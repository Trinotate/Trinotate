#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;

use File::Basename;

use Getopt::Long qw(:config no_ignore_case bundling pass_through);

my $usage = <<__EOUSAGE__;

################################################################################
#
#  --transcriptome <string>      Transcriptome assembly fasta file
#
#  --path_to_rnammer <string>    Path to the rnammer software 
#                                (ie.  /usr/bin/software/rnammer_v1.2/rnammer)
#
#  Optional:
# 
#  --org_type <string>           arc|bac|euk   (default: euk)
#
################################################################################


__EOUSAGE__

    ;



my $transcriptome_fasta;
my $path_to_rnammer;
my $help_flag;
my $org_type = "euk";

&GetOptions ( 'help|h' => \$help_flag,
              'transcriptome=s' => \$transcriptome_fasta,
              'path_to_rnammer=s' => \$path_to_rnammer,
              'org_type=s' => \$org_type,
              );

if ($help_flag) {
    die $usage;
}

unless ($transcriptome_fasta && $path_to_rnammer) {
    die $usage;
}

main: {

    ## concatenate transcripts
    my $cmd = "$FindBin::RealBin/util/superScaffoldGenerator.pl $transcriptome_fasta transcriptSuperScaffold 100";
    &process_cmd($cmd);

    ## Run RNAMMER
    $cmd = "perl $path_to_rnammer -S $org_type -m tsu,lsu,ssu -gff tmp.superscaff.rnammer.gff < transcriptSuperScaffold.fasta";
    &process_cmd($cmd);
    
    ## Convert back to transcript features from the super scaffold features
    my $output_file = basename($transcriptome_fasta) . ".rnammer.gff";
    $cmd = "$FindBin::RealBin/util/rnammer_supperscaffold_gff_to_indiv_transcripts.pl -R tmp.superscaff.rnammer.gff -T transcriptSuperScaffold.bed > $output_file";
    &process_cmd($cmd);

    print "\n\nDone.  See output file: $output_file\n\n";

    exit(0);
}


####
sub process_cmd {
    my ($cmd) = @_;

    print STDERR "CMD: $cmd\n";
    my $ret = system($cmd);
    if ($ret) {
        die "Error, cmd: $cmd died with ret $ret";
    }

    return;
}
    
