#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::RealBin/../../../PerlLib");
use EMBL_parser;
use Data::Dumper;

my $usage = "usage: $0 swissprot.dat out.prefix\n\n";

my $swiss_dat_file = $ARGV[0] or die $usage;
my $out_prefix = $ARGV[1] or die $usage;


main: {

    my $tmp_UniprotIndex_bulk_load_file = "$out_prefix.UniprotIndex";
    
    open (my $ofh, ">$tmp_UniprotIndex_bulk_load_file") or die "Error, cannot write to $tmp_UniprotIndex_bulk_load_file";
    
    my %taxon_ids;
    open (my $taxons_ofh, ">$out_prefix.TaxonomyIndex") or die $!;
        
    my $embl_parser = new EMBL_parser($swiss_dat_file);
    
    my $pep_file = "$swiss_dat_file.pep\n";
    open (my $ofh_pep, ">$pep_file") or die $!;
    
    ## types currently supporting: DEGKT
    
    my $record_counter = 0;
    
    while (my $record = $embl_parser->next()) {
        
        $record_counter++;
        print STDERR "\r[$record_counter]    " if $record_counter % 1000 == 0;
        
        my $ID = &get_ID($record);
        
        my @accessions = &get_accessions($record);
        
        my $descr = &get_description($record);
        
        my $taxon_id = &get_taxon_id($record, \%taxon_ids, $taxons_ofh);
        
        # gene ontology
        my @GO = &get_GO($record);
        
        ##   (type E for eggnog)
        my @eggnog = &get_eggNOG($record);
        
        ## kegg
        my @kegg = &get_KEGG($record);
        
        
        print $ofh join("\t", $ID, $descr, 'D') . "\n";
        
        print $ofh join("\t", $ID, $taxon_id, 'T') . "\n";
        
        foreach  my $go (@GO) {
            print $ofh join("\t", $ID, $go, 'G') . "\n";
        }
        
        
        foreach my $egg (@eggnog) {
            print $ofh join("\t", $ID, $egg, 'E') . "\n";
        }
        
        
        ## KEGG (type K)
        foreach my $k (@kegg) {
            print $ofh join("\t", $ID, $k, 'K') . "\n";
        }
        
        
        my $protein = &get_protein_seq($record);
        
        $descr =~ s/RecName: Full=//;
        $descr =~ s/;\s*$//;
        print $ofh_pep ">$ID $descr\n"
            . "$protein\n";
        
    }
    
    close $ofh_pep;
    
    
    close $ofh;
    close $taxons_ofh;
    
    exit(0);
    
    
}


####
sub get_ID {
    my ($record) = @_;

    my $ID_info = $record->{sections}->{ID};
    my @pts = split(/\s+/, $ID_info);

    my $ID = shift @pts;

    return($ID);
}

####
sub get_protein_seq {
    my ($record) = @_;
    
    my $seq = $record->{sections}->{SQ};
    my @lines = split(/\n/, $seq);
    shift @lines; # header

    my $protein = join("", @lines);
    $protein =~ s/\s//g;
    
    return($protein);
    
}



####
sub get_accessions {
    my ($record) = @_;

    my $acc_text = $record->{sections}->{AC};
    chomp $acc_text;

    my @pts = split(/\s+/, $acc_text);
    
    my @accs;
    foreach my $pt (@pts) {
        $pt =~ s/\;//;
        push (@accs, $pt);
    }
    
    return(@accs);
}
 

####
sub get_description {
    my ($record) = @_;

    my $descr_text = $record->{sections}->{DE} or die "Error, no description line for $record";
    
    # just get the first line.
    my @pts = split(/\n/, $descr_text);
    return($pts[0]);
}

####
sub get_taxon_id {
    my ($record, $taxon_ids_href, $taxons_ofh) = @_;
    
    my $ncbi_taxon_id = $record->{sections}->{OX} or die "Error, no OX record for $record";
    $ncbi_taxon_id =~ /NCBI_TaxID=(\d+)[; ]/ or die "Error, cannot parse $ncbi_taxon_id for taxon id";
    $ncbi_taxon_id = $1;

    if ($taxon_ids_href->{$ncbi_taxon_id}) {
        # already seen it
        return($ncbi_taxon_id);
    }

    my $taxon_string = $record->{sections}->{OC};
    $taxon_string =~ s/^\s|\s+$//g; # trim lead/trailing ws
    $taxon_string =~ s/\s+/ /g;
    $taxon_string =~ s/\.$//; # rid final dot char
    
    print $taxons_ofh join("\t", $ncbi_taxon_id, $taxon_string) . "\n";
    
    $taxon_ids_href->{$ncbi_taxon_id} = 1; # track seen ones.

    return($ncbi_taxon_id);

}

####
sub get_GO {
    my $self = shift;
    
    my $section_text = $self->{sections}->{DR};
    
    if (! $section_text) {
        return;
    }
    
    my @lines = split(/\n/, $section_text);
    
    my @GO_ids;
    foreach my $line (@lines) {
        if ($line =~ /^GO; (GO:\d+);/) {
            push (@GO_ids, $1);
        }
    }

    return(@GO_ids);
}

####
sub get_eggNOG {
    my $self = shift;
    
    my $section_text = $self->{sections}->{DR};
    
    if (! $section_text) {
        return;
    }
    
    my @lines = split(/\n/, $section_text);
    
    my @eggnogs;
    foreach my $line (@lines) {
        if ($line =~ /^eggNOG; (\S+);/) {
            push (@eggnogs, $1);
        }
    }

    return(@eggnogs);
}   


####
sub get_KEGG {
    my $self = shift;
    
    my $section_text = $self->{sections}->{DR};
    
    if (! $section_text) {
        return;
    }
    
    my @lines = split(/\n/, $section_text);
    
    my @kegg;
    foreach my $line (@lines) {
        if ($line =~ /^KEGG; (\S+);/) {
            push (@kegg, "KEGG:$1");
        }
        elsif ($line =~ /^KO; (\S+);/) {
            push (@kegg, "KO:$1");
        }
    }
    
    return(@kegg);
}   

