#!/usr/bin/env perl

use strict;

my @keep = qw(
EMBL_dat_parser.pl
EMBL_dat_retrieve_via_id_list.pl
EMBL_dat_to_Trinotate_sqlite_resourceDB.pl
EMBL_sprot_n_uniref90_parser.pl
PFAM_dat_parser.pl
PFAMtoGoParser.pl
RunMeAdminTest.pl
TaxonomyUniq
Taxonomyvalue.pre
Trinotate.sqlite
cleanMe.pl
go.obo.sample.tab
init_Trinotate_sqlite_db.pl
notes
testData/



);

my %keep = map { + $_ => 1 } @keep;

foreach my $file (<*>, <testData/*>) {
    if (-f $file && ( ! $keep{$file} ) && $file !~ /\.(java|class|gz)$/) {
        print STDERR "-removing $file\n";
        unlink $file;
    }
}

