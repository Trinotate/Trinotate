#!/usr/bin/env perl

use strict;
use warnings;

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib", "$FindBin::RealBin/PerlLib");
use DBI;
use Sqlite_connect;
use Trinotate;
use DEWebCommon;
use Data::Dumper;
use URI::Escape;
use CanvasXpress::PlotOnLoader;
use CanvasXpress::Heatmap;
use CanvasXpress::Line;

our $SEE = 0;

$|++;

main: {
    
    my $cgi = new CGI();
    print $cgi->header();
    
    my %params = $cgi->Vars();
    
    my $sqlite_db = $params{sqlite} or die "Error, need sqlite param";
    my $cluster_analysis_id = $params{cluster_analysis_id} or die "Error, need cluster_analysis_id param";

    my $dbproc = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
    
    my $query = "select cluster_analysis_group, cluster_analysis_name from ExprClusterAnalyses where cluster_analysis_id = \"$cluster_analysis_id\"";
    my $result = &do_sql_first_row($dbproc, $query);
    my ($analysis_group, $analysis_name) = split(/\t/, $result);
    
    my $title = "Transcriptional Cluster Report for $analysis_group\::$analysis_name";
    
    my $plots_per_page = $params{plots_per_page} || 1; 
    my $center_vals = $params{center_vals} || "none";
    
    my $scale_range = $params{scale_range} || "min-max";
    
    my $start = $params{start} || 1;
    
    my $max_genes_show = $params{max_genes_show} || 100;
    
    my $plot_loader_func_name = "load_plots_$$";
    
    print $cgi->start_html(-title => $title,
                           -onLoad => $plot_loader_func_name . "();",
                           -style => {'src' => "/css/common.css"},
        );
    
    print "<h1>$title</h1>\n";
    
    
    my $query = "select max(EC.expr_cluster_id) "
        . " from ExprClusters EC, ExprClusterAnalyses ECA "
        . " where ECA.cluster_analysis_id = ? "
        . " and ECA.cluster_analysis_id = EC.cluster_analysis_id ";

    my $max_cluster_id = &very_first_result_sql($dbproc, $query, $cluster_analysis_id);
    
    print "<p><a href=\"index.cgi?sqlite_db=" . uri_escape($sqlite_db) . "\">[Home]</a></p>\n";
    ## generate header
    my $header_html = "<div id='header' style='border:1px solid black;'>\n"
        . "<form action='transcript_cluster_viewer.cgi'>\n"
        . "<input type='hidden' name='sqlite' value=\'$sqlite_db\' />\n"
        . "<input type='hidden' name='cluster_analysis_id' value=\'$cluster_analysis_id\' />\n"
        . "<ul>\n"
        . "  <li>Plots per page: <input type='text' name='plots_per_page' value=\'$plots_per_page\' size=2 />\n"
        . "  <li>Starting plot number: <input type='text' name='start' value=\'$start\' size=2 /> of $max_cluster_id\n"
        . "  <li>Heatmap scale range: <input type='text' name='scale_range' value=\'$scale_range\' size=8 />\n"; 
    
    $header_html .= "<li>Center expression values: ";

    my @center_val_opts = qw(average median none);
    foreach my $opt (@center_val_opts) {

        $header_html .= "<input type='radio' name=\'center_vals\' value=\'$opt\' ";
        if ($opt eq $center_vals) {
            $header_html .= " checked ";
        }
        $header_html .= " />$opt\n";
    }
    
    $header_html .= "<li>Max genes to show: <input type='text' name='max_genes_show' value=$max_genes_show size=4 />\n";
    
    $header_html .= "<input type='submit' />\n"
        . "</ul>\n"
        . "</form>\n"
        . "</div>\n";
    
    print $header_html;
    
    if ($center_vals && $center_vals eq 'none') {
        undef($center_vals);
    }    
    
    ## make next_link:

    #print "Max cluster_id: $max_cluster_id\n";
    
    my $left_range = $start;
    my $right_range = $start + $plots_per_page - 1;
    if ($right_range > $max_cluster_id) {
        $right_range = $max_cluster_id;
    }
    if ($left_range > $right_range) {
        $left_range = $right_range;
    }
    
    
    my $next_link = "";
    
    if ($right_range < $max_cluster_id) {
        $next_link = "<div id='next_link' style='clear:both;'><p><a href=\"transcript_cluster_viewer.cgi?"
            . "sqlite=" . uri_escape($sqlite_db)
            . "&plots_per_page=$plots_per_page"
            . "&start=" . ($right_range+1)
            . "&cluster_analysis_id=" . uri_escape($cluster_analysis_id);
        if ($center_vals) {
            $next_link .= "&center_vals=$center_vals";
        }
        my $next_count_plots = $max_cluster_id - $right_range;
        if ($next_count_plots > $plots_per_page) {
            $next_count_plots = $plots_per_page;
        }
        $next_link .= "\">[Next $next_count_plots]</a></p></div>\n";
        
    }

    print $next_link;

    my $plot_loader = new CanvasXpress::PlotOnLoader($plot_loader_func_name);
    
    
    for my $cluster_no ($left_range..$right_range) {
        
        my %data = &DEWebCommon::get_expression_data($dbproc, { cluster_analysis_id => $cluster_analysis_id,
                                                                expr_cluster_id => $cluster_no,
                                                                center_vals => $center_vals,
                                                     });
        
        #print "<pre>" . Dumper(\%data) . "</pre>";
        
        my @feature_names = keys %{$data{feature_to_info}};
        my $num_total_features = scalar(@feature_names);
        my $msg = "";
        


        print "<h2 style='clear:both;'>Cluster $cluster_no, $cluster_analysis_id</h2>\n";
        print "<p>$num_total_features features clustered$msg.\n";



        #######################
        # Downsample as needed
        #######################
        
        if (scalar @feature_names > $max_genes_show) {
            %data = &DEWebCommon::sample_from_data(\%data, $max_genes_show);
            @feature_names = keys %{$data{feature_to_info}};
            
            $msg = " (Only $max_genes_show randomly selected features are shown)";
        }
        



        #################################
        # Expression Line Plot
        #################################

        print "<h3>Line plot for cluster $cluster_no, $cluster_analysis_id</h3>\n";

        
        my $plot_obj = new CanvasXpress::Line("line_plot_$cluster_no");
        $data{graphOrientation} = 'vertical';

        print $plot_obj->draw(%data);
        
        $plot_loader->add_plot($plot_obj);
        
        print $next_link;


        
        ############################
        # Heatmap
        ###########################
        
        print "<h3>Heatmap for cluster $cluster_no, $cluster_analysis_id</h3>\n";

        my $heatmap_obj = new CanvasXpress::Heatmap("heatmap_$cluster_no");
        $plot_loader->add_plot($heatmap_obj);
        
        $data{cluster_features} = 1;
        $data{cluster_samples} = 1;
        $data{dendrogramSpace} = 0.2;
        #$data{showSmpDendrogram} = 0;
        #$data{showVarDendrogram} = 0;
        $data{sample_annotations}->{sample_type} = $data{sample_names};
        

        $data{events}->{click} = "var gene = o['y']['vars'][0]; IGV_go(gene);\n";

        $data{events}->{'dblclick'} = "var gene = o['y']['vars'][0];\n"
            . "launch_feature_report(gene);\n";
        
        my ($min_scale, $max_scale) = split(/-/, $scale_range);
        if ($min_scale =~ /^\d+$/ && $max_scale =~ /^\d+$/) {
            $data{setMinX} = $min_scale;
            $data{setMaxX} = $max_scale;
        }
        
        print $heatmap_obj->draw(%data);


        print $next_link;

        ############################
        #  IGV stuff
        ############################
        
        print &DEWebCommon::write_IGV_go_script($sqlite_db);
        


        
        #&write_annotation_table($dbproc, $sqlite_db, $cluster_no, \@feature_names);  ## put in hide-away div
        
        #print $next_link;
    }
    
    
    print $plot_loader->write_plot_loader();
    
    $dbproc->disconnect;


        
    print $cgi->end_html();
    
    exit(0);

}

####
sub write_annotation_table {
    my ($dbproc, $sqlite_db, $cluster_no, $feature_names_aref) = @_;
        
    print "<table border=1 style='clear:both;'>\n";
    foreach my $feature_name (@$feature_names_aref) {
        
        my $query = "select gene_id, transcript_id, annotation from Transcript where gene_id = ? or transcript_id = ?";
        my @results = &do_sql_2D($dbproc, $query, $feature_name, $feature_name);
        foreach my $result (@results) {
            my ($gene_id, $transcript_id, $annotation) = @$result;
            

            if ($annotation =~ /RecName: (.*)/) {
                $annotation = $1;
            }
            my $annot = substr($annotation, 0, 200);
            print "<tr>\n";
            print "<td><a href=\"feature_report.cgi?feature_name=" . uri_escape($gene_id) . "&sqlite=" . uri_escape($sqlite_db) . "\" target=_blank >$gene_id</td>"
                . "<td><a href=\"feature_report.cgi?feature_name=" . uri_escape($transcript_id) . "&sqlite=" . uri_escape($sqlite_db) . "\" target=_blank >$transcript_id</td>"
                . "<td>$annot</td>\n";
            print "</tr>\n";
    
        }
    
        print "<tr><td colspan=3 bgcolor='#006666'>&nbsp;</td></tr>\n";
    }
    
    print "</table>\n";

    return;
}
    
    
