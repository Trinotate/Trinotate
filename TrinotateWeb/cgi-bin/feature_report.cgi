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
use CanvasXpress::Line;
use CanvasXpress::GenomeBrowser;
use CanvasXpress::PlotOnLoader;
use Trinotate;
use DEWebCommon;
use Data::Dumper;
use HTML::Template;

main: {
    
    my $cgi = new CGI();
    print $cgi->header();
    
    my %params = $cgi->Vars();
    
    my $sqlite_db = $params{sqlite} or die "Error, need sqlite param";
    my $feature_name = $params{feature_name} or die "Error, need feature_name"; 
    
    

    my $plot_loader_func_name = "load_plots_$$";

    my $plot_loader = new CanvasXpress::PlotOnLoader($plot_loader_func_name);
    

    my $header_template = HTML::Template->new(filename => 'html/header.tmpl');
    $header_template->param(SUBTITLE => "- $feature_name");
    print $header_template->output;
    
    my $nav_template = HTML::Template->new(filename => 'html/topnav.tabless.tmpl');
    $nav_template->param(ACTIVETAB => 'gene_search');
    $nav_template->param(SQLITE_DB => $sqlite_db);
    print $nav_template->output;
    
    
    
    my $dbproc = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
    
    my $feature_report_header_template = HTML::Template->new(filename => 'html/feature_report_header.tmpl');
    $feature_report_header_template->param(FEATURE_NAME => $feature_name);
    print $feature_report_header_template->output;


    ## determine if gene or transcript:
    my $query = "select rowid from Transcript where gene_id = \"$feature_name\"";
    my $is_gene = &very_first_result_sql($dbproc, $query);
    my $feature_type;
    if ($is_gene) {
        $feature_type = 'G';
    }
    else {
        ## ensure we have a transcript row:
        my $query = "select rowid from Transcript where transcript_id = \"$feature_name\" ";
        my $is_trans = &very_first_result_sql($dbproc, $query);
        if ($is_trans) {
            $feature_type = 'T';
        }
        else {
            print "No gene or transcript feature found with id = $feature_name";
            my $footer_template = HTML::Template->new(filename => 'html/footer.tmpl');
            print $footer_template->output;            
            exit();
        }
    }
    
    
    my %data = &DEWebCommon::get_expression_data($dbproc, { feature_name => $feature_name,
                                                            feature_type => $feature_type,
                                                            
                                                            include_transcript_isoforms => 1,
                                                 });

    #print "<pre>" . Dumper(\%data) . "</pre>\n";
    
    {
        my $feature_report_expression_template = HTML::Template->new(filename => 'html/feature_report_expression.tmpl');
        
        if (@{$data{value_matrix}}) {
            
            
            
            my %inputs = ( replicate_names => $data{replicate_names},
                           
                           sample_annotations => { samples => $data{sample_names} },
                           value_matrix => $data{value_matrix},
                           
                );
            
            ######################################
            ##  Heatmap ###
            ######################################
            
            my $clust_features_flag = (scalar @{$data{value_matrix}} > 1);
            
            my $heatmap_plot_obj = new CanvasXpress::Heatmap("heatmap_plot_$$");
            my $heatmap_plot =  $heatmap_plot_obj->draw(%inputs,
                                                        cluster_features => $clust_features_flag,
                                                        cluster_samples => 1,
                                                        dendrogramSpace => 0.2,
                                                        
                                                        events => { 
                                                            'dblclick' => "var gene = o['y']['vars'][0];\n"
                                                                . "var loc = '#' + gene;\n"
                                                                . "document.location.href=loc;\n",
                                                        },
                );
            
            $plot_loader->add_plot($heatmap_plot_obj);
            
            
            #######################################
            #  Expression line plot
            ###################################
            
            
            $inputs{graphOrientation} = 'vertical';
            
            my $line_plot_obj = new CanvasXpress::Line("line_plot_$$");
            my $line_plot = $line_plot_obj->draw(%inputs,
                                                 
                                                 events => { 
                                                     'dblclick' => "var gene = o['y']['vars'][0];\n"
                                                         . "var loc = '#' + gene;\n"
                                                         . "document.location.href=loc;\n",
                                                 },
                );
            
            $plot_loader->add_plot($line_plot_obj);
            
            $feature_report_expression_template->param(HEATMAP_PLOT => $heatmap_plot);
            $feature_report_expression_template->param(LINE_PLOT => $line_plot);
            
        } else {
            $feature_report_expression_template->param(FEATURE_NAME => $feature_name);
        }
        
        print $feature_report_expression_template->output;

    }


    { # ??? is this block encapsulation necessary?
        

        ## report annotations
        my $query = "select gene_id, transcript_id, annotation, sequence from Transcript where ";

        $query .= ($feature_type eq 'G') ? " gene_id = ? " : " transcript_id = ? ";
        
        my @results = &do_sql_2D($dbproc, $query, $feature_name);
        
        my $counter = 0;
        foreach my $result (@results) {
            my ($gene_id, $transcript_id, $annotation, $transcript_sequence) = @$result;
            my $transcript_plot_template = HTML::Template->new(filename => 'html/feature_report_transcript.tmpl');
            $transcript_plot_template->param(GENE_ID => $gene_id);
            $transcript_plot_template->param(TRANSCRIPT_ID => $transcript_id);
            my $trans_id_token = $transcript_id;
            $trans_id_token =~ s/\W/_/g;
            $transcript_plot_template->param(TRANS_ID_TOKEN => $trans_id_token);
            
            unless ($transcript_sequence) {
                print $transcript_plot_template->output;
                next;
            }
        
            my $transcript_id_plot_name = $transcript_id;
            $transcript_id_plot_name =~ s/\W/_/g;
            
            
            #######################################
            # Transcript level expression line plot
            #######################################

            my ($trans_expr_row) = grep {$_->[0] eq $transcript_id } @{$data{value_matrix}};
            
            if ($trans_expr_row) { 
                # if insufficient expression, won't be loaded into sqlite to save space
            
                my %inputs = ( replicate_names => $data{replicate_names},
                               value_matrix => [$trans_expr_row],
                               
                    );
                
                $inputs{graphOrientation} = 'vertical';
                
                            
                my $plot_obj = new CanvasXpress::Line("line_plot_${transcript_id_plot_name}_$$"); # ensure unique for each.
                $transcript_plot_template->param(PLOT => $plot_obj->draw(%inputs));
                
                $plot_loader->add_plot($plot_obj);
            }
            
                        
            my $genome_browser_plot_name = "gb_$transcript_id_plot_name";
            $genome_browser_plot_name =~ s/\W/_/g;
            
            my $genome_browser = new CanvasXpress::GenomeBrowser($genome_browser_plot_name, $transcript_sequence);
            $plot_loader->add_plot($genome_browser);
            
            my @peptide_seqs;

            my $query = "select orf_id, lend, rend, strand, peptide from ORF where transcript_id = ?";
            my @orf_results = &do_sql_2D($dbproc, $query, $transcript_id);
            foreach my $orf_result (@orf_results) {
                my ($orf_id, $lend, $rend, $strand, $peptide) = @$orf_result;
                my $track = new CanvasXpress::GenomeBrowser::Track("ORF:$orf_id", "box");
                my @match_tracks = &get_browser_match_elements($dbproc, $orf_id, $lend, $rend, $strand);
                foreach my $match_track (@match_tracks) {
                    $genome_browser->add_track($match_track);
                }
                
                push (@peptide_seqs, [$orf_id, $peptide]);

            }
            
            $transcript_plot_template->param(GENOME_BROWSER => $genome_browser->draw());
            
            $transcript_sequence =~ s/(\S{60})/$1\n/g;
            if ($annotation =~ /\t/) {
                my $decorated_annotation = "<ul>";
              Fields: 
                foreach my $field (split(/\t/, $annotation)) {
                    if ($field eq ".") { next; }
                    $decorated_annotation .= "<li>annotation"; # field sep
                    my @entries = split(/`/, $field);
                    foreach my $entry (@entries) {
                        my @parts = split(/\^/, $entry);
                        $decorated_annotation .= "<ul><li><ul><li>" . join("</li><li>", @parts) . "</li></ul></li></ul>\n";
                    }
                    $decorated_annotation .= "</li>\n";
                }
                $annotation = $decorated_annotation . "</ul>";
            }
            

            my $transcript_data_dump = "<ul style='clear:both'>\n"
                . "<li>gene_id: $gene_id\n"
                . "<li>transcript_id: $transcript_id\n"
                . "<li>annotations: $annotation\n"
                . "<li>transcript sequence:<div class='fasta'><pre>&gt;$transcript_id\n$transcript_sequence</pre></div>\n";

            if (@peptide_seqs) {
                $transcript_data_dump .= "<li>peptide sequences:";
                $transcript_data_dump .= "<ul>";
                foreach my $peptide (@peptide_seqs) {
                    my ($orf_id, $peptide_seq) = @$peptide;
                    $peptide_seq =~ s/(\S{60})/$1\n/g;
                    $transcript_data_dump .= "<li><div class='fasta'><pre>&gt;$orf_id\n$peptide_seq</pre></div>\n";
                }
                
            
                $transcript_data_dump .= "</ul>\n"; # end of orf list
            }
            
            $transcript_data_dump .= "</ul>\n"; # end of transcript list
            $transcript_plot_template->param(TRANSCRIPT_DATA => $transcript_data_dump);

            print $transcript_plot_template->output;
        }
        
    }

    my $feature_report_footer_template = HTML::Template->new(filename => 'html/feature_report_footer.tmpl');
    print $feature_report_footer_template->output;
            
    print $plot_loader->write_plot_loader();

    my $footer_template = HTML::Template->new(filename => 'html/footer.tmpl');

    my $JS = "
    \$('.panel-title a').click(function (e){
        window.scrollTo(0,0);
    });";

    $footer_template->param(ONLOAD_JS => $plot_loader_func_name . '();' . $JS );
    print $footer_template->output;
    

    exit(0);

}


####
sub get_browser_match_elements {
    my ($dbproc, $orf_id, $lend, $rend, $strand) = @_;

    my @browser_tracks;
    
    ## add the ORF
    my $orf_track = new CanvasXpress::GenomeBrowser::Track("ORF:$orf_id", 'box');
    my $orf_element = new CanvasXpress::GenomeBrowser::Element($orf_id, [ [$lend,$rend] ]);
    $orf_track->add_element($orf_element);
    
    push (@browser_tracks, $orf_track);
    

    ## get pfam domains:
    my @pfam_info = &Trinotate::get_pfam_info($dbproc, $orf_id, "DNC");
    if (@pfam_info) {
        
        my $pfam_track = new CanvasXpress::GenomeBrowser::Track("Pfam for $orf_id", 'box');
        
        foreach my $pfam_hit (@pfam_info) {
            my ($pfam_id, $domain_descr, $start, $end) = ($pfam_hit->{pfam_id},
                                                          $pfam_hit->{HMMERTDomainDescription},
                                                          $pfam_hit->{QueryStartAlign}, 
                                                          $pfam_hit->{QueryEndAlign});
            
            my ($draw_lend, $draw_rend) = &get_draw_coords($lend, $rend, $strand, $start, $end);
            
            my $match = new CanvasXpress::GenomeBrowser::Element("$pfam_id $domain_descr", [ [$draw_lend, $draw_rend] ]);
            $pfam_track->add_element($match);
            
        }
        push (@browser_tracks, $pfam_track);
    }
    
    ## get the blast hits
    my @blast_hits = &Trinotate::get_blast_results($dbproc, $orf_id, undef, "blastp");
    if (@blast_hits) {
        
        my $blast_track = new CanvasXpress::GenomeBrowser::Track("BLAST for $orf_id", 'box');

        
        foreach my $blast_hit (@blast_hits) {
            my ($acc, $start, $end, $per_id, $e_value, $descr) = ($blast_hit->{FullAccession},
                                                                  $blast_hit->{QueryStart},
                                                                  $blast_hit->{QueryEnd},
                                                                  $blast_hit->{PercentIdentity},
                                                                  $blast_hit->{Evalue},
                                                                  $blast_hit->{DescriptionLine},
                );

            my ($draw_lend, $draw_rend) = &get_draw_coords($lend, $rend, $strand, $start, $end);
            
            my $match = new CanvasXpress::GenomeBrowser::Element("$acc|PerID:$per_id|E:$e_value $descr", [ [$draw_lend, $draw_rend] ]);
            $blast_track->add_element($match);
            
        }

        push (@browser_tracks, $blast_track);
    }
    

    ## add other stuff later on

    return(@browser_tracks);
    
}

####
sub get_draw_coords {
    my ($refseq_lend, $refseq_rend, $refseq_orient, $match_lend, $match_rend) = @_;

    if ($refseq_orient eq '+') {
        return($refseq_lend + $match_lend -1, $refseq_lend + $match_rend - 1);
    }
    else {
        return($refseq_rend - $match_rend + 1, $refseq_rend - $match_lend + 1);
    }

}
    
