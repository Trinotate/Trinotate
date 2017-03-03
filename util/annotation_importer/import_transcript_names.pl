#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");

use Sqlite_connect;
use Trinotate;


my $usage = "usage: $0 sqlite.db annotations_file.txt\n\n"
    . " Note: annotations file should have format: \n"
    . " gene_id (tab) transcript_id (tab) annotation text till end of line.\n\n";



my $sqlite_db = $ARGV[0] or die $usage;
my $annot_file = $ARGV[1] or die $usage;

#our $SEE = 1;

main: {

    unless (-s "$sqlite_db") {
        die "Error, must first build Trinotate sqlite results database";
    }
    
    my $dbproc = &connect_to_db("$sqlite_db");
    
    ## clear out current annotations:
    my $query = "update Transcript set annotation = NULL";
    &RunMod($dbproc, $query);
    
    
    &RunMod($dbproc, "PRAGMA synchronous=OFF");
    
    $dbproc->{AutoCommit} = 0;
    
    my $counter = 0;

    open (my $fh, $annot_file) or die $!;
    while (<$fh>) {
        if (/^\#/) { next; }
        chomp;
        
        my ($gene_id, $transcript_id, $annot) = split(/\t/, $_, 3);

        my $query = "update Transcript set annotation = ? where gene_id = ? and transcript_id = ? ";
        &RunMod($dbproc, $query, $annot, $gene_id, $transcript_id);

        $counter++;

        print STDERR "\r[$counter]    ";
        if ($counter % 100 == 0) {
            $dbproc->commit;
        }

    }
    close $fh;

    $dbproc->commit;
    

    exit(0);


}

