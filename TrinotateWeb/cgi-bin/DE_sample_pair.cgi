#!/usr/bin/env perl

use strict;
use warnings;

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib", "$FindBin::RealBin/PerlLib");
use DBI;
use Sqlite_connect;
use CanvasXpress::Scatter2D;
use CanvasXpress::PlotOnLoader;
use URI::Escape;
use Data::Dumper;
use HTML::Template;
use TextCache;


$|++;

our $SEE = 0;

main: {
    
    my $cgi = new CGI();
    print $cgi->header();
    
    my %params = $cgi->Vars();

    if ($params{SEE}) {
        $SEE = 1;
    }
    
    my $sqlite_db = $params{sqlite} or die "Error, need sqlite param";
        
    my $sample_pair = $params{sample_pair} or die "Error, need sample pair";
    #$sample_pair =~ s/\.(genes|isoforms)\.results//g;
    
    my $feature_type = $params{feature_type} || 'G'; # default to Gene
    
    my ($genes_selected, $trans_selected, $both_selected) = ("","","");
    
    if ($feature_type eq 'G') {
        $genes_selected = "checked";
    }
    elsif ($feature_type eq 'T') {
        $trans_selected = "checked";
    }
    elsif ($feature_type eq 'B') {
        $both_selected = "checked";
    }
    
    
    
    my $token = "$sqlite_db-DE_sample_pair-$sample_pair-$feature_type";
    if (my $html = &TextCache::get_cached_page($token)) {
        print $html;
    }
    else {
        
        my $html = "";
        
        my ($sampleA, $sampleB) = split(/,/, $sample_pair);
        
        my $plot_loader_func_name = "load_plots_$$";
        
        my $plot_loader = new CanvasXpress::PlotOnLoader($plot_loader_func_name);
        
        my $header_template = HTML::Template->new(filename => 'html/header.tmpl');
        $header_template->param(SUBTITLE => "- Comparison of sample $sampleA to $sampleB");
        $html .= $header_template->output;


        my $dashboard_header_template = HTML::Template->new(filename => 'html/dashboard-header.tmpl');
        $html .= $dashboard_header_template->output;
    
    
        my $nav_template = HTML::Template->new(filename => 'html/topnav.tabless.tmpl');
        $nav_template->param(ACTIVETAB => 'DE');
        $nav_template->param(SQLITE_DB => $sqlite_db);
        $html .= $nav_template->output;

        my $DE_sample_pair_template = HTML::Template->new(filename => 'html/DE_sample_pair.tmpl');
        
                
        my $dbproc = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
        
        
        my %gene_to_data = &get_diff_express_data($dbproc, $sampleA, $sampleB, $feature_type);
        
        # print "<pre>" . Dumper(\%gene_to_data) . "</pre>\n";
        
        my ($ma_plot_obj, $ma_plot_draw, $volcano_plot_obj, $volcano_plot_draw);
        
        print STDERR "\ngene_to_data:\n";
        print STDERR $gene_to_data{'error'};
        
        if ($gene_to_data{'error'}) {
            $DE_sample_pair_template->param(ERROR => 'There are no results for the selected feature type.');
        } else {
            ($ma_plot_obj, $ma_plot_draw) = &write_MA_plot($sampleA, $sampleB, \%gene_to_data, $sqlite_db);
            ($volcano_plot_obj, $volcano_plot_draw) = &write_Volcano_plot($sampleA, $sampleB, \%gene_to_data, $sqlite_db);
            
            $plot_loader->add_plot($ma_plot_obj);
            $plot_loader->add_plot($volcano_plot_obj);
        }
        
        $DE_sample_pair_template->param(SQLITE => $sqlite_db);
        $DE_sample_pair_template->param(SAMPLE_PAIR => $sample_pair);
        $DE_sample_pair_template->param(SAMPLE_A => $sampleA);
        $DE_sample_pair_template->param(SAMPLE_B => $sampleB);
        $DE_sample_pair_template->param(GENES_SELECTED => $genes_selected);
        $DE_sample_pair_template->param(TRANSCRIPTS_SELECTED => $trans_selected);
        $DE_sample_pair_template->param(BOTH_SELECTED => $both_selected);
        $DE_sample_pair_template->param(MA_PLOT_DRAW => $ma_plot_draw);
        $DE_sample_pair_template->param(VOLCANO_PLOT_DRAW => $volcano_plot_draw);
        
        $html .= $DE_sample_pair_template->output;
        
        unless ($gene_to_data{'error'}) {
            $html .= $plot_loader->write_plot_loader();
        }
        
        my $footer_template = HTML::Template->new(filename => 'html/footer.tmpl');
        $footer_template->param(ONLOAD_JS => $plot_loader_func_name . '();' );
        $html .= $footer_template->output;
    
        print $html;
        
        &TextCache::cache_page($token, $html);
    }
    

    exit(0);
}


####
sub get_diff_express_data {
    my ($dbproc, $sampleA, $sampleB, $feature_type) = @_;
    
    my %comparisons = &get_sample_comparisons_list($dbproc);  # sampleA . $; . sampleB
    
    my $invert_FC = 0;
    my ($sample_id_A, $sample_id_B); # just for querying the database below
    if ($comparisons{ join("$;", $sampleA, $sampleB) }) {
        ($sample_id_A, $sample_id_B) = ($sampleA, $sampleB);
    }
    elsif ($comparisons{ join("$;", $sampleB, $sampleA) }) {
        $invert_FC = 1;
        ($sample_id_A, $sample_id_B) = ($sampleB, $sampleA);
    }
    else {
        die "Error, did not detect an analysis of DE between $sampleA and $sampleB. Only have record of: " . Dumper(\%comparisons);
    }
    

   
    my $query = "select d.feature_name, d.log_avg_expr, d.log_fold_change, d.p_value, d.fdr, T.annotation "
        . " from Diff_expression d, Samples s1, Samples s2, Transcript T "
        . " where d.sample_id_A = s1.sample_id "
        . " and d.sample_id_B = s2.sample_id "
        . " and s1.sample_name = \"$sample_id_A\" "
        . " and s2.sample_name = \"$sample_id_B\" ";
    
    if ($feature_type eq 'G') {
        $query .= ' and d.feature_type = "G" and T.gene_id = d.feature_name ';
    }
    elsif ($feature_type eq 'T') {
        $query .= ' and d.feature_type = "T" and T.transcript_id = d.feature_name';
    }
    else {
        $query .= 
            ' and ( '
          . '   ( d.feature_type = "G" and T.gene_id = d.feature_name ) '
          . '   or '
          . '   ( d.feature_type = "T" and T.transcript_id = d.feature_name ) '
          . ' )';
    }
    
    print STDERR "$query\n";
    my $start = time();
    # exit(0);

    my @results = &do_sql_2D($dbproc, $query);
    my $end = time();
    
    my $query_time = $end - $start;
    print STDERR "\nQuery time: $query_time seconds.\n\n";
    

    my %gene_info;
    my %gene_annot;

    unless (@results) {
        my %error;
        $error{'error'} = 'no results';
        return(%error);
    }

    foreach my $result (@results) {
        my ($feature_name, $log_avg_expr, $log_fold_change, $p_value, $fdr, $annot) = @$result;

        if ($invert_FC) {
            $log_fold_change *= -1; # logspace
        }
        
        $gene_info{$feature_name} = { log_avg_expr => $log_avg_expr,
                                      log_fold_change => $log_fold_change,
                                      p_value => $p_value,
                                      fdr => $fdr,
                                      annot => $annot,
                                      
        };

        
    }
    
    return(%gene_info);
                                          

}



####
sub get_sample_comparisons_list {
    my ($dbproc) = @_;
        
    ## get relevant data:
    my $query = "select distinct s1.sample_name, s2.sample_name "
        . " from Samples s1, Samples s2, Diff_expression d "
        . " where s1.sample_id = d.sample_id_A "
        . " and s2.sample_id = d.sample_id_B ";
    my @results = &do_sql_2D($dbproc, $query);
    
    my %pairs;
    foreach my $result (@results) {
        my ($sampleA, $sampleB) = @$result;
        # print "<p>$sampleA, $sampleB\n";
        my $token = join("$;", $sampleA, $sampleB);
        $pairs{$token} = 1;
    }

    return(%pairs);

}


####
sub write_MA_plot {
    my ($sampleA, $sampleB, $gene_to_data_href, $sqlite_db) = @_;
    

    my @value_matrix;
    my @annots;
    my @stat_signif;
    foreach my $feature_name (keys %$gene_to_data_href) {
        my $struct = $gene_to_data_href->{$feature_name};
        
        my $log_avg_expr = $struct->{log_avg_expr};
        my $log_fold_change = $struct->{log_fold_change};
        my $fdr = $struct->{fdr};
        
        $log_avg_expr = sprintf("%.2f", $log_avg_expr);
        $log_fold_change = sprintf("%.2f", $log_fold_change);
        

        push (@value_matrix, [$feature_name, $log_avg_expr, $log_fold_change]);
        
        my $annot = $struct->{annot};
        push (@annots, $annot);
        
        my $is_stat_signif = ($fdr <= 0.05) ? "Yes" : "No";
        push (@stat_signif, $is_stat_signif);
    }

    $sqlite_db = uri_escape($sqlite_db);
    
    
    my %plot_inputs = ( replicate_names => ['log_avg_expr', 'log_fold_change'],
                        value_matrix => \@value_matrix,
                        comparisons => [ ['log_avg_expr', 'log_fold_change'] ],
                        
                        feature_annotations => {
                            annotation => \@annots,
                            significant => \@stat_signif,
                        },

                        colorBy => 'significant',
                        
                            #events => {

                            #'click' => "console.log('clicked');\n"
                            #    . "var gene = o['y']['vars'][0];\n"
                            #    . "console.log(gene);\n"
                            #    . "alert('clicked');\n"
                            #    ,
                            #    
                            #    'dblclick' => "alert('dblclick');\n",
                            #
                            #    'mousemove' => #"DumperAlert(o);",
                                #"var gene = o['vars'][0];\n"
                            #    "console.log('1');\n"
                            #    . "alert('mouseover');\n",
                            # }
                        
                        

                        events =>  { 'dblclick' => "var gene = o['y']['vars'][0];\n"
                                         #. "document.location.href=\'feature_report.cgi?feature_name=\' + gene"
                                         #. " + \'&sqlite=$sqlite_db\';\n",
                                         
                                         #. "window.open(\'feature_report.cgi?feature_name=\' + gene + \'&sqlite=$sqlite_db\');\n", 
                                         
                                         . "var win = window.open(\'feature_report.cgi?feature_name=\' + gene"
                                         . " + \'&sqlite=$sqlite_db\');\n"
                                         . "win.focus();\n"
                                         ,
                                         

                        },
                        
                        
                        
        );
    
    my $plot_obj = new CanvasXpress::Scatter2D("ma_plot_$$");

    my $plot_draw = $plot_obj->draw(%plot_inputs);
    
    
    return ($plot_obj, $plot_draw);
}


####
sub write_Volcano_plot {
    my ($sampleA, $sampleB, $gene_to_data_href, $sqlite_db) = @_;
    
    my $MIN_FDR = 1e-50;

    my @value_matrix;
    my @annots;
    my @stat_signif;
    foreach my $feature_name (keys %$gene_to_data_href) {
        my $struct = $gene_to_data_href->{$feature_name};
        
        my $fdr = $struct->{fdr};
        if ($fdr == 0) {
            $fdr = $MIN_FDR;
        }
        my $log_fold_change = $struct->{log_fold_change};
        
        my $is_stat_signif = ($fdr <= 0.05) ? "Yes" : "No";
        push (@stat_signif, $is_stat_signif);
        
        $fdr = -1 * log($fdr)/log(10);

        $log_fold_change = sprintf("%.2f", $log_fold_change);
        $fdr = sprintf("%.2f", $fdr);
        
        push (@value_matrix, [$feature_name, $log_fold_change, $fdr]);
        
        my $annot = $struct->{annot};
        push (@annots, $annot);
        

    }

    $sqlite_db = uri_escape($sqlite_db);
    
    my %plot_inputs = ( replicate_names => ['log_fold_change', '-1*log10(fdr)'],
                        value_matrix => \@value_matrix,
                        comparisons => [ ['log_fold_change', '-1*log10(fdr)'] ],
    
                        feature_annotations => {
                            annotation => \@annots,
                            significant => \@stat_signif,
                        },

                        colorBy => 'significant',


                        
                        events =>  { 'dblclick' => "var gene = o['y']['vars'][0];\n"
                                         #. "document.location.href=\'feature_report.cgi?feature_name=\' + gene"
                                         #. " + \'&sqlite=$sqlite_db\';\n",
                                         . "window.open(\'feature_report.cgi?feature_name=\' + gene + \'&sqlite=$sqlite_db\');\n", 

                        },

        );
    
    my $plot_obj = new CanvasXpress::Scatter2D("volcano_plot_$$");

    my $plot_draw = $plot_obj->draw(%plot_inputs);
    
    
    return ($plot_obj, $plot_draw);
}
