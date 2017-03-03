#!/usr/bin/env perl

use strict;
use warnings;


use FindBin;
use lib ("$FindBin::RealBin/../PerlLib");
use Data::Dumper;
use Sqlite_connect;


my $usage = "usage: $0 Trinotate_db.sqlite\n\n";

my $sqlite_db = $ARGV[0] or die $usage;


# truncate the UniprotIndex table:
=ladeda

delete from UniprotIndex where not exists (select 1 from BlastDbase b where b.UniprotSearchString = UniprotIndex.Accession);

TAXONOMYINDEX..................................... 22621       19.1% 
GO................................................ 14976       12.6% 
EGGNOGINDEX....................................... 10608        8.9% 
HMMERDBASE........................................ 6880         5.8%


    delete from TaxonomyIndex where not exists (select 1 from UniprotIndex u where u.AttributeType = 'T' and u.LinkId = TaxonomyIndex.NCBITaxonomyAccession);


VACUUM;

=cut


main: {

    unless (-s $sqlite_db) {
        die "Error, cannot find sqlite database: $sqlite_db ";
    }
    
    my $dbproc = &connect_to_db($sqlite_db);
    
    &init_setup($dbproc);
    
    print STDERR "Removing unneeded uniprot descriptions ...\n";

    my $query = "delete from UniprotIndex where not exists (select 1 from BlastDbase b where b.UniprotSearchString = UniprotIndex.Accession)";
    &commit($dbproc, $query);


    print $STDERR "Removing unneeded taxonomy entries ...\n";
    $query = "delete from TaxonomyIndex where not exists (select 1 from UniprotIndex u where u.AttributeType = 'T' and u.LinkId = TaxonomyIndex.NCBITaxonomyAccession)";

    &commit($dbproc, $query);


    ## vacuum the database
    
    print STDERR "\n\nDone.\n\n";
    exit(0);

}

####
sub commit {
    my ($dbproc, $query) = @_;
    
    my $t1 = time();
    &RunMod($dbproc, $query);
    my $t2 = time();
    my $min = sprintf("%.1f", ($t2 - $t1)/60);
    print "\t[deletion took $min min.]\n\n";

    return;
}

####
sub init_setup {
    my ($dbproc) = @_;

    my $query = "pragma journal_mode=memory";
    &RunMod($dbproc, $query);

    $query = "pragma synchronous=0";
    &RunMod($dbproc, $query);

    $query = "pragma cache_size=4000000";
    &RunMod($dbproc, $query);

    return;
}


