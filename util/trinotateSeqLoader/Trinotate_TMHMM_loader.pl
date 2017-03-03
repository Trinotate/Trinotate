#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");
use Fasta_reader;

use DBI;
use Sqlite_connect;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);


my $usage = <<__EOUSAGE__;

###########################################################################
#
# Required:
#
# --sqlite <string>  Trinotate sqlite database
#
# --tmhmm <string>    tmmhmm output
#
###########################################################################


__EOUSAGE__


    ;



my $sqlite_db;
my $tmhmm_output;
my $help_flag;

&GetOptions( 'sqlite=s' => \$sqlite_db,
             'tmhmm=s' => \$tmhmm_output,
             
             'help|h' => \$help_flag,
    );

if ($help_flag) {
    die $usage;
}


unless ($sqlite_db && $tmhmm_output) {
    die $usage;
}


main: {
    
    unless (-s $sqlite_db) {
        die "Error, cannot locate the $sqlite_db database file";
    }
        
    my $dbh = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
    $dbh->do("delete from tmhmm") or die $!;
    $dbh->disconnect();
    
    # CREATE TABLE tmhmm(queryprotid,Score REAL,PredHel,Topology);

    my $tmp_tmhmm_bulk_load_file = "tmp.tmhmm_bulk_load.$$";
    open (my $ofh, ">$tmp_tmhmm_bulk_load_file") or die "Error, cannot write to tmp file: $tmp_tmhmm_bulk_load_file";
    
    open (my $fh, $tmhmm_output) or die $!;
    while (<$fh>) {
        chomp;
        unless (/\w/) { next; }
        if (/^\#/) { next; }
        my @x = split(/\s+/);

        # This skips any HTML markup which is often found in the header/footer of the file
        next unless scalar(@x) >= 5;
        
        my $queryprotid = $x[0];
        my $score = $x[2];
        my $PredHel = $x[4];
        my $Topology = $x[5];

        print $ofh join("\t", $queryprotid, $score, $PredHel, $Topology) . "\n";
    }
    close $ofh;

    &bulk_load_sqlite($sqlite_db, "tmhmm", $tmp_tmhmm_bulk_load_file);

    unlink($tmp_tmhmm_bulk_load_file);
        
    print STDERR "\n\nLoading complete..\n\n";
        
    exit(0);
}
