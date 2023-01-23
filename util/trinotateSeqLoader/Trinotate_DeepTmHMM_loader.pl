#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");
use Fasta_reader;
use Carp;
use DBI;
use Sqlite_connect;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);
use Data::Dumper;

my $usage = <<__EOUSAGE__;

###########################################################################
#
# Required:
#
# --sqlite <string>  Trinotate sqlite database
#
# --deeptmhmm_gff3 <string>  deep  tmmhmm gff3 formatted output
#
###########################################################################


__EOUSAGE__


    ;



my $sqlite_db;
my $tmhmm_output;
my $help_flag;

&GetOptions( 'sqlite=s' => \$sqlite_db,
             'deeptmhmm_gff3=s' => \$tmhmm_output,
             
             'help|h' => \$help_flag,
    );

if ($help_flag) {
    die $usage;
}


unless ($sqlite_db && $tmhmm_output) {
    die $usage;
}


main: {
    
    unless (-s $sqlite_db) {
        die "Error, cannot locate the $sqlite_db database file";
    }
        
    my $dbh = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
    $dbh->do("delete from tmhmm") or die $!;
    $dbh->disconnect();
    
    # CREATE TABLE tmhmm(queryprotid,Score REAL,PredHel,Topology);

    my %feature_to_preds = &parse_DEEP_TmHMM_gff3($tmhmm_output);
    
    
    my $tmp_tmhmm_bulk_load_file = "tmp.tmhmm_bulk_load.$$";
    open (my $ofh, ">$tmp_tmhmm_bulk_load_file") or die "Error, cannot write to tmp file: $tmp_tmhmm_bulk_load_file";

    
    foreach my $prot_id (sort keys %feature_to_preds) {

        my @region_features = sort {$a->{region_start}<=>$b->{region_start}} @{$feature_to_preds{$prot_id}};
        my ($num_tm_helices, $tm_token) = &extract_tm_token(@region_features);
        
        my $queryprotid = $prot_id;
        my $score = "NULL";
        my $PredHel = $num_tm_helices;
        my $Topology = $tm_token;

        print $ofh join("\t", $queryprotid, $score, $PredHel, $Topology) . "\n";
    }
    close $ofh;

    &bulk_load_sqlite($sqlite_db, "tmhmm", $tmp_tmhmm_bulk_load_file);

    unlink($tmp_tmhmm_bulk_load_file);
        
    print STDERR "\n\nLoading complete..\n\n";
        
    exit(0);
}


####
sub parse_DEEP_TmHMM_gff3 {
    my ($tmhmm_file) = @_;

    my %prot_to_features;


    my $PARSING = 0;
    open(my $fh, $tmhmm_file) or confess "Error, cannot open file: $tmhmm_file";
    while (<$fh>) {
        if (/predicted TMRs: (\d+)/) {
            my $num_tmrs = $1;
            if ($num_tmrs > 0) {
                $PARSING = 1;
            }
            elsif ($num_tmrs == 0) {
                $PARSING = 0;
            }
            else {
                confess "Error, cannot decipher tmr count from line $_";
            }
        }
        elsif ($PARSING && (! /^\#/) && (! /^\//) ) {
            chomp;
            my ($prot_id, $region_type, $region_start, $region_end) = split(/\t/);
            push (@{$prot_to_features{$prot_id}}, { region_type => $region_type,
                                                    region_start => $region_start,
                                                    region_end => $region_end } );
        }
    }
    close $fh;

    return(%prot_to_features);
}


####
sub extract_tm_token {
    my @region_features = @_;

    my $num_TM_helices = 0;
    my @tokens;
    my $signal = "";
    my $prev_side_membrane = undef;
    foreach my $region_feature (@region_features) {
        my $region_type = $region_feature->{region_type};
        my $region_start = $region_feature->{region_start};
        my $region_end = $region_feature->{region_end};
        
        if ($region_type eq "signal") {
            $signal = "S\*${region_start}-${region_end}";
        }
        elsif ($region_type eq "TMhelix") {
            $num_TM_helices += 1;
            if (! defined $prev_side_membrane) {
                confess "Error, membrane side not defined before membrane spanning helix: " . Dumper(\@region_features);
            }
            my $opposite_side_membrane = ($prev_side_membrane eq "i") ? "o" : "i";
            unless(@tokens) {
                push (@tokens, "${prev_side_membrane}"); # only for first entry
            }
            push (@tokens, "${region_start}-${region_end}${opposite_side_membrane}");
        }
        elsif ($region_type eq "inside") {
            unless ( (! defined $prev_side_membrane) || $prev_side_membrane eq "o") {
                confess "Error, I/O features out of order: " . Dumper(\@region_features);
            }
            $prev_side_membrane = "i";
        }
        elsif ($region_type eq "outside") {
            unless ( (! defined $prev_side_membrane) || $prev_side_membrane eq "i") {
                confess "Error, I/O features out of order: " . Dumper(\@region_features);
            }
            $prev_side_membrane = "o";
        }
        else {
            die "Error, not processing features properly: " . Dumper(\@region_features);
        }
        

    }


    my $token = join("", @tokens);

    return($num_TM_helices, $signal . $token);
}

