#!/usr/bin/env perl

use strict;
use warnings;

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib", "$FindBin::RealBin/PerlLib");
use DBI;
use Sqlite_connect;
use CanvasXpress::Heatmap;
use CanvasXpress::PlotOnLoader;
use Data::Dumper;
use File::Basename;
use DEWebCommon;
use Data::Dumper;
use HTML::Template;

$|++;

my $DEFAULT_MIN_FC = 4;
my $DEFAULT_MAX_FDR = 1e-4;


main: {
    
    my $cgi = new CGI();
    print $cgi->header();
    
    my %params = $cgi->Vars();
    my $sqlite_db = $params{sqlite} or die "Error, need sqlite param";

    my $sample_pair = $params{sample_pair};

    my $title = ($sample_pair) ? "Heatmap for sample pair: $sample_pair" : "Expression Heatmap for " . basename($sqlite_db);

    my $plot_loader_func_name = "load_plots_$$";

    my $header_template = HTML::Template->new(filename => 'html/header.tmpl');
    $header_template->param(SUBTITLE => "- $title");
    print $header_template->output;
    
    my $nav_template = HTML::Template->new(filename => 'html/topnav.tabless.tmpl');
    $nav_template->param(ACTIVETAB => 'DE');
    $nav_template->param(SQLITE_DB => $sqlite_db);
    print $nav_template->output;

    my $plot_loader = new CanvasXpress::PlotOnLoader($plot_loader_func_name);

    my $heatmap_template = HTML::Template->new(filename => 'html/HeatmapNav.tmpl');
    $heatmap_template->param(TITLE => $title);

    $heatmap_template->param(SQLITE_DB => $sqlite_db);
    
    my $min_FC = $params{min_FC} || $DEFAULT_MIN_FC;
    $heatmap_template->param(MIN_FC => $min_FC);

    my $max_FDR = $params{max_FDR} || $DEFAULT_MAX_FDR;
    $heatmap_template->param(MAX_FDR => $max_FDR);

    my $min_any_feature_expr = $params{min_any_feature_expr} || 0;
    $heatmap_template->param(MIN_ANY_FEATURE_EXPR => $min_any_feature_expr );

    my $min_sum_feature_expr = $params{min_sum_feature_expr} || 0;
    $heatmap_template->param(MIN_SUM_FEATURE_EXPR => $min_sum_feature_expr );

    my $scale_range = $params{scale_range} || "min-max";
    $heatmap_template->param(SCALE_RANGE => $scale_range );

    my $center_vals = $params{center_vals} || "none";
    if ($center_vals eq "average") {
        $heatmap_template->param(CENTER_AVERAGE => 1);
    }
    if ($center_vals eq "median") {
        $heatmap_template->param(CENTER_MEDIAN => 1);
    }
    if ($center_vals eq "none") {
        $heatmap_template->param(CENTER_NONE => 1);
    }

    my $feature_type = $params{feature_type} || "G"; # genes by default
    if ($feature_type eq "G") {
        $heatmap_template->param(FEATURE_TYPE_G => 1);
    }
    if ($feature_type eq "T") {
        $heatmap_template->param(FEATURE_TYPE_T => 1);
    }

    if ($params{all_features}) {
        $heatmap_template->param(ALL_FEATURES => 1);
    }

    if ($params{cluster_transcripts}) {
        $heatmap_template->param(CLUSTER_TRANSCRIPTS => 1);
    }

    if ($params{top_expressed_flag}) {
        $heatmap_template->param(TOP_EXPRESSED_FLAG => 1);
    }

    if ($params{sample_pair}) {
        $heatmap_template->param(SAMPLE_PAIR => $params{sample_pair});
    }

    if ($params{restrict_to_sample_pair_flag}) {
        $heatmap_template->param(RESTRICT_TO_SAMPLE_PAIR_FLAG => 1);
    }

    my $max_genes_show = $params{max_genes_show} || 100;    
    $heatmap_template->param(MAX_GENES_SHOW => $max_genes_show);

    my ($heatmap_plot_obj, $message, $heatmap_drawing) = &write_heatmap($sqlite_db, \%params);
    $heatmap_template->param(MESSAGE => $message);
    $heatmap_template->param(HEATMAP_DRAWING => $heatmap_drawing);

    print $heatmap_template->output;

    if ($heatmap_plot_obj) {
        $plot_loader->add_plot($heatmap_plot_obj);

        print $plot_loader->write_plot_loader();
        
        print '<hr style="clear:both;">'; #just separate the annot divs that show up in the IGV go script.
        print &DEWebCommon::write_IGV_go_script($sqlite_db);
    }
    
    my $footer_template = HTML::Template->new(filename => 'html/footer.tmpl');
    $footer_template->param(ONLOAD_JS => $plot_loader_func_name . '();' );
    print $footer_template->output;
    
    
    exit(0);
}

####
sub write_heatmap {
    my ($sqlite_db, $params_href) = @_;
    
    my $dbproc = connect_to_db($sqlite_db);
    

    ## none of this helps with performance...  :(
    #&AutoCommit($dbproc, 0);
    #&RunMod($dbproc, "PRAGMA synchronous=OFF");
    #&RunMod($dbproc, "pragma cache_size=4000000");
    #&RunMod($dbproc, "PRAGMA temp_store=MEMORY");
    #&RunMod($dbproc, "pragma journal_mode=memory");
    
    
    my $min_FC = $params_href->{min_FC} || $DEFAULT_MIN_FC;
    my $max_FDR = $params_href->{max_FDR} || $DEFAULT_MAX_FDR;

    my $scale_range = $params_href->{scale_range} || "min-max";

    if ($params_href->{all_features}) {
        $min_FC = undef;
        $max_FDR = undef;
    }
    
    my $min_any_feature_expr = $params_href->{min_any_feature_expr} || 0;
    my $min_sum_feature_expr = $params_href->{min_sum_feature_expr} || 0;
    my $sample_pair = $params_href->{sample_pair};
    my $restrict_to_sample_pair_flag = $params_href->{restrict_to_sample_pair_flag};
    my $max_genes_show = $params_href->{max_genes_show} || 100;    
    my $top_expressed_flag = $params_href->{top_expressed_flag} || 0;
    my $center_vals = $params_href->{center_vals} || "none";
    my $feature_type = $params_href->{feature_type} || "G"; # genes by default
    
    # print "<pre>\n" . Dumper($params_href) . "</pre>\n";
    
    if ($center_vals && $center_vals eq 'none') {
        undef($center_vals);
    }    
    

    my %data = &DEWebCommon::get_expression_data($dbproc, { min_FC => $min_FC,
                                                            max_FDR => $max_FDR,
                                                            min_any_feature_expr => $min_any_feature_expr,
                                                            min_sum_feature_expr => $min_sum_feature_expr,
                                                            
                                                            sample_pair => $sample_pair, # just in case specified
                                                            restrict_to_sample_pair_flag => $restrict_to_sample_pair_flag,
                                                            
                                                            feature_type => $feature_type,
    
                                                            center_vals => $center_vals,
                                                            
                                                            max_select => 200000,
                                                 });
    
    #print Dumper(\%data);

    #######################
    # Downsample as needed
    #######################
    
        
    my @feature_names = keys %{$data{feature_to_info}};

    my $message = "";

    if (scalar @feature_names > $max_genes_show) {
        %data = &DEWebCommon::sample_from_data(\%data, $max_genes_show, $top_expressed_flag);
        
        $message .= "<p> (Only $max_genes_show of " . scalar(@feature_names) . " randomly selected features are shown) </p>";
    }
    
    my $replicate_names_aref = $data{replicate_names};
    my $value_matrix_aref = $data{value_matrix};

    my $num_features = scalar(@$value_matrix_aref);
    
    $message .= "<p>Found $num_features features.</p>\n";
    
    unless ($num_features) {
        # nothing to plot.
        return(undef);
    }
    
    
    my %heatmap_inputs = (

        sample_annotations => { samples => $data{sample_names} },
        
        replicate_names => $replicate_names_aref,
        value_matrix => $value_matrix_aref,
        cluster_features => $params_href->{cluster_transcripts},
        cluster_samples => $params_href->{cluster_samples},
        dendrogramSpace => 0.2,
        
                          
                          events => {

                            'click' => #"console.log('clicked' + o);\n"
                                 "var gene = o['y']['vars'][0];\n"
                                #. "console.log(gene);\n"
                                #. "alert('clicked ' + gene);\n"
                                . "IGV_go(gene);\n"
                                ,
                            #    
                            #'dblclick' => "console.log('dblclick' + Dumper.alert(o));\n",
                            #'dblclick' => "console.log(Dumper.write(cx.varDendrogram.nodes));\n",
#"Dumper.alert(o);\n",
                            'dblclick' => "var gene = o['y']['vars'][0];\n"
                                         . "launch_feature_report(gene);\n",

                            #
                            #    'mousemove' => #"DumperAlert(o);",
                                #"var gene = o['vars'][0];\n"
                            #    "console.log('1');\n"
                            #    . "alert('mouseover');\n",
                            
                          },
                          
        );
    

    # heatmap color scaling
    
    my ($min_scale, $max_scale) = split(/-/, $scale_range);
    if ($min_scale =~ /^\d+$/ && $max_scale =~ /^\d+$/) {
        $heatmap_inputs{setMinX} = $min_scale;
        $heatmap_inputs{setMaxX} = $max_scale;
    }
    
    my $heatmap_obj = new CanvasXpress::Heatmap("heatmap_$$");

    my $heatmap_drawing= $heatmap_obj->draw(%heatmap_inputs);

    
    return($heatmap_obj, $message, $heatmap_drawing);
}

