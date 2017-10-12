#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/../PerlLib");
use Fasta_reader;
use GTF_utils;
use GFF3_utils;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);
use Data::Dumper;

my $usage = <<__EOUSAGE__;

###########################################################################
#
# Required:
#
#  --annot <string>        GTF or GFF3-formatted annotation file (must end in gtf or gff3)
#                             and should include CDS annotations in addition to transcripts and genes.
#  
#  --genome_fa <string>    genome fasta file
#
#  --out_prefix <string>   output prefix
#
###########################################################################



__EOUSAGE__


    ;


my $help_flag;
my $annot_file;
my $genome_fasta_file;
my $out_prefix;

&GetOptions( 
    'help|h' => \$help_flag,
    'annot=s' => \$annot_file,             
    'genome_fa=s' => \$genome_fasta_file,
    'out_prefix=s' => \$out_prefix,
    );


if ($help_flag) {
    die $usage;
}

unless ($annot_file && $genome_fasta_file && $out_prefix) {
    die $usage;
}

unless ($annot_file =~ /(gtf|gff3)$/i) {
    die "Error, must specify a gtf or gff3 annotation file\n";
}


main: {

    my $scaffold_to_genes_href;
    my $gene_obj_indexer_href = {};

    if ($annot_file =~ /gtf$/i) { 
        $scaffold_to_genes_href = GTF_utils::index_GTF_gene_objs_from_GTF($annot_file, $gene_obj_indexer_href);
    }
    else {
        $scaffold_to_genes_href = GFF3_utils::index_GFF3_gene_objs($annot_file, $gene_obj_indexer_href);
    }
        
    my $fasta_reader = new Fasta_reader($genome_fasta_file);
    
    my %genome_seqs = $fasta_reader->retrieve_all_seqs_hash();


    ## prep outputs:
    #

    # transcript fasta file:
    my $transcripts_cdna_fasta_file = "$out_prefix.transcripts.cdna.fa";
    open(my $transcripts_ofh, ">$transcripts_cdna_fasta_file") or die "Error, cannot write to $transcripts_cdna_fasta_file";

    # protein fasta file
    my $protein_fasta_file = "$out_prefix.proteins.fa";
    open(my $proteins_ofh, ">$protein_fasta_file") or die "Error, cannot write to $protein_fasta_file";

    # gene-to-trans-mapping
    my $gene_trans_map_file = "$out_prefix.gene-to-trans-map";
    open(my $gene_trans_map_ofh, ">$gene_trans_map_file") or die "Error, cannot write to $gene_trans_map_file";

    
    
    foreach my $scaffold (keys %$scaffold_to_genes_href) {
        
        my @gene_ids = @{$scaffold_to_genes_href->{$scaffold}};
        
        my $chr_seq = $genome_seqs{$scaffold};

        foreach my $gene_id (@gene_ids) {
            
            my $gene_obj = $gene_obj_indexer_href->{$gene_id} or die "Error, cannot locate gene_obj for $gene_id";
            
            $gene_obj->create_all_sequence_types(\$chr_seq);
            
            foreach my $trans_obj ($gene_obj, $gene_obj->get_additional_isoforms()) {

                my $gene_id = $trans_obj->{TU_feat_name};
                my $model_id = $trans_obj->{Model_feat_name};

                print $gene_trans_map_ofh "$gene_id\t$model_id\n";
                
                my ($lend, $rend) = sort {$a<=>$b} $trans_obj->get_coords();
                my $orient = $trans_obj->get_orientation();
            
                my $annotation = $trans_obj->{com_name};
                
                my $transcript_seq = $trans_obj->get_cDNA_sequence();
                my $transcript_id = $model_id; # alias
                
                print $transcripts_ofh ">$model_id $gene_id\n$transcript_seq\n";
                
                if (my $protein_seq = $trans_obj->get_protein_sequence()) {
                    my $prot_len = length($protein_seq);
                    my $cds_seq = $trans_obj->get_CDS_sequence();
                    my $cds_rel_start = index($transcript_seq, $cds_seq);
                    if ($cds_rel_start < 0) { 
                        die "Error, cannot map cds within cdna sequence";
                    }
                    $cds_rel_start += 1; # make 1-based coords
                    
                    my $cds_rel_end = $cds_rel_start + length($cds_seq) - 1;
                                        
                    print $proteins_ofh ">$transcript_id.pep $gene_id ${transcript_id}:${cds_rel_start}-${cds_rel_end}\(+)\n$protein_seq\n";
                }
                                
                
            }
        }
    }


    close $transcripts_ofh;
    close $proteins_ofh;
    close $gene_trans_map_ofh;
        
    print STDERR "\ndone.\n";

    exit(0);
    
}

