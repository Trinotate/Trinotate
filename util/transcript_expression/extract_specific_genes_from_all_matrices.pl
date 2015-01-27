#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case bundling pass_through);

my $usage = "usage: $0 --gene_accs gene_list.txt --suffix <string>   matrix1 [matrix2 ...]\n\n";


my $help_flag;
my $gene_accs_file;
my $suffix = "selected";

&GetOptions ( 'h' => \$help_flag,
              'gene_accs=s' => \$gene_accs_file,
              'suffix=s' => \$suffix,
              );


my @matrices = @ARGV;

if ($help_flag || (! $gene_accs_file) || !@ARGV) {
    die $usage;
}

main: {
    
    my @gene_accs = `cat $gene_accs_file`;
    chomp @gene_accs;
    
    my %genes_want;
    foreach my $entry (@gene_accs) {
        if ($entry =~ /(comp\d+_c\d+)/) {
            my $core = $1;
            $genes_want{$core} = 1;
        }
        else {
            print STDERR "cannot parse component ID from $entry\n";
        }
    }
                                             
    

    foreach my $matrix (@matrices) {
        
        open (my $ofh, ">$matrix.$suffix") or die "Error, cannot write to $matrix.$suffix";
        open (my $fh, $matrix) or die $!;
        my $header = <$fh>;
        print $ofh $header;

        while (<$fh>) {
            my $line = $_;
            my @x = split(/\t/);
            my $acc = $x[0];
            if (/(comp\d+_c\d+)/) {
                my $core = $1;
                if ($genes_want{$core}) {
                    print $ofh $line;
                }
            }
        }
    }

    exit(0);
}


                                        
