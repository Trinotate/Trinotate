#!/usr/bin/env perl

# Converts the eggNOG v5 orthologous-group annotation table (e5.og_annotations.tsv)
# into the 2-column (eggNOG_id <tab> description) bulk-load file for the eggNOGIndex table.
#
# Input columns: tax_level, OG_id, COG_functional_category, description
#   e.g.   2759    KOG4258   KLT   insulin receptor substrate binding
#          2759    2RY34     S
#
# UniProt (SwissProt) eggNOG cross-references use COG/KOG/arCOG ids as-is, and prefix
# eggNOG v5 de novo OG ids with 'ENOG50' (eg. 2RY34 -> ENOG502RY34), so ids are written
# here in the UniProt form to allow a direct join on UniprotIndex.LinkId.
#
# COG/KOG/arCOG ids recur across taxonomic levels with differing descriptions; one is
# chosen per id, preferring the broadest level (root, then the superkingdoms), and
# falling back to the COG functional category when no description is given.

use strict;
use warnings;

my $usage = "usage: $0 e5.og_annotations.tsv[.gz] > eggnog5.bulk_load\n";
my $file = $ARGV[0] or die $usage;

my %level_rank = ( 1 => 0,       # root
                   2759 => 1,    # Eukaryota
                   2 => 2,       # Bacteria
                   2157 => 3,    # Archaea
                   10239 => 4,   # Viruses
    );
my $default_rank = 9;

my $fh;
if ($file =~ /\.gz$/) {
    open($fh, "gunzip -c $file |") or die "Error, cannot gunzip $file";
}
else {
    open($fh, $file) or die "Error, cannot open $file";
}

my %best; # og_id -> [rank, description]

while (my $line = <$fh>) {
    chomp $line;
    next unless $line =~ /\S/;
    my ($tax_level, $og_id, $cog_cat, $descr) = split(/\t/, $line, 4);
    next unless defined $og_id && $og_id =~ /\S/;

    my $uniprot_style_id = ($og_id =~ /^(COG|KOG|arCOG)/) ? $og_id : "ENOG50$og_id";

    $descr = "" unless defined $descr;
    $descr =~ s/\s+/ /g;
    $descr =~ s/^ | $//g;
    if ($descr eq "") {
        $descr = (defined $cog_cat && $cog_cat =~ /\S/) ? "COG_category:$cog_cat" : "NA";
    }

    my $rank = exists $level_rank{$tax_level} ? $level_rank{$tax_level} : $default_rank;
    # a real description beats a category-only placeholder at any rank
    my $is_placeholder = ($descr =~ /^(COG_category:|NA$)/) ? 1 : 0;
    my $score = $is_placeholder * 100 + $rank;

    if (! exists $best{$uniprot_style_id} || $score < $best{$uniprot_style_id}->[0]) {
        $best{$uniprot_style_id} = [$score, $descr];
    }
}
close $fh;

foreach my $id (sort keys %best) {
    print join("\t", $id, $best{$id}->[1]) . "\n";
}

exit(0);
