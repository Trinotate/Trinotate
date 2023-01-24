#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;

use Data::Dumper;

my $usage = "usage: $0 pfam.dat\n\n";

my $pfam_dat_file = $ARGV[0] or die $usage;

=sqlite_structure

          pfam_accession = PF08793.5
         pfam_domainname = 2C_adapt
  pfam_domaindescription = 2-cysteine
Sequence_GatheringCutOff = 20.1
  Domain_GatheringCutOff = 20.1
  Sequence_TrustedCutOff = 21.2
    Domain_TrustedCutOff = 20.1
    Sequence_NoiseCutOff = 19.4
      Domain_NoiseCutOff = 19.8


## pfam record:

 //
HMMER3/b [3.0 | March 2010]
NAME  120_Rick_ant
ACC   PF12574.3
DESC  120 KDa Rickettsia surface antigen
LENG  255
ALPH  amino
RF    no
CS    no
MAP   yes
DATE  Tue Sep 27 11:43:56 2011
NSEQ  7
EFFN  0.796387
CKSUM 2501422644
    GA    21.00 21.00;
TC    22.70 21.60;
NC    19.20 18.90;




=cut


main: {

    my %data;
    
    
    my $fh;
    if ($pfam_dat_file =~ /\.gz/) {
        open ($fh, "gunzip -c $pfam_dat_file | ") or die $!;
    }
    else {
        open ($fh, $pfam_dat_file) or die $!;
    }
    
    open (my $ofh, ">$pfam_dat_file.pfam_sqlite_bulk_load") or die $!;

    my $record_counter = 0;
    while (<$fh>) {

        if (m|^//|) {

            $record_counter++;
            
            print STDERR "\r[$record_counter]  " if $record_counter % 100 == 0;
            
            if (%data) {
                ## process record

                my $pfam_accession = $data{ACC} or die "Error, no ACC for record: " . Dumper(\%data);
                my $pfam_domainname = $data{NAME} or die "Error, no NAME for record " . Dumper(\%data);
                my $pfam_domaindescription = $data{DESC} or die "Error, no DESC for record " . Dumper(\%data);
                
                my $gathering_cutoffs = $data{GA} or die "Error, no GA for record " . Dumper(\%data);
                $gathering_cutoffs =~ s/;//;
                my ($Sequence_GatheringCutOff, $Domain_GatheringCutOff) = split(/\s+/, $gathering_cutoffs);
                
                my $trusted_cutoffs = $data{TC} or die "Error, no TC for record " . Dumper(\%data);
                $trusted_cutoffs =~ s/;//;
                my ($Sequence_TrustedCutOff, $Domain_TrustedCutOff) = split(/\s+/, $trusted_cutoffs);
                
                my $noise_cutoffs = $data{NC} or die "Error, no NC for record " . Dumper(\%data);
                $noise_cutoffs =~ s/;//;
                my ($Sequence_NoiseCutOff, $Domain_NoiseCutOff) = split(/\s+/, $noise_cutoffs);

                print $ofh join("\t", $pfam_accession, $pfam_domainname, $pfam_domaindescription,
                                $Sequence_GatheringCutOff, $Domain_GatheringCutOff,
                                $Sequence_TrustedCutOff, $Domain_TrustedCutOff,
                                $Sequence_NoiseCutOff, $Domain_NoiseCutOff) . "\n";
                

            }
            %data = (); # clear for next record
        }
        if (/^(\S+)\s+(.*)$/) {
            $data{$1} = $2;
        }
    }
    close $fh;
    close $ofh;
    
    exit(0);
}
