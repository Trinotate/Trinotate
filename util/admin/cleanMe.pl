#!/usr/bin/env perl

use strict;
use warnings;


## cleaning up:
my @tmpfiles = qw(go-basic.obo
                          pfam2go
                          pfam2go.1
                          e5.og_annotations.tsv.gz
                          e5.og_annotations.bulk_load
                          go-basic.obo.tab
                          Pfam-A.hmm.gz.pfam_sqlite_bulk_load
                          pfam2go.tab.tab
                          pfam2go.tab
                          trinotate.sqlite
                          Pfam-A.hmm.gz
        );

push (@tmpfiles, <*.UniprotIndex>, <*.TaxonomyIndex>, <uniprot_sprot.*>);

foreach my $file (@tmpfiles) {
    if (-e $file) {
        print STDERR "-removing file: $file\n";
        unlink($file);
    }
}

`rm -rf __trino_chkpts`;


exit(0);

