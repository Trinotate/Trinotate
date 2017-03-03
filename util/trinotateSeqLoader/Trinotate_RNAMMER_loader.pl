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
# --rnammer <string>    tmmhmm output
#
###########################################################################


__EOUSAGE__


    ;



my $sqlite_db;
my $rnammer_output;
my $help_flag;

&GetOptions( 'sqlite=s' => \$sqlite_db,
             'rnammer=s' => \$rnammer_output,
             
             'help|h' => \$help_flag,
    );

if ($help_flag) {
    die $usage;
}


unless ($sqlite_db && $rnammer_output) {
    die $usage;
}


main: {
    
    unless (-s $sqlite_db) {
        die "Error, cannot locate the $sqlite_db database file";
    }
        
    my $dbh = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
    $dbh->do("delete from RNAMMERdata") or die $!;
    $dbh->disconnect();
    
    # CREATE TABLE RNAMMERdata(TrinityQuerySequence,Featurestart INTEGER,Featureend INTEGER,Featurescore REAL, FeatureStrand, FeatureFrame, Featureprediction);

=sqlite_format

TrinityQuerySequence = comp4913_c1_seq2
        Featurestart = 14
          Featureend = 128
        Featurescore = 80.1
       FeatureStrand = +
        FeatureFrame = .
   Featureprediction = 8s_rRNA

=cut

    my $tmp_rnammer_bulk_load_file = "tmp.rnammer_bulk_load.$$";
    open (my $ofh, ">$tmp_rnammer_bulk_load_file") or die "Error, cannot write to tmp file: $tmp_rnammer_bulk_load_file";
    
    open (my $fh, $rnammer_output) or die $!;
    while (<$fh>) {
        chomp;
        unless (/\w/) { next; }
        if (/^\#/) { next; }
        my @x = split(/\s+/);
        
        my $TrinityQuerySequence = $x[0];
        my $Featurestart = $x[3];
        my $Featureend = $x[4];
        my $Featurescore = $x[5];
        my $FeatureStrand = $x[6];
        my $FeatureFrame = $x[7];
        my $Featureprediction = $x[8];

        print $ofh join("\t", $TrinityQuerySequence, $Featurestart, $Featureend, $Featurescore,
                        $FeatureStrand, $FeatureFrame, $Featureprediction) . "\n";
                        
    }
    close $ofh;
    

    &bulk_load_sqlite($sqlite_db, "RNAMMERdata", $tmp_rnammer_bulk_load_file);
    

    unlink($tmp_rnammer_bulk_load_file);
        
    print STDERR "\n\nLoading complete..\n\n";
        
    exit(0);
    
}
