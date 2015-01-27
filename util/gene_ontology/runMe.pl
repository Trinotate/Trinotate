#!/usr/bin/env perl

use strict;
use warnings;

unless (-s "gene_ontology_ext.obo") {
    &process_cmd("wget http://www.geneontology.org/ontology/obo_format_1_2/gene_ontology_ext.obo");
}

unless (-s "gene_ontology_ext.obo.tab") {
    &process_cmd("./obo_to_tab.pl gene_ontology_ext.obo > gene_ontology_ext.obo.tab");
}

unless (-s "GO.sqlite") {
    &process_cmd("./obo_tab_to_sqlite_db.pl gene_ontology_ext.obo.tab");
}

exit(0);

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

