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
# --infernal <string>  infernal output
#
###########################################################################


__EOUSAGE__


    ;



my $sqlite_db;
my $infernal_output;
my $help_flag;

&GetOptions( 'sqlite=s' => \$sqlite_db,
             'infernal=s' => \$infernal_output,
             
             'help|h' => \$help_flag,
    );

if ($help_flag) {
    die $usage;
}


unless ($sqlite_db && $infernal_output) {
    die $usage;
}


main: {
    
    unless (-s $sqlite_db) {
        die "Error, cannot locate the $sqlite_db database file";
    }
        
    my $dbh = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
    $dbh->do("delete from Infernal") or die $!;
    $dbh->disconnect();
    
    # CREATE TABLE INFERNALdata(TrinityQuerySequence,Featurestart INTEGER,Featureend INTEGER,Featurescore REAL, FeatureStrand, FeatureFrame, Featureprediction);

=sqlite_format

TrinityQuerySequence = comp4913_c1_seq2
        Featurestart = 14
          Featureend = 128
        Featurescore = 80.1
       FeatureStrand = +
        FeatureFrame = .
   Featureprediction = 8s_rRNA

=cut

    my $tmp_infernal_bulk_load_file = "tmp.infernal_bulk_load.$$";
    open (my $ofh, ">$tmp_infernal_bulk_load_file") or die "Error, cannot write to tmp file: $tmp_infernal_bulk_load_file";
    
    open (my $fh, $infernal_output) or die $!;
    while (<$fh>) {
        chomp;
        unless (/\w/) { next; }
        if (/^\#/) { next; }
        my @x = split(/\s+/);

        my $target_name = $x[1];
        my $rfam_acc = $x[2];
        my $query_acc = $x[3];
        my $clan_name = $x[5];
        my $region_start = $x[7];
        my $region_end = $x[8];
        my $strand = $x[11];
        my $score = $x[16];
        my $evalue = $x[17];
        my $overlap_indicator = $x[19];

        if ($overlap_indicator eq "=") { next; }
        
        print $ofh join("\t", 
                        $query_acc, $target_name, $rfam_acc, $clan_name, $region_start, $region_end, $strand, $score, $evalue) . "\n";
        
    }
    close $ofh;
    

    &bulk_load_sqlite($sqlite_db, "Infernal", $tmp_infernal_bulk_load_file);
    

    unlink($tmp_infernal_bulk_load_file);
        
    print STDERR "\n\nLoading complete..\n\n";
        
    exit(0);
    
}
