#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");
use Carp;
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
# --pfam <string>    pfam domain table output
#
###########################################################################


__EOUSAGE__


    ;



my $sqlite_db;
my $pfam_output;
my $help_flag;

&GetOptions( 'sqlite=s' => \$sqlite_db,
             'pfam=s' => \$pfam_output,
             
             'help|h' => \$help_flag,
    );

if ($help_flag) {
    die $usage;
}


unless ($sqlite_db && $pfam_output) {
    die $usage;
}


main: {
    
    unless (-s $sqlite_db) {
        die "Error, cannot locate the $sqlite_db database file";
    }
        
    my $dbh = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
    $dbh->do("delete from HMMERDbase") or die $!;
    $dbh->disconnect();
    
    #CREATE TABLE HMMERDbase(QueryProtID,pfam_id,HMMERDomain,HMMERTDomainDescription,QueryStartAlign REAL,QueryEndAlign REAL,PFAMStartAlign REAL,PFAMEndAlign REAL,FullSeqEvalue REAL,ThisDomainEvalue REAL,FullSeqScore REAL,FullDomainScore REAL);

    my $tmp_pfam_bulk_load_file = "tmp.pfam_bulk_load.$$";
    open (my $ofh, ">$tmp_pfam_bulk_load_file") or die "Error, cannot write to tmp file: $tmp_pfam_bulk_load_file";
    
    open (my $fh, $pfam_output) or die $!;
    while (<$fh>) {
        chomp;
        my $ln = $_;
        unless (/\w/) { next; }
        if (/^\#/) { next; }
        my @x = split(/\s+/);

        if (scalar @x < 22) {
            print STDERR "WARNING: Skipping line: $_ as likely corrupt.\n";
            next;
        }
        

        # hmmscan format:
        #0       Fe-ADH_2
        #1       PF13685.5
        #2       250
        #3       CUFF.50.1.p1
        #4       -

        # hmmsearch format:
        #0       CUFF.50.1.p1
        #1       -
        #2       423
        #3       Fe-ADH_2
        #4       PF13685.5
        #5       250

        
        next unless $x[3];  # domtbl

        my $QueryProtID;
        my $pfam_id;
        my $HMMERDomain;

        
        if ($x[1] =~ /^PF\d+/) {
            # hmmscan formatting 
            $QueryProtID = $x[3]; # CUFF.50.1.p1
            $HMMERDomain = $x[0]; # Fe-ADH_2
            $pfam_id = $x[1]; # PF13685.5
        }
        elsif ($x[4] =~ /^PF\d+/) {
            # hmmsearch formatting:
            $QueryProtID = $x[0]; # CUFF.50.1.p1
            $HMMERDomain = $x[3]; # Fe-ADH_2
            $pfam_id = $x[4]; # PF13685.5
        }
        else {
            confess "Error, cannot decipher pfam hit formatting: $ln ";
        }

        my $QueryStartAlign = $x[17];
        my $QueryEndAlign = $x[18];
        my $PFAMStartAlign = $x[15];
        my $PFAMEndAlign = $x[16];
        my $FullSeqEvalue = $x[6];
        my $ThisDomainEvalue = $x[12];
        my $FullSeqScore = $x[7];
        my $FullDomainScore = $x[13];

        print $ofh join("\t", $QueryProtID, $pfam_id, $HMMERDomain, "NULL",
                        $QueryStartAlign, $QueryEndAlign, $PFAMStartAlign, $PFAMEndAlign,
                        $FullSeqEvalue, $ThisDomainEvalue, $FullSeqScore, $FullDomainScore) . "\n";
        
    }
    close $ofh;


    &bulk_load_sqlite($sqlite_db, "HMMERDbase", $tmp_pfam_bulk_load_file);
    

    unlink($tmp_pfam_bulk_load_file);
        
    print STDERR "\n\nLoading complete..\n\n";
        
    exit(0);
    
}
