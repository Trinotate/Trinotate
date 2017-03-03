#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use Getopt::Long qw(:config posix_default no_ignore_case bundling pass_through);
use FindBin;
use lib ("$FindBin::RealBin/../PerlLib");
use Pipeliner;
use IniReader;

my $usage = <<__EOUSAGE__;

##############################################################################
#
# Required:
#
#  --Trinotate_sqlite <string>                Trinotate.sqlite boilerplate database
#
#  --transcripts <string>                     transcripts.fasta
#
#  --gene_to_trans_map <string>               gene-to-transcript mapping file
#
#  --conf <string>                            config file
#
#  --CPU <int>                                number of threads to use.
#
#
##############################################################################


__EOUSAGE__

    ;


my $transcripts_fasta;
my $gene_to_trans_map;
my $conf_file;
my $CPU;
my $trinotate_sqlite;

my $help_flag;

&GetOptions ( 'h' => \$help_flag,
              
              'Trinotate_sqlite=s' => \$trinotate_sqlite,
              
              'transcripts=s' => \$transcripts_fasta,

              'gene_to_trans_map=s' => \$gene_to_trans_map,

              'conf=s' => \$conf_file,
              
              'CPU=i' => \$CPU,
              
    );


if ($help_flag) { die $usage; }

unless ($transcripts_fasta && $gene_to_trans_map && $conf_file && $CPU && $trinotate_sqlite) {
    die $usage;
}


main: {

    my $ini_reader = new IniReader($conf_file);

    my @sections = $ini_reader->get_section_headings();
    @sections = grep { $_ ne 'GLOBALS' } @sections;

    my %globals = $ini_reader->get_section_hash('GLOBALS');
    $globals{TRANSCRIPTS_FASTA} = $transcripts_fasta;
    $globals{GENE_TO_TRANS_MAP} = $gene_to_trans_map;
    $globals{CPU} = $CPU;
    $globals{TRINOTATE_HOME} = $FindBin::RealBin . "/../";
    $globals{TRINOTATE_SQLITE} = $trinotate_sqlite;
    

    ## get command structs
    my @cmd_structs;
    foreach my $section (@sections) {
        my %keyvals = $ini_reader->get_section_hash($section);
        $keyvals{__SECTION__} = $section;
        
        if ($keyvals{RUN} =~ /^T/i) {
            push (@cmd_structs, \%keyvals);
        }
    }

    ## build compute pipeline
    
    my $pipeliner = new Pipeliner(-verbose => 1);
    
    @cmd_structs = sort {$a->{RANK}<=>$b->{RANK}} @cmd_structs;

    foreach my $cmd_struct (@cmd_structs) {
        my $CMD = $cmd_struct->{CMD};
        $CMD = &substitute_tokens($CMD, \%globals);
        
        my $section_name = $cmd_struct->{__SECTION__};
        my $checkpoint_file = "chkpt.$section_name.ok";

        $pipeliner->add_commands( new Command($CMD, $checkpoint_file) );
    }
        
    $pipeliner->run();
    


    exit(0);
}


####
sub substitute_tokens {
    my ($cmd, $globals_href) = @_;

    my %token_templates;
    while ($cmd =~ /(\{__\S+__\})/g) {
        my $token_template = $1;
        
        $token_templates{$token_template}++;
    }

    if (%token_templates) {
        foreach my $token_template (keys %token_templates) {
            $token_template =~ /\{__(\S+)__\}/ or die "Error, not able to parse token template: $token_template";
            my $token_name = $1;

            my $replacement_val = $globals_href->{$token_name};
            unless (defined $replacement_val) {
                die "Error, unable to identify global value for token name: $token_name of cmd: $cmd";
            }
            $cmd =~ s/$token_template/$replacement_val/g;
        }
    }

    return($cmd);
}
        
        
