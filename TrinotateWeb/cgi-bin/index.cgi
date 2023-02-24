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
use CanvasXpress::Piechart;
use CanvasXpress::Barplot;


our $RESET_FLAG = 0;

my $plot_loader = new CanvasXpress::PlotOnLoader("load_plots");
main: {
    
    my $cgi = new CGI();
    print $cgi->header();

    my %params = $cgi->Vars();

    my $sqlite_db = $params{sqlite_db};

    $RESET_FLAG = $params{RESET} || 0;
    
        
    my $header_template = HTML::Template->new(filename => 'html/header.tmpl');
    print "<!-- Header Template -->\n";
    print $header_template->output;

    
     
    eval {
        if ($sqlite_db) {
            
            if (! -s $sqlite_db) {
                die "Error, cannot locate $sqlite_db";
            }
            print "<body onload=\"load_plots();\">\n";

            print "<!-- Nav Template -->\n";
            my $nav_template = HTML::Template->new(filename => 'html/topnav.tmpl');
            $nav_template->param(SQLITE_DB => $sqlite_db);
            print $nav_template->output;
            
            print "<!-- Dashboard Header -->\n";
            my $dashboard_header_template = HTML::Template->new(filename => 'html/dashboard-header.tmpl');
            print $dashboard_header_template->output;
            
            &TrinotateWebMain(\%params, $sqlite_db);
            
        }
        else {
            
            print "<body>\n<h2>Need database info</h2>\n";
            
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
    
        
    my $cgi = new CGI();

    
    #print $cgi->start_html(-title => "Trinotate Report",
    #                       -onLoad => "load_plots();");
    
    

    ## Load up the panels tied to the selector tabs:
    
    overview_panel_text($dbproc, $sqlite_db);
    
    keyword_search_panel_text($dbproc, $sqlite_db);
    
    gene_search_panel($dbproc, $sqlite_db);
    
    DE_panel_text($dbproc, $sqlite_db);

    TaxonomyBestHit_text($dbproc, $sqlite_db);

    pfamplot($dbproc, $sqlite_db);
    
    goplot($dbproc, $sqlite_db);

    write_plot_loader($plot_loader, $sqlite_db);
    
    
    return;
}




####
sub overview_panel_text {
    my ($dbproc, $sqlite_db) = @_;


    my $html_cache_token = "$sqlite_db-overview_panel_text";
    unless ($RESET_FLAG) {
        if (my $html = &TextCache::get_cached_page($html_cache_token)) {
            print $html;
            return;
        }
    }

            
    my $query = "select count(distinct gene_id) from Transcript";
    my $gene_count = &very_first_result_sql($dbproc, $query);
    
    $query = "select count(distinct transcript_id) from Transcript";
    my $transcript_count = &very_first_result_sql($dbproc, $query);
    
    
    my $template = HTML::Template->new(filename => 'html/overview.tmpl');
    $template->param(GENE_COUNT => $gene_count);
    $template->param(TRANSCRIPT_COUNT => $transcript_count);
    my $html = $template->output;
    
    print $html;
    
    $html = &add_cache_resetter($html, $sqlite_db);
    
    &TextCache::cache_page($html_cache_token, $html);
    
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
    
    my $html_cache_token = "$sqlite_db-taxonomy_info_text";

    unless ($RESET_FLAG) {
        if (my $html = &TextCache::get_cached_page($html_cache_token)) {
            print($html);
            return;
        }
    }
    
    my $template = HTML::Template->new(filename => 'html/taxonomy_best_hit.tmpl');
        
    my $taxonomy_html = &_get_taxonomy_info($dbproc, $sqlite_db);
    
    $template->param(TAXONOMY_HTML => $taxonomy_html);

    $taxonomy_html = $template->output;

    my $cached_taxonomy_html = &add_cache_resetter($taxonomy_html, $sqlite_db); 
    
    &TextCache::cache_page($html_cache_token, $cached_taxonomy_html);

    print($taxonomy_html);

    return;
    
}


=keggplot
###
sub keggplot {
    my ($dbproc, $sqlite_db) = @_;

    my $html_cache_token = "$sqlite_db-kegg_info_text";
    unless ($RESET_FLAG) {
        if (my $html = &TextCache::get_cached_page($html_cache_token)) {
            print($html);
            return;
        }
    }
    my $template2 = HTML::Template->new(filename => 'html/kegg.tmpl');
        
    my $kegg_html = &_get_kegg_info($dbproc, $sqlite_db);
    
    $template2->param(kegg => $kegg_html);
    
    
    $kegg_html = $template2->output;

    my $cached_kegg_html = &add_cache_resetter($kegg_html, $sqlite_db);
    
    &TextCache::cache_page($html_cache_token, $cached_kegg_html);

    print $kegg_html;

    return;

}
=cut

###
sub pfamplot{
    my ($dbproc, $sqlite_db) = @_;

    my $html_cache_token = "$sqlite_db-pfam_info_text";
    unless ($RESET_FLAG) {
        if (my $html = &TextCache::get_cached_page($html_cache_token)) {
            print $html;
            return;
        }
    }
    
    
    my $template2 = HTML::Template->new(filename => 'html/pfam.tmpl');
        
    my $pfam_html = &_get_pfam_info($dbproc, $sqlite_db);
    
    $template2->param(pfam_var => $pfam_html);
    
    $pfam_html = $template2->output;

    my $cached_pfam_html = &add_cache_resetter($pfam_html, $sqlite_db);
    

    &TextCache::cache_page($html_cache_token, $cached_pfam_html);
    
    print $pfam_html;
    
}



sub goplot{
    my ($dbproc, $sqlite_db) = @_;

    my $html_cache_token = "$sqlite_db-GeneOntology_text";
    unless ($RESET_FLAG) {
        if (my $html = &TextCache::get_cached_page($html_cache_token)) {
            print $html;
            return;
        }
    }
    
    my $template2 = HTML::Template->new(filename => 'html/go.tmpl');
        
    my $go_info = &_get_go_info($dbproc, $sqlite_db);
    
    $template2->param(go_var => $go_info);
    
    my $go_html = $template2->output;

    my $cached_go_html = &add_cache_resetter($go_html, $sqlite_db);
    
    &TextCache::cache_page($html_cache_token, $cached_go_html);
    
    print $go_html;
    
}
    
####
sub DE_panel_text {
    my ($dbproc, $sqlite_db) = @_;

    my $html_cache_token = "$sqlite_db-DE_panel";
    if (my $html = &TextCache::get_cached_page($html_cache_token)) {
        print $html;
    }
    else {
    
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

        
        my $html = $template->output;
        &TextCache::cache_page($html_cache_token, $html);
        print $html;
    }

}

####
sub multi_sample_cluster_text {
    my ($dbproc, $sqlite_db) = @_;

    my $html_cache_token = "$sqlite_db-multi_sample_cluster_text";
    if (my $html = &TextCache::get_cached_page($html_cache_token)) {
        return($html);
    }

                
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
    
    &TextCache::cache_page($html_cache_token, $cluster_html);
    
    return $cluster_html;
    
}




####
sub _get_taxonomy_info {
    my ($dbproc, $sqlite_db) = @_;


    my $query = "select t.TaxonomyValue, count(*) as count from TaxonomyIndex t, UniprotIndex u, BlastDbase b, Transcript "
        . " where u.AttributeType = 'T' and u.LinkID =  t.NCBITaxonomyAccession and  u.accession = b.UniprotSearchString and Transcript.transcript_id = b.TrinityID "
        . " group by t.TaxonomyValue "
        . " order by count DESC limit 1000";
    
    
    
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

    $plot_loader->add_plot($taxonomy_sunburst);
    
    my %inputs = (title =>  "Taxonomic representation of transcript-level top blastx matches",

                  column_names => [@levels],

                  column_contents => \%column_data_hash,

                  row_values => [@row_values]);


    my $taxonomy_html = $taxonomy_sunburst->draw(%inputs);

    
    return($taxonomy_html);
    
}


=eggnog

####
sub _get_eggnog_info {
    my ($dbproc, $sqlite_db) = @_;


    my $NUM_TOP_EGGNOG = 50;
    
    my $query = "select e.eggNOGIndexTerm, count(*) as count from eggNOGIndex e, UniprotIndex u, BlastDbase b "
        . " where e.eggNOGIndexTerm = u.LinkId and u.accession = b.UniprotSearchString and u.AttributeType = 'E' "
        . " group by e.eggNOGIndexTerm "
        . " order by count DESC limit $NUM_TOP_KEGG";

    print $query;
    
    my @vals;
    my $counter = 0;

    my @results = &do_sql_2D($dbproc, $query);
    
    foreach my $result (@results) {
        
        my ($kegg, $count) = @$result;
        
        push (@vals, [$kegg, $count]);
        
    }
    
    my $keggbarplot = new CanvasXpress::Barplot("keggbarplot");

    $plot_loader->add_plot($keggbarplot);
    
    my %inputs = ( orientation => 'horizontal',

                   title => 'Top 50 KEGG domains',

                   var_name => 'kegg',

                   data => [@vals],
        );
                  


    my $kegg_html .= $keggbarplot->draw(%inputs);
        
    
    return($kegg_html); 

}

=cut

sub _get_pfam_info {
    my ($dbproc, $sqlite_db) = @_;

    my $query = "select h.pfam_id, h.HMMERDomain, count(*) as c "
        . " from HMMERDbase h, PFAMreference p "
        . " where h.pfam_id = p.pfam_accession and h.FullDomainScore >= p.Domain_NoiseCutOff and h.ThisDomainEvalue <= 1e-5 "
        . " group by h.pfam_id, h.HMMERDomain "
        . " order by c DESC limit 50";
            
    my @vals;
    my @results = &do_sql_2D($dbproc, $query);
    foreach my $result (@results) {
        
        my ($pfam_id, $domain, $count) = @$result;
                
        push (@vals, ["$pfam_id^$domain", $count]);
     
    }

    
    my %inputs = ( orientation => 'horizontal',

                   title => 'Top 50 Pfam domains (DNC, e<=1e-5)',
                   
                   var_name => 'Pfam',

                   data => [@vals],
        );

    my $barplot = new CanvasXpress::Barplot("barplot");
    $plot_loader->add_plot($barplot);

    my $pfam_html .= $barplot->draw(%inputs);

        
    return ($pfam_html);
}

###
sub _get_go_info {
    my ($dbproc, $sqlite_db) = @_;

    my $query = "select gs.namespace, gs.name, count(*) as c "
        . " from Transcript t, Orf o, UniprotIndex ui, go g, go_slim gs, go_slim_mapping gsm, BlastDbase b " 
        . " where t.transcript_id = o.transcript_id and "
        . " o.orf_id = b.TrinityID and "
        . " b.UniprotSearchString = ui.Accession and "
        . " ui.AttributeType = 'G' and ui.LinkId = g.id and "
        . " g.id = gsm.go_id and gsm.slim_id = gs.id "
        . " group by gs.namespace, gs.name order by c DESC";
    
    #print $query;
    
    my @vals;
    my @results = &do_sql_2D($dbproc, $query);
    my @column_names = ("go_class", "go_term");
    my %column_data;
    my @row_values;
    foreach my $result (@results) {
        
        my ($go_class, $go_term, $count) = @$result;
                 
        push (@{$column_data{'go_class'}}, $go_class);
        push (@{$column_data{'go_term'}}, $go_term);
        push (@row_values, $count);
    }
  

    my $GO_sunburst = new CanvasXpress::Sunburst("GO_sunburst");
    $plot_loader->add_plot($GO_sunburst);

    my %inputs = (title => "Gene Ontology Categories",
                  column_names => [@column_names],
                  column_contents => \%column_data,
                  row_values => [@row_values] );

    my $go_html = $GO_sunburst->draw(%inputs);

    return $go_html;
}


####
sub write_plot_loader {
    my ($plot_loader, $sqlite_db) = @_;
    
    my $html_cache_token = "$sqlite_db-plot_loader_text";
    unless($RESET_FLAG) {
        if (my $html = &TextCache::get_cached_page($html_cache_token)) {
            print $html;
            return;
        }
    }
   
    my $html = $plot_loader->write_plot_loader();
    &TextCache::cache_page($html_cache_token, $html);
    print $html;
    
}

####
sub add_cache_resetter {
    my ($html, $sqlite_db) = @_;

    $html =~ s|not_cached|<a href="/cgi-bin/index.cgi?RESET=1&sqlite_db=$sqlite_db">Cached page. Click to recompute.</a>|;

    return($html);
}

