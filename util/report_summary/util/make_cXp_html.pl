#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::Bin/../../../TrinotateWeb/cgi-bin/PerlLib/");
use CanvasXpress::Sunburst;
use CanvasXpress::Piechart;
use CanvasXpress::Barplot;

use CanvasXpress::PlotOnLoader;

use CGI;

my $usage = "usage: $0 report_prefix\n\n";

my $report_prefix = $ARGV[0] or die $usage;


my $plot_loader = new CanvasXpress::PlotOnLoader("load_plots");

main: {

    my $cgi = new CGI();
        
    print $cgi->start_html(-title => "Trinotate Report: $report_prefix",
                           -onLoad => "load_plots();");

    print " <link rel=\"stylesheet\" href=\"http://canvasxpress.org/css/canvasXpress.css\" type=\"text/css\"/>\n";
    
    ## taxonomy report
    &generate_taxonomy_report_html("$report_prefix.taxonomy_counts");

    ## top species report
    &generate_top_species_report_html("$report_prefix.species_counts");


    ## Gene Ontology view
    &generate_gene_ontology_view("$report_prefix.GO.slim");

    ## Pfam domains:
    &generate_pfam_domain_barplot("$report_prefix.pfam.counts");

    ## Eggnog funccats:
    &generate_eggnog_funccat_barplot("$report_prefix.eggnog_counts.funcats");
    
        
    print $plot_loader->write_plot_loader();

    print $cgi->end_html();

    exit(0);
}


####
sub generate_taxonomy_report_html {
    my ($data_file) = @_;
    
    my $NUM_TOP_CATS = 50;
    
    open(my $fh, $data_file) or die "Error, cannot open file: $data_file";
    my $header = <$fh>;
    chomp $header;
    my @levels = split(/\t/, $header);
    pop @levels; # count value

    my @row_values;
    my @column_data;
    my $other_counts = 0;
    my $counter = 0;
    while (<$fh>) {
        $counter++;
        chomp;
        my @x = split(/\t/);
        my $count = pop @x;

        if ($counter < $NUM_TOP_CATS) {
            for(my $i = 0; $i <= $#x; $i++) {
                push (@{$column_data[$i]}, $x[$i]);
            }
            push (@row_values, $count);
        }
        else {
            $other_counts += $count;
        }
    }
    close $fh;

    if ($other_counts) {
        # build other counts entry:
        my @columns = @column_data;
        my $first_col = shift @columns;
        push (@$first_col, "Other");
        foreach my $other_col (@columns) {
            push (@$other_col, "NA");
        }
        push (@row_values, $other_counts);
    }


    # convert column data to hash:
    my %column_data_hash;
    for (my $i = 0; $i <= $#levels; $i++) {

        my $level = $levels[$i];
        my $col_data_aref = $column_data[$i];
        $column_data_hash{$level} = $col_data_aref;
    }
    
    my $taxonomy_sunburst = new CanvasXpress::Sunburst("taxonomy_sunburst");
    $plot_loader->add_plot($taxonomy_sunburst);

    my %inputs = (title =>  "Taxonomic representation of gene-level top blastx matches",
                  
                  column_names => [@levels],

                  column_contents => \%column_data_hash,

                  row_values => [@row_values]);

    print $taxonomy_sunburst->draw(%inputs);
    
    
}



####
sub generate_top_species_report_html{
    my ($data_file) = @_;

    my $MIN_PCT = 2;

    my @vals;
    open(my $fh, $data_file) or die "Error, cannot open file: $data_file";
    my $header = <$fh>;
    my $total_count = 0;
    while (<$fh>) {
        chomp;
        my ($species, $count) = split(/\t/);
        push (@vals, [$species, $count]);
        $total_count += $count;
    }
    close $fh;

    my @pie_slices;
    my $other_counts = 0;
    foreach my $val_pair (@vals) {
        my ($species, $count) = @$val_pair;
        my $pct = $count / $total_count * 100;
        if ($pct >= $MIN_PCT) {
            push (@pie_slices, $val_pair);
        }
        else {
            $other_counts += $count;
        }
    }
    
    if ($other_counts) {
        push (@pie_slices, ["other", $other_counts]);
    }
    
    my $piechart = new CanvasXpress::Piechart("top_species_piechart");
    
    $plot_loader->add_plot($piechart);
    
    my %inputs = (pie_name => "Top species represented",
                  pie_slices => [@pie_slices]);
    
    print $piechart->draw(%inputs);
        
}


####
sub generate_gene_ontology_view {
    my ($data_file) = @_;


    my @column_names = ("go_class", "go_term");
    my %column_data;
    my @row_values;
    
    open(my $fh, $data_file) or die "Error, cannot open file $data_file";
    while (<$fh>) {
        chomp;
        unless (/\w/) { next; }
        my @x = split(/\t/);
        my ($go_class, $go_id, $go_term, $count, $go_descr) = @x;


        if ($go_term =~ /^(biological_process|cellular_component|molecular_function)$/) { next; } # skip highest-level 
        
        
        $go_id =~ s/:/_/g;
        
        $go_term = "$go_id $go_term";

        push (@{$column_data{'go_class'}}, $go_class);
        push (@{$column_data{'go_term'}}, $go_term);
        push (@row_values, $count);
    }
    close $fh;
    
    my $GO_sunburst = new CanvasXpress::Sunburst("GO_sunburst");
    $plot_loader->add_plot($GO_sunburst);

    my %inputs = (title => "Gene Ontology Categories",

                  column_names => [@column_names],

                  column_contents => \%column_data,

                  row_values => [@row_values] );

    print $GO_sunburst->draw(%inputs);
 

    return;
}
    
####
sub generate_pfam_domain_barplot {
    my ($data_file) = @_;

    my $NUM_TOP_DOMAINS = 50;

    open(my $fh, $data_file) or die "Error, cannot open file: $data_file";
    my $header = <$fh>;

    my @vals;
    my $counter = 0;
    while (<$fh>) {
        chomp;
        $counter++;
        
        my ($pfam, $count) = split(/\t/);

        push (@vals, [$pfam, $count]);
        
        if ($counter >= $NUM_TOP_DOMAINS) { last; }
        
    }
    close $fh;

    
    my %inputs = ( orientation => 'horizontal',
                   
                   title => 'Top Pfam domains',
                   
                   var_name => 'Pfam',

                   data => [@vals],
        );
    
    my $barplot = new CanvasXpress::Barplot("Pfam_barplot");
    $plot_loader->add_plot($barplot);

    print $barplot->draw(%inputs);
    
    return;
}


####
sub generate_eggnog_funccat_barplot {
    my ($data_file) = @_;

    my @vals;
    open(my $fh, $data_file) or die "Error, cannot open file: $data_file";
    my $header = <$fh>;
    while (<$fh>) {
        chomp;
        my ($code, $funccat, $count) = split("\t");
        
        if ($code eq "S" || $code eq "R") { next; } # nonspecific categories
        
        push (@vals, [$funccat, $count]);
    }
    close $fh;

    
    my %inputs = ( orientation => 'horizontal',
                   
                   title => 'Functional Categories via Eggnog/COG Mappings',
                   
                   var_name => 'funccats',

                   data => [@vals],
        );
    
    my $barplot = new CanvasXpress::Barplot("funccat_barplot");
    $plot_loader->add_plot($barplot);

    print $barplot->draw(%inputs);
    
    return;

}


