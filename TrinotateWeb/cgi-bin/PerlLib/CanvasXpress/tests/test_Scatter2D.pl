#!/usr/bin/env perl

use strict;
use warnings;
use CGI;

use FindBin;
use lib ("$FindBin::RealBin/../../");
use CanvasXpress::Scatter2D;
use CanvasXpress::PlotOnLoader;

my $cgi = new CGI();

print $cgi->start_html(-title => "Testing Scatter2D",
                       -onLoad => "load_plots();");


my $scatter_2D_tester = new CanvasXpress::Scatter2D("test_canvas");
my $plot_loader = new CanvasXpress::PlotOnLoader("load_plots");
$plot_loader->add_plot($scatter_2D_tester);

my %inputs = ( replicate_names => ['sampleA', 'sampleB', 'sampleC', 'sampleD'],
               value_matrix => [ 
                   ['gene1', 1, 2, 10, 11],
                   ['gene2', 2, 3, 11, 12],
                   ['gene3', 3, 4, 12, 13],
                   ['gene4', 4, 5, 13, 14],
                   ['gene5', 5, 6, 14, 15],
               ],
               
               
               sample_annotations => { 
                   'sample_type' => ['liver', 'liver', 'kidney', 'kidney'],
               },
               
               feature_annotations => {
                   annots => ['gene1:name', 'gene2:name', 'gene3:name', 'gene4:name', 'gene5:name'],
               },
               
               events =>  { 'click' => "var gene = o['y']['vars'][0];\n"
                                . "document.location.href=\'feature_report.cgi?feature_name=\' + gene;\n",
                                
               },
               

               comparisons => [
                   ['sampleA', 'sampleB'],
                   ['sampleC', 'sampleD'],
               ],
               
               

    );


print $scatter_2D_tester->draw(%inputs);

print $plot_loader->write_plot_loader();


print $cgi->end_html();

exit(0);

