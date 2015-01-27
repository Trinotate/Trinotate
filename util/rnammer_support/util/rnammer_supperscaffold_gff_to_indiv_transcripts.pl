#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case bundling pass_through);

my $usage =  <<__EOUSAGE__;

################################################################################
#
#  --rnammmer_gff|R <string>             rnammer superscaffold gff
#
#  --transcript_scaffolding|T <string>   transcript super-scaffolding bed file
#
################################################################################


__EOUSAGE__


    ;


my $rnammer_gff_file;
my $transcript_scaffolding_file;
my $help_flag;

&GetOptions( "rnammer_gff|R=s" => \$rnammer_gff_file,
             "transcript_scaffolding|T=s" => \$transcript_scaffolding_file,
             
             "help|h" => \$help_flag,
             );

unless ($rnammer_gff_file && $transcript_scaffolding_file) {
    die $usage;
}



main: {

    my @rnammer_features = &get_rnammer_features($rnammer_gff_file);

    unless (@rnammer_features) {
        die "WARNING: No RNAMMER features are described in file: $rnammer_gff_file";
    }

    @rnammer_features = sort {$a->{lend}<=>$b->{lend}} @rnammer_features;
    
    

    open (my $fh, $transcript_scaffolding_file) or die "Error, cannot open file $transcript_scaffolding_file";
  rnammer_mappings:
    while (<$fh>) {
        chomp;
        my @x = split(/\t/);
        my $acc = $x[3];
        my $lend = $x[1];
        my $rend = $x[2];
        
        while (@rnammer_features && $rnammer_features[0]->{rend} < $lend) {
            shift @rnammer_features;
        }
        unless (@rnammer_features) {
            ## done.
            last rnammer_mappings;
        }
        
        ## check overlap
        if ($rend > $rnammer_features[0]->{lend} && $lend < $rnammer_features[0]->{rend}) {
            ## got overlap
            
            ## examine all potential rnammer annotations across contig:
          rnammer_overlap_search:
            for (my $i = 0; $i <= $#rnammer_features; $i++) {

                if ($rend > $rnammer_features[$i]->{lend} && $lend < $rnammer_features[$i]->{rend}) {

                    my $repeat_lend = ($rnammer_features[$i]->{lend} < $lend) ? $lend : $rnammer_features[$i]->{lend};
                    my $repeat_rend = ($rnammer_features[$i]->{rend} > $rend) ? $rend : $rnammer_features[$i]->{rend};
                    
                    ## want transcript-based coordinates
                    my $trans_lend = $repeat_lend - $lend + 1;
                    my $trans_rend = $repeat_rend - $lend + 1;
                    
                    print join("\t", $acc, "RNAmmer", "rRNA", $trans_lend, $trans_rend, 
                               $rnammer_features[$i]->{score}, $rnammer_features[$i]->{orient}, ".",
                               $rnammer_features[$i]->{type}) . "\n";
                }
                else {
                    last rnammer_overlap_search;
                }
            }
        }
                               


    }
    close $fh;

    exit(0);

}

####
sub get_rnammer_features {
    my ($file) = @_;
    
    my @features;

    my $scaff_id = "";

    open (my $fh, $file) or die "Error, cannot open file $file";
    while (<$fh>) {
        if (/^\#/) { next; }
        chomp;
        my @x = split(/\t/);
        
        my ($scaff, $lend, $rend, $score, $orient, $attribute) = ($x[0], $x[3], $x[4], $x[5], $x[6], $x[8]);
        
        if ($scaff_id && $scaff ne $scaff_id) {
            die "Error, supposed to be a single super scaffold, but finding multiple scaff ids: $scaff_id, $scaff";
        }

        push (@features, { lend => $lend,
                           rend => $rend,
                           score => $score,
                           orient => $orient,
                           type => $attribute,
                       });

    }
    close $fh;
    
    return(@features);
}
