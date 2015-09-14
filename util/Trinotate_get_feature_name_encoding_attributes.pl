#!/usr/bin/env perl

use strict;
use warnings;

my $usage = "usage: $0 Trinotate.xls\n\n";

my $trinotate_xls = $ARGV[0] or die $usage;


main: {

    my %data;
    
    open (my $fh, $trinotate_xls) or die $!;
    my $header = <$fh>;
    chomp $header;
    my @fields = split(/\t/, $header);
    my %col_no_to_field;
    my %field_to_col_no;
    for (my $i = 0; $i <= $#fields; $i++) {
        my $field = $fields[$i];
        $field_to_col_no{$field} = $i;
        $col_no_to_field{$i} = $field;
    }


    print STDERR "-reading $trinotate_xls\n";
    while (<$fh>) {
        chomp;
        my @x = split(/\t/);
        my $gene_id = $x[0];
        my $trans_id = $x[1];

        foreach my $col_pos (2..$#x) {
            my $val = $x[$col_pos];
            if ($val ne ".") {
                my $field = $col_no_to_field{$col_pos};
                $data{$gene_id}->{$field}->{$val} = 1;
                $data{$trans_id}->{$field}->{$val} = 1;
            }
        }
    }
    close $fh;
    
    
    print STDERR "-generating annotated identifiers.\n";

    foreach my $feature_id (sort keys %data) {
        
        my @tokens;
        
        my $feature_data_href = $data{$feature_id};
        
        if (exists $feature_data_href->{'sprot_Top_BLASTX_hit'}) {
            my @top_blastx_hits = keys %{$feature_data_href->{'sprot_Top_BLASTX_hit'}};
            foreach my $top_blastx_hit (@top_blastx_hits) {
                my @vals = split(/\^/, $top_blastx_hit);
                my $hit = shift @vals;
                unless (grep { $_ eq $hit } @tokens) {
                    push (@tokens, $hit);
                }
            }
        }

        
        if (exists $feature_data_href->{'sprot_Top_BLASTP_hit'}) {
            my @top_blastp_hits = keys %{$feature_data_href->{'sprot_Top_BLASTP_hit'}};
            foreach my $top_blastp_hit (@top_blastp_hits) {
                my @vals = split(/\^/, $top_blastp_hit);
                my $hit = shift @vals;
                unless (grep { $_ eq $hit } @tokens) {
                    push (@tokens, $hit);
                }
            }
        }

        ## pfam
        if (exists $feature_data_href->{Pfam}) {
            my @pfam_hits = keys %{$feature_data_href->{Pfam}};
            my %phits;
            foreach my $pfam_hit (@pfam_hits) {
                my @vals = split(/\^/, $pfam_hit);
                my $domain_name = $vals[1];
                $phits{$domain_name}=1;
            }
            my @pfam_domains = sort keys %phits;
            push (@tokens, @pfam_domains);
        }
        
        ## sigP
        if (exists $feature_data_href->{SignalP}) {
            push (@tokens, "sigP");
        }
       
        ## tmhmm
        if (exists $feature_data_href->{TmHMM}) {
            my @tmhmm_info = keys %{$feature_data_href->{TmHMM}};
            my $info = shift @tmhmm_info;
            $info =~ /PredHel=(\d+)/ or die "Error, cannot parse tmhmm info from $info";
            push (@tokens, "Tm$1");
        }

        ## generate token:
        
        my $new_feature_id = join("^", $feature_id, @tokens);

        print join("\t", $feature_id, $new_feature_id) . "\n";
        
    }
    

    exit(0);
}


                 
