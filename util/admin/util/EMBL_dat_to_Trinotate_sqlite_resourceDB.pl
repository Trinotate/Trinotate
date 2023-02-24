#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::RealBin/../../../PerlLib");
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
# --uniprot_index <string>      file.UniprotIndex
#
# --taxonomy_index <string>     file.TaxonomyIndex
#
# --pfam <string>               Pfam_A.hmm file
#
# --eggnog <string>             concatenated eggnog file
#
# --go_obo_tab <string>             gene ontology obo tab file
#
# --go_slim_tab <string>        gene ontology SLIM tab file
#
# --pfam2go <string>            pfam2go data file
#
# --go_slim_mappings <string>    go slim mappings file
#
##################################################################################

__EOUSAGE__

    ;



my $uniprot_index;
my $taxonomy_index;
my $pfam_file;
my $eggnog_file;
my $go_obo_tab_file;
my $help_flag;
my $create_flag;
my $sqlite_db;
my $pfam2go_file;
my $go_slim_file;
my $go_slim_mappings_file;

&GetOptions('h' => \$help_flag,
            'sqlite=s' => \$sqlite_db,
            'create' => \$create_flag,
            'uniprot_index=s' => \$uniprot_index,
            'taxonomy_index=s' => \$taxonomy_index,
            'pfam=s' => \$pfam_file,
            'eggnog=s' => \$eggnog_file,
            'go_obo_tab=s' => \$go_obo_tab_file,
            'pfam2go=s' => \$pfam2go_file,
            'go_slim_tab=s' => \$go_slim_file,
            'go_slim_mappings=s' => \$go_slim_mappings_file,
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

unless ($create_flag || $uniprot_index || $taxonomy_index || $pfam_file || $eggnog_file || $go_obo_tab_file || $pfam2go_file || $go_slim_file || $go_slim_mappings_file) {
    die $usage . "\n\n select an action to perform.\n";
}


my $bindir = $FindBin::RealBin;

if ($create_flag) {
    if (-s $sqlite_db) {
        unlink($sqlite_db);
    }
    my $cmd = "$bindir/init_Trinotate_sqlite_db.pl --sqlite $sqlite_db";
    &process_cmd($cmd);
}

if ($uniprot_index) {
    # parse uniprot dat file

    unless (-s $uniprot_index) {
        die "Error, cannot locate file $uniprot_index";
    }

    &Sqlite_connect::bulk_load_sqlite($sqlite_db, "UniprotIndex", $uniprot_index);
}

if ($taxonomy_index) {
    
    unless (-s $taxonomy_index) {
        die "Error, cannot locate file $taxonomy_index";
        
    }
    
    &Sqlite_connect::bulk_load_sqlite($sqlite_db, "TaxonomyIndex", $taxonomy_index);
}


if ($pfam_file) {
        
    &Sqlite_connect::bulk_load_sqlite($sqlite_db, "PFAMreference", $pfam_file);
}


if ($eggnog_file) {
    # import EggNog
    &Sqlite_connect::bulk_load_sqlite($sqlite_db, "eggNOGIndex", $eggnog_file); # already prepped for bulk loading
}

if ($pfam2go_file) {
 
    &Sqlite_connect::bulk_load_sqlite($sqlite_db, "pfam2go", $pfam2go_file);
    
}


# import gene ontology
if ($go_obo_tab_file) {
    
    my $cmd = "$FindBin::RealBin/obo_tab_to_sqlite_db.pl $sqlite_db go $go_obo_tab_file"; ## TODO: make bulk load like everything else here.
    &process_cmd($cmd);
    
}

if ($go_slim_file) {
    my $cmd = "$FindBin::RealBin/obo_tab_to_sqlite_db.pl $sqlite_db go_slim $go_slim_file"; ## TODO: make bulk load like everything else here.
    &process_cmd($cmd);
}


if ($go_slim_mappings_file) {
    &Sqlite_connect::bulk_load_sqlite($sqlite_db, "go_slim_mapping", $go_slim_mappings_file);
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


