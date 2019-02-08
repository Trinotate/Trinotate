#!/usr/bin/env perl

use strict;
use warnings;

# standard perl modules
use CGI;
use CGI::Pretty ":standard";
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use DBI;
use URI::Escape;
use Data::Dumper;
use Cwd;
use HTML::Template;

# custom modules
use lib ("$FindBin::RealBin/../../PerlLib", "$FindBin::RealBin/PerlLib");
use Sqlite_connect;
use TextCache;
use CanvasXpress::Sunburst;
use CanvasXpress::PlotOnLoader;


main: {
    
    my $cgi = new CGI();
    print $cgi->header();

    my %params = $cgi->Vars();

    my $sqlite_db = $params{sqlite_db};
    
    my $header_template = HTML::Template->new(filename => 'html/header.tmpl');
    print $header_template->output;
    
    my $nav_template = HTML::Template->new(filename => 'html/topnav.tmpl');
    $nav_template->param(SQLITE_DB => $sqlite_db);
    print $nav_template->output;
    
    my $dashboard_header_template = HTML::Template->new(filename => 'html/dashboard-header.tmpl');
    print $dashboard_header_template->output;
    

    eval {
        if ($sqlite_db) {
            
            if (! -s $sqlite_db) {
                die "Error, cannot locate $sqlite_db";
            }
            &TrinotateWebMain(\%params, $sqlite_db);
            
        }
        else {
            
            print "<h2>Need database info</h2>\n";
            
            &print_get_sqlite_db_path_form();
            
        }
    };
    if ($@) {
        print "<b>Error encountered:</b> $@";
    }
    
    my $dashboard_footer_template = HTML::Template->new(filename => 'html/dashboard-footer.tmpl');
    print $dashboard_footer_template->output;


    
    # update the heatmap url link
    my $footer_template = HTML::Template->new(filename => 'html/footer.tmpl');

    my $JS = "
        \$('#heatmapnav-link').attr('href', \$('#heatmapnav-link').attr('href') + \$('#topnav').data('sqlite'));
    ";

    $footer_template->param(ONLOAD_JS => $JS );

    print $footer_template->output;
    
    exit(0);
}

####
sub print_get_sqlite_db_path_form {
    
    print "<form action='index.cgi' method='get'>\n";

    print "<ul>\n"
        . "<li>Path to Trinotate SQLite database:\n"
        . "<li><input type='text' name='sqlite_db' maxlength=1000 size=150 />\n"
        . "<li><input type='submit' />\n"
        . "</li>\n"
        . "</ul>\n";
    
    print "</form>\n";


    return;
}
    
####
sub TrinotateWebMain {
    my ($params_href, $sqlite_db) = @_;
    
    my $dbproc = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
        

    ## Load up the panels tied to the selector tabs:
    
    overview_panel_text($dbproc, $sqlite_db);
    
    keyword_search_panel_text($dbproc, $sqlite_db);
    
    gene_search_panel($dbproc, $sqlite_db);
    
    DE_panel_text($dbproc, $sqlite_db);

    TaxonomyBestHit_text($dbproc, $sqlite_db);
    
    return;
}

####
sub overview_panel_text {
    my ($dbproc, $sqlite_db) = @_;


    my $html_cache_token = "$sqlite_db-overview_panel_text";
    if (my $html = &TextCache::get_cached_page($html_cache_token)) {
        print $html;
    }
    else {
        
        my $query = "select count(distinct gene_id) from Transcript";
        my $gene_count = &very_first_result_sql($dbproc, $query);
        
        $query = "select count(distinct transcript_id) from Transcript";
        my $transcript_count = &very_first_result_sql($dbproc, $query);
        
        

        
        my $template = HTML::Template->new(filename => 'html/overview.tmpl');
        $template->param(GENE_COUNT => $gene_count);
        $template->param(TRANSCRIPT_COUNT => $transcript_count);
        my $html = $template->output;
        
        &TextCache::cache_page($html_cache_token, $html);
        
        print $html;
    }


    return;
}

####
sub keyword_search_panel_text {
    #Still needed: search based on specific attribute: pfam, go, kegg, etc.
    my ($dbproc, $sqlite_db) = @_;
    
    my $template = HTML::Template->new(filename => 'html/keyword_search.tmpl');
    print $template->output;
}

####
sub gene_search_panel {
    my ($dbproc, $sqlite_db) = @_;
    
    my $template = HTML::Template->new(filename => 'html/gene_search.tmpl');
    print $template->output;
}


####
sub TaxonomyBestHit_text {
    my ($dbproc, $sqlite_db) = @_;
    
    my $template = HTML::Template->new(filename => 'html/taxonomy_best_hit.tmpl');
        
    #my $taxonomy_html = &_get_taxonomy_info($dbproc, $sqlite_db);
    
    #$template->param(TAXONOMY_HTML => $taxonomy_html);

    $template->param(TAXONOMY_HTML => "under construction");
    
    print $template->output;
}


####
sub DE_panel_text {
    my ($dbproc, $sqlite_db) = @_;
    
    ## get list of pairs:
    my $query = "select sample_name from Samples";
    my @results = &do_sql($dbproc, $query);

    my $template = HTML::Template->new(filename => 'html/DE.tmpl');

    #format result array into array of hashes for HTML::Template
    my @samples = ();
    while (@results) {
        my %row_data; # get a fresh hash for the row data 
        $row_data{SAMPLE} = shift @results;
        push(@samples, \%row_data);
    }

    $template->param(SAMPLES => \@samples);
    $template->param(CLUSTER_HTML => &multi_sample_cluster_text($dbproc, $sqlite_db));

    print $template->output;
}


####
sub multi_sample_cluster_text {
    my ($dbproc, $sqlite_db) = @_;
    
    ## get cluster analyses
    my $query = "select ECA.cluster_analysis_id, ECA.cluster_analysis_group, ECA.cluster_analysis_name, count(distinct EC.expr_cluster_id) "
        . " from ExprClusterAnalyses ECA, ExprClusters EC "
        . " where ECA.cluster_analysis_id = EC.cluster_analysis_id "
        . " group by ECA.cluster_analysis_id, ECA.cluster_analysis_group, ECA.cluster_analysis_name order by ECA.cluster_analysis_group";
    
    #print $query;

    my @results = &do_sql_2D($dbproc, $query);
    my $cluster_html = '';

    if (@results) {
        $cluster_html .= "<ul>Analyses of clusters of expression profiles:\n";
        
        foreach my $result (@results) {
            my ($cluster_analysis_id, $analysis_group, $analysis_name, $cluster_count) = @$result;
            $cluster_html .= "<li><a href=\"transcript_cluster_viewer.cgi?cluster_analysis_id=" . uri_escape($cluster_analysis_id)
                . "&sqlite=" . uri_escape($sqlite_db) . "\" target=_blank >$analysis_group :: $analysis_name</a> with $cluster_count clusters.\n";
        }
        $cluster_html .= "</ul>\n";
    }
    else {
        $cluster_html .= "<p>No expression profile clusters defined yet.\n";
    }
    
    
    return $cluster_html;
}




####
sub _get_taxonomy_info {
    my ($dbproc, $sqlite_db) = @_;

    my $query = "select t.TaxonomyValue, count(*) as count from TaxonomyIndex t, UniprotIndex u where u.AttributeType = 'T' and u.LinkID =  t.NCBITaxonomyAccession group by t.TaxonomyValue order by count desc limit 1000";
    
    my %taxonomy_counter;
    my %species_counter;

    my $TOP_TAX_LEVEL = 6;
    
    my @results = &do_sql_2D($dbproc, $query);
    foreach my $result (@results) {
        my ($taxonomy, $count) = @$result;
        
        my @tax_levels = split(/;\s*/, $taxonomy);
        my $species = pop @tax_levels;
        my @top_tax_levels = @tax_levels[0..($TOP_TAX_LEVEL-1)];
        for my $level (@top_tax_levels) {
            if (! defined $level) {
                $level = "NA";
            }
        }
        
        my $top_tax_level = join("\t", @top_tax_levels);
        #print STDERR "$top_tax_level -> $species\n" if $DEBUG;
        $taxonomy_counter{$top_tax_level} += $count;
        $species_counter{$species} = $count;
        
    }

    ###################################
    ## reorganize the data for plotting
        
    my $NUM_TOP_CATS = 50;
    
    my @levels;
    for (my $i = 1; $i <= $TOP_TAX_LEVEL; $i++) {
        push (@levels, "L$i");
    }

    my @row_values;
    my @column_data;
    my $other_counts = 0;
    my $counter = 0;
    foreach my $taxonomy (reverse sort {$taxonomy_counter{$a}<=>$taxonomy_counter{$b}} keys %taxonomy_counter) {
        $counter++;
                
        my $count = $taxonomy_counter{$taxonomy};
        my @x = split("\t", $taxonomy);
        if ($counter < $NUM_TOP_CATS) {
            for(my $i = 0; $i <= $#x; $i++) {
                push (@{$column_data[$i]}, $x[$i]);
            }
            push (@row_values, $count);
        }
        else {
            $other_counts += $count;
        }
    }


    if ($other_counts) {
        # build other counts entry:
        my @columns = @column_data;
        my $first_col = shift @columns;
        push (@$first_col, "Other");
        foreach my $other_col (@columns) {
            push (@$other_col, "NA");
        }
        push (@row_values, $other_counts);
    }

    # convert column data to hash:
    my %column_data_hash;
    for (my $i = 0; $i <= $#levels; $i++) {

        my $level = $levels[$i];
        my $col_data_aref = $column_data[$i];
        $column_data_hash{$level} = $col_data_aref;
    }

    my $taxonomy_sunburst = new CanvasXpress::Sunburst("taxonomy_sunburst");
    my $plot_loader = new CanvasXpress::PlotOnLoader("taxonomy_$$");
    $plot_loader->add_plot($taxonomy_sunburst);
    
    my %inputs = (title =>  "Taxonomic representation of gene-level top blastx matches",

                  column_names => [@levels],

                  column_contents => \%column_data_hash,

                  row_values => [@row_values]);


    my $taxonomy_html = $taxonomy_sunburst->draw(%inputs);

    $taxonomy_html .= $plot_loader->write_plot_loader();
    
    return($taxonomy_html);
    
}
