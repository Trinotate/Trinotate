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
# --signalp <string>    tmmhmm output
#
###########################################################################


__EOUSAGE__


    ;



my $sqlite_db;
my $signalp_output;
my $help_flag;

&GetOptions( 'sqlite=s' => \$sqlite_db,
             'signalp=s' => \$signalp_output,
             
             'help|h' => \$help_flag,
    );

if ($help_flag) {
    die $usage;
}


unless ($sqlite_db && $signalp_output) {
    die $usage;
}


main: {
    
    unless (-s $sqlite_db) {
        die "Error, cannot locate the $sqlite_db database file";
    }
        
    my $dbh = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
    $dbh->do("delete from signalp") or die $!;
    $dbh->disconnect();
    
    # CREATE TABLE SignalP(query_prot_id,start REAL,end REAL,score REAL,prediction);

    my $tmp_signalp_bulk_load_file = "tmp.signalp_bulk_load.$$";
    open (my $ofh, ">$tmp_signalp_bulk_load_file") or die "Error, cannot write to tmp file: $tmp_signalp_bulk_load_file";
    
    open (my $fh, $signalp_output) or die $!;
    while (<$fh>) {
        chomp;
        unless (/\w/) { next; }
        if (/^\#/) { next; }
        my @x = split(/\t/);

        my @fasta_header_pts = split(/\s+/, $x[0]);
        my $query_prot_id = $fasta_header_pts[0];
        my $start = $x[3];
        my $end = $x[4];
        my $score = $x[5];
        my $prediction = $x[8];

        print $ofh join("\t", $query_prot_id, $start, $end, $score, $prediction) . "\n";
        
    }
    close $ofh;
    

    &bulk_load_sqlite($sqlite_db, "signalp", $tmp_signalp_bulk_load_file);
    

    unlink($tmp_signalp_bulk_load_file);
        
    print STDERR "\n\nLoading complete..\n\n";
        
    exit(0);
    
}
