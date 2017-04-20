#!/usr/bin/env perl


use strict;
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib", "$FindBin::RealBin/PerlLib");
use DBI;
use Sqlite_connect;

$|++;

my $cgi = new CGI();

print $cgi->header();
my %params = $cgi->Vars();

main: {
    
    my $sqlite_db = $params{sqlite_db} or die "Error, need sqlite_db ";
    my $feature = $params{feature} or die "Error, need feature";

    unless (-s $sqlite_db) {
        die "Error, cannot locate sqlite_db at: $sqlite_db";
    }

 
    my $dbproc = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";

    my $query = "select gene_id, transcript_id, scaffold, lend, rend, annotation from Transcript where gene_id = ? or transcript_id = ?";
    my @results = &do_sql_2D($dbproc, $query, $feature, $feature);
    
    unless (@results) {
        die "Error, no record of feature $feature";
    }
    my $top_result = shift @results;
    my ($gene_id, $transcript_id, $scaffold, $lend, $rend, $annotation) = @$top_result;

    unless ($scaffold) {
        $scaffold = $transcript_id;
    }
    unless ($lend) {
        $lend = "null";
    }
    unless ($rend) {
        $rend = "null";
    }
    

    $annotation =~ s/\W/ /g;
    # print "$scaffold:$lend-$rend\n";
    
    # write json
    print "{\n"
        . "   'gene_id' : \'$gene_id\',\n"
        . "   'transcript_id' : \'$transcript_id\',\n"
        . "   'scaffold' : \'$scaffold\',\n"
        . "   'lend' : $lend,\n"
        . "   'rend' : $rend,\n"
        . "   'annotation' : \"$annotation\"\n"
        . "}\n";
    
    exit(0);

}
