#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::Bin/../PerlLib");
use Sqlite_connect;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);
use File::Basename;

my $usage = <<__EOUSAGE__;

###################################################################################
#
# --sqlite <string>             name of the Trinotate sqlite database to create.
#
# --create                      create a new Trinotate sqlite database
#
# --embl_dat <string>           EMBL dat file  (ex. swissprot.dat or trembl.dat)
#
# --pfam <string>               Pfam_A.hmm file
#
# --eggnog <string>             concatenated eggnog file
#
# --go_obo <string>             gene ontology obo file
#
# --pfam2go <string>            pfam2go data file
#
##################################################################################

__EOUSAGE__

    ;



my $embl_dat_file;
my $pfam_file;
my $eggnog_file;
my $go_obo_file;
my $help_flag;
my $create_flag;
my $sqlite_db;
my $pfam2go_file;

&GetOptions('h' => \$help_flag,
            'sqlite=s' => \$sqlite_db,
            'create' => \$create_flag,
            'embl_dat=s' => \$embl_dat_file,
            'pfam=s' => \$pfam_file,
            'eggnog=s' => \$eggnog_file,
            'go_obo=s' => \$go_obo_file,
            'pfam2go=s' => \$pfam2go_file,
            );


if (@ARGV) {
    die "Error, don't understand params: @ARGV";
}

if ($help_flag) {
    die $usage;
}
unless ($sqlite_db) {
    die $usage . "\n SQLITE database name required\n";
}

unless ($create_flag || $embl_dat_file || $pfam_file || $eggnog_file || $go_obo_file || $pfam2go_file) {
    die $usage . "\n\n select an action to perform.\n";
}


my $bindir = $FindBin::Bin;

if ($create_flag) {
    if (-s $sqlite_db) {
        unlink($sqlite_db);
    }
    my $cmd = "java -cp $bindir:$bindir/../java/sqlitejdbc-v056.jar CreateJavaSQLliteTables $sqlite_db";
    &process_cmd($cmd);
}

if ($embl_dat_file) {
    # parse uniprot dat file
    my $uniprot_index_bulk_load_file = "$embl_dat_file.UniprotIndex";
    my $taxonomy_index_bulk_load_file = "$embl_dat_file.TaxonomyIndex";
    
    if (! (-s $uniprot_index_bulk_load_file && -s $taxonomy_index_bulk_load_file) ) {
        my $cmd = "$bindir/EMBL_dat_parser.pl $embl_dat_file $embl_dat_file";
        &process_cmd($cmd);
    }
    
    &Sqlite_connect::bulk_load_sqlite($sqlite_db, "UniprotIndex", $uniprot_index_bulk_load_file);
    &Sqlite_connect::bulk_load_sqlite($sqlite_db, "TaxonomyIndex", $taxonomy_index_bulk_load_file);
}


if ($pfam_file) {
    # import PFAM
    my $pfam_bulk_load_file = "$pfam_file.pfam_sqlite_bulk_load";
    if (! -s $pfam_bulk_load_file) {
        my $cmd = "$bindir/PFAM_dat_parser.pl $pfam_file";
        &process_cmd($cmd);
    }
    
    &Sqlite_connect::bulk_load_sqlite($sqlite_db, "PFAMreference", $pfam_bulk_load_file);
}


if ($eggnog_file) {
    # import EggNog
    &Sqlite_connect::bulk_load_sqlite($sqlite_db, "eggNOGIndex", $eggnog_file); # already prepped for bulk loading
}

if ($pfam2go_file) {
    my $cmd = "$bindir/PFAMtoGoParser.pl $pfam2go_file > $pfam2go_file.tab";
    &process_cmd($cmd);
    
    &Sqlite_connect::bulk_load_sqlite($sqlite_db, "pfam2go", "$pfam2go_file.tab");
    
}


# import gene ontology
if ($go_obo_file) {
    my $go_obo_tab = basename($go_obo_file) . ".tab";
    if (-s $go_obo_tab) {
        print STDERR "-reusing existing $go_obo_tab file\n";
    }
    else {
        my $cmd = "$bindir/../util/gene_ontology/obo_to_tab.pl $go_obo_file > $go_obo_tab";
        &process_cmd($cmd);
    }
    
    my $cmd = "$bindir/../util/gene_ontology/obo_tab_to_sqlite_db.pl $sqlite_db $go_obo_tab";
    &process_cmd($cmd);
    
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


