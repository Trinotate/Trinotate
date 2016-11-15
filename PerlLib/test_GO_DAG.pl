#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::RealBin");
use GO_DAG;


my $go_dag = new GO_DAG();

#$go_dag->dump_DAG();
#die;

my @go_ids = @ARGV;

unless (@go_ids) {    

    for my $id (1..100) {
        my $go_id = sprintf("GO:%07d", $id);
        
        push (@go_ids, $go_id);
    }
}


foreach my $id (@go_ids) {
    
    if ($go_dag->node_exists($id)) {
        my @all_ids_in_path = $go_dag->get_all_ids_in_path($id);
        print "$id\t" . join(",", @all_ids_in_path) . "\n";
    }
    else {
        print "$id\tNOT FOUND\n";
    }
    
}

exit(0);



