#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::RealBin/../PerlLib");
use Pipeliner;

my $usage = "\n\n\tusage: $0 Database_prefix [no_cleanup_flag]\n\n\n";


my $prefix = $ARGV[0] or die $usage;
my $no_cleanup_flag = $ARGV[1] || 0;


my $UTILDIR = "$FindBin::RealBin/util";

## Resources:
my $SPROT_DAT_URL = "ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.dat.gz";
my $EGGNOG_DAT_URL = "http://eggnogdb.embl.de/download/eggnog_4.5/data/NOG/NOG.annotations.tsv.gz";
my $GENE_ONTOLOGY_DAT_URL = "http://purl.obolibrary.org/obo/go/go-basic.obo";
my $PFAM_DAT_URL = "ftp://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.gz";
#my $PFAM2GO_DAT_URL = "http://www.geneontology.org/external2go/pfam2go"; # ftp://ftp.geneontology.org/pub/go/external2go/pfam2go
my $PFAM2GO_DAT_URL = "ftp://ftp.geneontology.org/pub/go/external2go/pfam2go";


main: {

    my $checkpoint_dir = "__trino_chkpts";
    
    my $sqlite_db = "$prefix.sqlite";
    if (-e $sqlite_db && ! -d $checkpoint_dir) {
        print STDERR "\n\n\tERROR, database: $sqlite_db already exists.  Please remove or rename it before continuing.\n\n";
        exit(1);
    }
    

    my $pipeliner = new Pipeliner(-verbose => 2);

    unless (-d $checkpoint_dir) {
        mkdir $checkpoint_dir or die "Error, cannot mkdir $checkpoint_dir";
    }

    ## process Sprot dat file
    $pipeliner->add_commands(new Command("wget \"$SPROT_DAT_URL\"", "$checkpoint_dir/wget_sprot_dat.ok") );

    $pipeliner->add_commands(new Command("$UTILDIR/EMBL_swissprot_parser.pl uniprot_sprot.dat.gz $prefix", "$checkpoint_dir/parse_sprot_dat.ok"));
    
    $pipeliner->add_commands(new Command("mv uniprot_sprot.dat.gz.pep uniprot_sprot.pep",
                                         "$checkpoint_dir/rename_sprot_pep_file.ok"));
    
    

    # create sqlite database and load in the swissprot data:

    $pipeliner->add_commands(new Command("$UTILDIR/EMBL_dat_to_Trinotate_sqlite_resourceDB.pl --sqlite $sqlite_db --create", "$checkpoint_dir/init_sqlite_db.ok"));

    $pipeliner->add_commands(new Command("$UTILDIR/EMBL_dat_to_Trinotate_sqlite_resourceDB.pl --sqlite $sqlite_db --uniprot_index $prefix.UniprotIndex",
                             "$checkpoint_dir/uniprot_index_loading.ok") );

    $pipeliner->add_commands(new Command("$UTILDIR/EMBL_dat_to_Trinotate_sqlite_resourceDB.pl --sqlite $sqlite_db --taxonomy_index $prefix.TaxonomyIndex",
                             "$checkpoint_dir/taxonomy_index_loading.ok") );
    

    ##########
    ## EGGNOG
    $pipeliner->add_commands(new Command("wget \"$EGGNOG_DAT_URL\"", "$checkpoint_dir/eggnog_download.ok") );
    
    # extract fields
    $pipeliner->add_commands(new Command("gunzip -c NOG.annotations.tsv.gz | $UTILDIR/print.pl 1 5 > NOG.annotations.tsv.gz.bulk_load",
                                         "$checkpoint_dir/eggnog_field_extraction.ok") );  # note, had set -eou pipefail, but this generated errors on certain flavors and/or versions of linux
    # load 
    $pipeliner->add_commands(new Command("$UTILDIR/EMBL_dat_to_Trinotate_sqlite_resourceDB.pl --sqlite $sqlite_db --eggnog NOG.annotations.tsv.gz.bulk_load",
                                         "$checkpoint_dir/eggnog.load.ok") );
    
    
    
    ################
    ## Gene ontology

    $pipeliner->add_commands(new Command("wget \"$GENE_ONTOLOGY_DAT_URL\"", "$checkpoint_dir/go_download.ok"));

    $pipeliner->add_commands(new Command("$UTILDIR/obo_to_tab.pl go-basic.obo > go-basic.obo.tab",
                                         "$checkpoint_dir/go_obo_to_tab.ok"));

    $pipeliner->add_commands(new Command("$UTILDIR/EMBL_dat_to_Trinotate_sqlite_resourceDB.pl --sqlite $sqlite_db --go_obo_tab go-basic.obo.tab",
                                         "$checkpoint_dir/go_obo_load.ok"));

    


    ##############
    ## Pfam

    $pipeliner->add_commands(new Command("wget \"$PFAM_DAT_URL\"", "$checkpoint_dir/download_pfam.ok"));
    
    $pipeliner->add_commands(new Command("$UTILDIR/PFAM_dat_parser.pl Pfam-A.hmm.gz", "$checkpoint_dir/pfam_parsing.ok"));
    
    $pipeliner->add_commands(new Command("$UTILDIR/EMBL_dat_to_Trinotate_sqlite_resourceDB.pl --sqlite $sqlite_db --pfam Pfam-A.hmm.gz.pfam_sqlite_bulk_load",
                                         "$checkpoint_dir/pfam_loading.ok") );
    
    
    #############
    ## Pfam2Go

    $pipeliner->add_commands(new Command("wget \"$PFAM2GO_DAT_URL\" ",
                                         "$checkpoint_dir/pfam2go_download.ok") );

    $pipeliner->add_commands(new Command("$UTILDIR/PFAMtoGoParser.pl pfam2go > pfam2go.tab",
                                         "$checkpoint_dir/pfam2go_tab.ok"));

    $pipeliner->add_commands(new Command("$UTILDIR/EMBL_dat_to_Trinotate_sqlite_resourceDB.pl --sqlite $sqlite_db --pfam2go pfam2go.tab",
                                         "$checkpoint_dir/pfam2go_tab_loading.ok"));

    
    

    
    $pipeliner->run();



    unless ($no_cleanup_flag) {
        
        ## cleaning up:
        my @tmpfiles = qw(go-basic.obo
                          pfam2go
                          pfam2go.1
                          NOG.annotations.tsv.gz
                          NOG.annotations.tsv.gz.bulk_load
                          go-basic.obo.tab
                          Pfam-A.hmm.gz.pfam_sqlite_bulk_load
                          pfam2go.tab.tab
                          pfam2go.tab
        );
        
        push (@tmpfiles, "$prefix.UniprotIndex", "$prefix.TaxonomyIndex");
        
        foreach my $file (@tmpfiles) {
            unlink($file);
        }

    
        
        `rm -rf $checkpoint_dir`;
    
    }

    
    exit(0);
}


