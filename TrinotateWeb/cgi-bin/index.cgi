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
use lib ("$FindBin::Bin/../../PerlLib", "$FindBin::Bin/PerlLib");
use Sqlite_connect;
use TextCache;

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
        
    
    overview_panel_text($dbproc, $sqlite_db);
    
    keyword_search_panel_text($dbproc, $sqlite_db);
    
    gene_search_panel($dbproc, $sqlite_db);
    
    DE_panel_text($dbproc, $sqlite_db);

    
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
