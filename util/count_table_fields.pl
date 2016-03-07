#!/usr/bin/env perl

use strict;
use warnings;

my $usage = "\n\n\tusage: $0 Trinotate.xls\n\n";

my $trinotate_file = $ARGV[0] or die $usage;

main: {

    open (my $fh, $trinotate_file) or die $!;
    
    my $header = <$fh>;
    chomp $header;
    my @fields = split(/\t/, $header);

    my %column_counter;    
    my @pos_to_field;
    for (my $i = 0; $i <= $#fields; $i++) {
        
        my $field = $fields[$i];
        $pos_to_field[$i] = $field;
        $column_counter{$field} = 0;
        
    }


    while (<$fh>) {
        chomp;
        my @x = split(/\t/);
        for (my $i = 0; $i <= $#x; $i++) {
            my $val = $x[$i];
            if ($val ne ".") {
                my $field = $pos_to_field[$i];
                $column_counter{$field}++;
            }
        }
    }
    close $fh;


    @fields = reverse sort {$column_counter{$a} <=> $column_counter{$b}} keys %column_counter;

    for my $field (@fields) {
        my $count = $column_counter{$field};
        print join("\t", $field, $count) . "\n";
    }


    exit(0);
}


