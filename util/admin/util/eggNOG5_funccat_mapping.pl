#!/usr/bin/env perl

# Builds the eggNOG v5 functional-category mapping (eggNOG_id <tab> COG_category letters)
# used by util/report_summary/util/assign_eggnog_funccats.pl, restricted to the eggNOG ids
# that SwissProt cross-references (so the shipped resource file stays small).
#
# Ids are written in the UniProt form (COG/KOG/arCOG as-is, de novo OGs prefixed 'ENOG50'),
# matching the eggnog column of the Trinotate report. When an id has categories at several
# taxonomic levels, the broadest level is preferred (root, then the superkingdoms).
#
# usage: eggNOG5_funccat_mapping.pl e5.og_annotations.tsv[.gz] uniprot_sprot.dat.gz > eggnog5.funccat.txt

use strict;
use warnings;

my $usage = "usage: $0 e5.og_annotations.tsv[.gz] uniprot_sprot.dat[.gz] > eggnog5.funccat.txt\n";
my $og_file = $ARGV[0] or die $usage;
my $sprot_file = $ARGV[1] or die $usage;

my %level_rank = ( 1 => 0, 2759 => 1, 2 => 2, 2157 => 3, 10239 => 4 );
my $default_rank = 9;

my %want;
{
    my $fh = &open_maybe_gz($sprot_file);
    while (<$fh>) {
        if (/^DR   eggNOG; ([^;]+);/) {
            $want{$1} = 1;
        }
    }
    close $fh;
}

my %best; # id -> [rank, cat]
{
    my $fh = &open_maybe_gz($og_file);
    while (my $line = <$fh>) {
        chomp $line;
        my ($tax_level, $og_id, $cog_cat) = split(/\t/, $line);
        next unless defined $cog_cat && $cog_cat =~ /^[A-Z]+$/;
        my $id = ($og_id =~ /^(COG|KOG|arCOG)/) ? $og_id : "ENOG50$og_id";
        next unless $want{$id};
        my $rank = exists $level_rank{$tax_level} ? $level_rank{$tax_level} : $default_rank;
        if (! exists $best{$id} || $rank < $best{$id}->[0]) {
            $best{$id} = [$rank, $cog_cat];
        }
    }
    close $fh;
}

foreach my $id (sort keys %best) {
    print join("\t", $id, $best{$id}->[1]) . "\n";
}

exit(0);

sub open_maybe_gz {
    my ($file) = @_;
    my $fh;
    if ($file =~ /\.gz$/) {
        open($fh, "gunzip -c $file |") or die "Error, cannot gunzip $file";
    }
    else {
        open($fh, $file) or die "Error, cannot open $file";
    }
    return $fh;
}
