#!/usr/bin/env perl

use strict;
use warnings;

use Carp;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);

use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");
use GO_DAG;
use DelimParser;


main: {
   
    my $go_slim_file = "$FindBin::Bin/../../PerlLib/obo/goslim_generic.obo.gz";
    unless (-s $go_slim_file) {
        die "Error, cannot locate required file: $go_slim_file - be sure to use the latest version of Trinotate, which should come with this file.";
    }

    my $go_dag = new GO_DAG();

    my @all_GO_ids = $go_dag->get_all_ids();


    # get slim info
    my %namespaces;
    my %go_slim = &parse_go_slim_file($go_slim_file, \%namespaces);

    print "go_id\tslim_id\n";
    
    foreach my $go_id (@all_GO_ids) {
        
        my @parent_go_terms = $go_dag->get_all_ids_in_path($go_id);
        foreach my $parent_go (@parent_go_terms) {
            if (my $slim_entry = $go_slim{$parent_go}) {
                print join("\t", $go_id, $parent_go) . "\n";
            }
        }
    }
    
    exit(0);
}


####
sub parse_go_slim_file {
    my ($go_slim_file, $namespaces_href) = @_;

    my %go_slim;

    my %curr_entry;
    my $on_flag = 0;
    open (my $fh, "gunzip -c $go_slim_file |") or die "Error, cannot open $go_slim_file via gunzip ";
    while (<$fh>) {
        unless (/\w/) { next; }
        chomp;
        if (/^\[/) {
            if (%curr_entry) {
                &add_entry(\%curr_entry, \%go_slim, $namespaces_href);
            }
            %curr_entry = ();
            $on_flag = 0;
            if (/^\[Term\]/) {
                $on_flag = 1;
            }
        }
        elsif ($on_flag) {
            my ($token, $val) = split(/\s+/, $_, 2);
            $curr_entry{$token} = $val;
        }
    }
    close $fh;
    if (%curr_entry) {
        &add_entry(\%curr_entry, \%go_slim, $namespaces_href);
    }

    return(%go_slim);
}

####
sub add_entry {
    my ($curr_entry_href, $go_slim_href, $namespaces_href) = @_;

    my $id = $curr_entry_href->{'id:'} or die "Error, no id: field for " . Dumper($curr_entry_href);
    
    my $name = $curr_entry_href->{'name:'} or die "Error, no name: field for " . Dumper($curr_entry_href);

    my $namespace = $curr_entry_href->{'namespace:'} or die "Error, no namespace: field for " . Dumper($curr_entry_href);

    my $def = $curr_entry_href->{'def:'} or die "Error, no def field for " . Dumper($curr_entry_href);
    $def =~ s/\t/ /g; # just in case
    
    $go_slim_href->{$id} = { id => $id,
                             name => $name,
                             namespace => $namespace,
                             def => $def,
                             
                             transcripts => {}, # store transcripts later.
    };

    $namespaces_href->{$namespace}->{$id} = 1;
    
    return;
}

            
