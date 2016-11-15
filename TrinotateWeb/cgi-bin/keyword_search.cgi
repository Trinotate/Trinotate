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
use URI::Escape;
use Data::Dumper;
use HTML::Template;


my $MAX_RESULTS = 200;
my $MAX_TEXTLINE_LEN = 300;

main: {
    
    my $cgi = new CGI();
    print $cgi->header();
    
    my %params = $cgi->Vars();
    
    my $sqlite_db = $params{sqlite} or die "Error, need sqlite param";
    my $keyword = $params{keyword} or die "Error, need keyword param";
    $keyword =~ s/\W/ /g;
    
    my $header_template = HTML::Template->new(filename => 'html/header.tmpl');
    print $header_template->output;
    
    my $nav_template = HTML::Template->new(filename => 'html/topnav.tmpl');
    $nav_template->param(ACTIVETAB => 'keyword_search');
    $nav_template->param(SQLITE_DB => $sqlite_db);
    print $nav_template->output;
    
    my $dbproc = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";

    my $query = "select gene_id, transcript_id, annotation from Transcript where ";
    my @keywords = split(/\s+/, $keyword);
    for (my $i = 0; $i <= $#keywords; $i++) {
        $query .= " annotation like \"%" . $keywords[$i] . "%\"";
        if ($i != $#keywords) {
            $query .= " and ";
        }
    }


    print '<div class="container-fluid">';
    print '<div class="row">';
    print '<div class="col-sm-12 col-md-12 main">';
    print '<div class="row">';
    print "<h3>Search results for [$keyword]</h3>\n";
    
    my $counter = 0;

    my @results = &do_sql_2D($dbproc, $query);

    print "<p>There are " . scalar(@results) . " matching entries.</p>\n";
    
    if (@results) {
        
        print '<div class="table-responsive">';
        print '<table class="table table-striped">';
        print "<tr><th>#</th><th>gene_id</th><th>transcript_id</th><th>annotation</th></tr>\n";
        
        
        
        foreach my $result (@results) {
            
            $counter++;

            my ($gene_id, $transcript_id, $annot) = @$result;
            if (length($annot) > $MAX_TEXTLINE_LEN) {
                $annot = substr($annot, 0, $MAX_TEXTLINE_LEN);
            }
            foreach my $keyw (@keywords) {
                $annot =~ s/$keyw/<b>$keyw<\/b>/g;
            }
            print "<tr><td>$counter</td>"
                . "<td><a href=\"feature_report.cgi?feature_name=" . uri_escape($gene_id) . "&sqlite=" . uri_escape($sqlite_db) . "\" target=\"$gene_id report\">$gene_id</td>"
                . "<td><a href=\"feature_report.cgi?feature_name=" . uri_escape($transcript_id) . "&sqlite=" . uri_escape($sqlite_db) . "\" target=\"$transcript_id report\">$transcript_id</td>"
                . "<td>$annot</td></tr>\n";
                    
            if ($counter >= $MAX_RESULTS) {
                print "<tr><td colspan=4>RESULTS TRUNCATED TO MAX OF $MAX_RESULTS ENTRIES</td></tr>\n";
                last;
            }
        }
        print "</table>\n";
        print "</div>\n";
        print "</div>\n";
        print "</div>\n";
        print "</div>\n";
        print "</div>\n";
    }
    
        
    $dbproc->disconnect;
        
    my $footer_template = HTML::Template->new(filename => 'html/footer.tmpl');
    print $footer_template->output;
    
    
    exit(0);

}

