#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use Data::Dumper;


my $usage = "usage: $0 Trinotate_report.xls.gene_ontology [include_transcript_ids]\n\n";

my $trinotate_go_report_file = $ARGV[0] or die $usage;
my $include_transcript_ids_flag = $ARGV[1] || 0;

my $go_slim_file = "$FindBin::Bin/../../PerlLib/obo/goslim_generic.obo.gz";
unless (-s $go_slim_file) {
    die "Error, cannot locate required file: $go_slim_file - be sure to use the latest version of Trinotate, which should come with this file.";
}

main: {
    
    my %namespaces;
    my %go_slim = &parse_go_slim_file($go_slim_file, \%namespaces);
    
    open(my $fh, $trinotate_go_report_file) or die "Error, cannot open file: $trinotate_go_report_file";
    while (<$fh>) {
        chomp;
        my ($transcript_id, $go_listing) = split(/\t/);
        my @go_fields = split(/,/, $go_listing);

        foreach my $go_field (@go_fields) {
            if (my $go_slim_struct_href = $go_slim{$go_field}) {
                $go_slim_struct_href->{transcripts}->{$transcript_id} = 1; 
            }
        }
    }
    close $fh;

        
    ## generate report
    foreach my $namespace (sort keys %namespaces) {
        my @slim_go_ids = keys %{$namespaces{$namespace}};

        my @results;
        foreach my $slim_go_id (@slim_go_ids) {
            my $struct = $go_slim{$slim_go_id};
            my @transcripts = keys %{$struct->{transcripts}};
            my $num_transcripts = scalar(@transcripts);

            my $transcript_listing = join(",", @transcripts);
            if ( (! $include_transcript_ids_flag) || (! $transcript_listing)) {
                $transcript_listing = "."; # placeholder
            }
            
            push (@results, [$namespace,
                             $slim_go_id,
                             $struct->{name},
                             $num_transcripts,
                             $struct->{def},
                             $transcript_listing] );
            
        }

        @results = reverse sort {$a->[3]<=>$b->[3]} @results;
        foreach my $result (@results) {
            print join("\t", @$result) . "\n";
        }
        print "\n"; # spacer between namespaces
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
    
