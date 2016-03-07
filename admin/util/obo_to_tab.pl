#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;

my $usage = "usage: gene_ontology_ext.obo\n\n";

my $gene_ontology_file = $ARGV[0] or die $usage;

main: {

    my %dat;
    
    open (my $fh, $gene_ontology_file) or die $!;
    while (<$fh>) {
        unless (/\w/) { next; }
        chomp;
        if (/^\[Term\]/) {
            if (%dat) {
                &dump_entry(%dat);
                %dat = ();
            }
        }
        else {
            my ($field, $annot) = split(/\s+/, $_, 2);
            $dat{$field} = $annot;
        }
    }
    close $fh;
    
    
    &dump_entry(%dat); # get last one
    
    
    exit(0);
    
}

####
sub dump_entry {
    my (%dat) = @_;

    my $id = $dat{"id:"};
    unless (defined $id) { return; }
    
    my $name = $dat{"name:"} || "";
    my $namespace = $dat{"namespace:"} || "";
    my $def = $dat{"def:"} || "";
    
    print join("\t", $id, $name, $namespace, $def) . "\n";
 
    return;
}
