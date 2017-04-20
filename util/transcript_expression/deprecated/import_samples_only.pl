#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use Getopt::Long qw(:config no_ignore_case bundling);
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");
use DBI;
use Sqlite_connect;
use Data::Dumper;

my $usage = <<__EOUSAGE__;

#################################################################################################
#
# Required:
#
#  --sqlite <string>         path to the Trinotate sqlite database
#
#  --samples_file <string>        file describing samples and replicates
#
#
##################################################################################################


__EOUSAGE__

    ;


my $sqlite;
my $help_flag;
my $samples_file;

&GetOptions (  'h' => \$help_flag,
               
               'sqlite=s' => \$sqlite,

               'samples_file=s' => \$samples_file,

               );


if ($help_flag) {
    die $usage;
}

unless ($sqlite
        &&
        $samples_file
        ) {
    die $usage;
}


unless (-s $sqlite) {
    die "Error, cannot find db: $sqlite ";
}

our $SEE = 0;


main: {

    my $dbproc = DBI->connect( "dbi:SQLite:$sqlite" ) || die "Cannot connect: $DBI::errstr";

    my %samples = &parse_samples_file($samples_file);
    
    print STDERR "Samples and replicates: " . Dumper(\%samples);
    
    my %samples_n_reps_to_ID = &get_sample_ids($dbproc, \%samples);
    
    print STDERR "Done.  Loaded: " . Dumper(\%samples_n_reps_to_ID);
    
    exit(0);
                        
}

####
sub parse_samples_file {
    my ($samples_file) = @_;

    my %sample_to_reps;

    open (my $fh, $samples_file) or die "Error, cannot open file: $samples_file";
    while (<$fh>) {
        chomp;
        unless (/\w/) { next; }
        if (/^\#/) { next; }
        
        my ($sample, $rep_name, @rest) = split(/\t/);
        
        if (defined ($sample) && defined ($rep_name) ) {
            $sample_to_reps{$sample}->{$rep_name} = 1;
        }
    }
    close $fh;
    
    return(%sample_to_reps);
}

####
sub get_sample_ids {
    my ($dbproc, $samples_href) = @_;

    my %sample_and_rep_ids;
    
    my $max_sample_no = 0;
    my $max_rep_no = 0;

    ## get existing assignments
    {
        my $query = "select sample_id, sample_name from Samples";
        my @results = &do_sql_2D($dbproc, $query);
        foreach my $result (@results) {
            my ($sample_id, $sample_name) = @$result;
            $sample_and_rep_ids{sample}->{$sample_name} = $sample_id;
            $sample_id =~ s/\D//g;
            if ($sample_id > $max_sample_no) {
                $max_sample_no = $sample_id;
            }
        }
    }
    
    {
        my $query = "select replicate_id, replicate_name from Replicates";
        my @results = &do_sql_2D($dbproc, $query);
        foreach my $result (@results) {
            my ($replicate_id, $replicate_name) = @$result;
            $sample_and_rep_ids{replicate}->{$replicate_name} = $replicate_id;
            $replicate_id =~ s/\D//g;
            if ($replicate_id > $max_rep_no) {
                $max_rep_no = $replicate_id;
            }
        }
    }

    ## insert those that don't already exist.
    foreach my $sample (keys %$samples_href) {
        
        my $sample_id = $sample_and_rep_ids{sample}->{$sample};
        unless ($sample_id) {
            ## insert it
            $sample_id = "S" . ++$max_sample_no;
            &do_sql($dbproc, "insert into Samples (sample_id, sample_name) values (?,?)", $sample_id, $sample);
            $sample_and_rep_ids{sample}->{$sample} = $sample_id;;
        }
        
        foreach my $replicate (keys %{$samples_href->{$sample}}) {

            unless ($sample_and_rep_ids{replicate}->{$replicate}) {
                ## insert it
                my $rep_id = "R" . ++$max_rep_no;
                &do_sql($dbproc, "insert into Replicates (replicate_id, replicate_name, sample_id) values (?,?,?)",
                        $rep_id, $replicate, $sample_id);
                $sample_and_rep_ids{replicate}->{$replicate} = $rep_id;
            }
        }
    }


    $dbproc->commit;
    
    return(%sample_and_rep_ids);
}


