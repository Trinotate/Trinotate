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
# --outfmt6 <string>   blast output format in BLAST+ '-outfmt 6' format
#
# --prog <string>      blastp|blastx
#
# --dbtype <string>     egc. Swissprot, TrEMBL, or other custom database name.
#
###########################################################################




__EOUSAGE__


    ;



my $sqlite_db;
my $help_flag;

my $outfmt6;
my $prog;
my $dbtype;


&GetOptions( 'sqlite=s' => \$sqlite_db,
             'outfmt6=s' => \$outfmt6,
             'prog=s' => \$prog,
             'dbtype=s' => \$dbtype,
             
             'help|h' => \$help_flag,
    );

if ($help_flag) {
    die $usage;
}


unless ($sqlite_db && $outfmt6 && $prog && $dbtype) {
    die $usage;
}

unless ($prog =~ /blastp|blastx/i) { 
    die "Error, do not recognize prog type: $prog ";
}


main: {
    
    unless (-s $sqlite_db) {
        die "Error, cannot locate the $sqlite_db database file";
    }
        
    my $dbh = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";


    ## Purge earlier stored results for that sequence type and database type:
    if ($prog =~ /blastp/) {
        my $query = "delete from BlastDbase where TrinityID in (select orf_id from ORF) and DatabaseSource = \"$dbtype\" ";
        $dbh->do($query) or die "Error, $!";
    }
    elsif ($prog =~ /blastx/) {
        my $query = "delete from BlastDbase where TrinityID in (select transcript_id from Transcript) and DatabaseSource = \"$dbtype\"";
        $dbh->do($query) or die "Error, $!";
    }
    
    $dbh->disconnect();
    
    ## prep for bulk load
    
    my $tmp_blast_bulk_load_file = "tmp.blast_bulk_load.$$";
    open (my $ofh, ">$tmp_blast_bulk_load_file") or die "Error, cannot write to tmp file: $tmp_blast_bulk_load_file";
    
=Trinotate_sqlite_structure

          TrinityID = m.673
      FullAccession = sp|Q5RED0|PGRC1_PONAB
           GINumber = Swissprot
UniprotSearchString = Q5RED0
         QueryStart = 33.0
           QueryEnd = 161.0
           HitStart = 61.0
             HitEnd = 185.0
    PercentIdentity = 44.27
             Evalue = 9.0e-24
           BitScore = 109.0
           DatabaseSource = Swissprot

=cut

    open (my $fh, $outfmt6) or die $!;
    while (<$fh>) {
        chomp;
        unless (/\w/) { next; }
        if (/^\#/) { next; }
        my @x = split(/\s+/);
        
        my $TrinityID = $x[0];
        my $FullAccession = $x[1];
        my $GINumber = $dbtype; # backwards compatibility since we were misusing this field.
        
        my $UniprotSearchString = "";
                
        #if ($FullAccession =~ /UniRef/) {
        #    $UniprotSearchString = $FullAccession;
        #    $UniprotSearchString =~ s/UniRef\d+_//;
        #    $UniprotSearchString =~ s/-\d+$//; # in case diff isoform peps are provided.
        #}
        #else {
        #    my @acc_pts = split(/\|/, $FullAccession);
        #    $UniprotSearchString = $acc_pts[1];
        #}


        $UniprotSearchString = $FullAccession;
        
        my $QueryStart = $x[6];
        my $QueryEnd = $x[7];
        my $HitStart = $x[8];
        my $HitEnd = $x[9];
        
        my $PercentIdentity = $x[2];
        my $Evalue = $x[10];
        my $BitScore = $x[11];
        my $DatabseSource = $dbtype;
        
        print $ofh join("\t", $TrinityID, $FullAccession, $GINumber, $UniprotSearchString,
                        $QueryStart, $QueryEnd, $HitStart, $HitEnd,
                        $PercentIdentity, $Evalue, $BitScore, $DatabseSource) . "\n";
        
        
    }
    close $ofh;


    &bulk_load_sqlite($sqlite_db, "BlastDbase", $tmp_blast_bulk_load_file);
    

    unlink($tmp_blast_bulk_load_file);
        
    print STDERR "\n\nBlastDbase loading complete..\n\n";
    
    exit(0);
    
}
