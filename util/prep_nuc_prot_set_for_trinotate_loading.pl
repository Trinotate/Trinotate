#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);

use FindBin;
use lib ("$FindBin::RealBin/../PerlLib");
use Fasta_reader;
use Data::Dumper;

my $usage = <<__EOUSAGE__;

############################################################################################
#
# --trans <string>      transcripts.fasta
#
# --pep <string>        proteins that map perfectly to above transcripts.fasta using tblastn
#
#############################################################################################


__EOUSAGE__

    ;



my $help_flag;
my $trans_file;
my $pep_file;



&GetOptions ( 'h' => \$help_flag,
              'trans=s' => \$trans_file,
              'pep=s' => \$pep_file,
    );


if ($help_flag) {
    die $usage;
}

unless ($trans_file && $pep_file) {
    die $usage;
}

## need to use blast+ ... ensure the tools are available.

foreach my $tool qw(makeblastdb tblastn) {
    my $path = `which $tool`;
    unless ($path =~ /\w/) {
        die "Error, cannot find path to utility: $tool.  Please be sure BLAST+ is installed. ";
    }
}


main: {

    ## blast the peps against the trans
    my $cmd = "makeblastdb -in $trans_file -dbtype nucl";
    &process_cmd($cmd);

    my $blast_out = "tmp_tblastn.$$.outfmt6";
    $cmd = "tblastn -db $trans_file -query $pep_file -max_target_seqs 1 -outfmt 6 -seg no > $blast_out";
    &process_cmd($cmd);

    my %top_hits;
    open (my $fh, $blast_out) or die "Error, cannot open file $blast_out";
    while (<$fh>) {
        chomp;
        my @x = split(/\t/);
        my $pep_acc = $x[0];
        my $trans_acc = $x[1];
        my $per_id = $x[2];
        my $pep_lend = $x[6];
        my $pep_rend = $x[7];
        my $trans_end5 = $x[8];
        my $trans_end3 = $x[9];
      
        my ($trans_lend, $trans_rend, $orient) = ($trans_end5 < $trans_end3) 
            ? ($trans_end5, $trans_end3, '+')
            : ($trans_end3, $trans_end5, '-');
        
        $top_hits{$pep_acc} = { trans_acc => $trans_acc,
                                per_id => $per_id,
                                pep_lend => $pep_lend,
                                pep_rend => $pep_rend,
                                trans_lend => $trans_lend,
                                trans_rend => $trans_rend,
                                orient => $orient,
        };
        
        
    }
    close $fh;

    {
        ## write trinotate-compatible pep file
        open (my $ofh, ">trinotate_pep_file_to_load.pep") or die "Error, cannot write new pep file";
        my $fasta_reader = new Fasta_reader($pep_file);
        while (my $seq_obj = $fasta_reader->next()) {
            my $acc = $seq_obj->get_accession();
            my $sequence = $seq_obj->get_sequence();
            
            my $trans_hit_ref = $top_hits{$acc};
            unless (ref $trans_hit_ref) {
                print STDERR "ERROR: no mapping of peptide $acc to a transcript... skipping.\n";
                next;
            }
            
            my $pep_length = length($sequence);
            if ($trans_hit_ref->{pep_lend} != 1 or $trans_hit_ref->{pep_rend} != $pep_length) {
                print STDERR "WARNING, complete peptide for $acc does not map within transcript sequence: pep_len: $pep_length, mapping: " . Dumper($trans_hit_ref);
                
            }
            
            my $header_line = ">$acc len:$pep_length " 
                . $trans_hit_ref->{trans_acc} 
            . ":" . $trans_hit_ref->{trans_lend} . "-" . $trans_hit_ref->{trans_rend}
            . "(" . $trans_hit_ref->{orient} . ")";
            
            $sequence =~ s/(\S{60})/$1\n/g; # fasta format
            print $ofh "$header_line\n$sequence\n";
            
        }
    
        close $ofh;
    }
    

    ## generate the gene-to-trans mapping file
    {
        
        open (my $ofh, ">trinotate.gene-to-trans.mapping") or die "Error, cannot write gene to trans mapping file";

        open (my $fh, $trans_file) or die "Error, cannot open file $trans_file";
        while (<$fh>) {
            if (/>(\S+)/) {
                my $trans_acc = $1;
                print $ofh "gene.$trans_acc\t$trans_acc\n";
            }
        }
        close $fh;
        close $ofh;

    }

    print "\n\n\nDone.  Use the following files with Trinotate loading:\n"
        . "\t$trans_file\n"
        . "\ttrinotate_pep_file_to_load.pep\n"
        . "\ttrinotate.gene-to-trans.mapping\n\n";

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
