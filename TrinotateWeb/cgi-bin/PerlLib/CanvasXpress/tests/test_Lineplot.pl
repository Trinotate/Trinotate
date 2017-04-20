#!/usr/bin/env perl

use strict;
use warnings;
use CGI;

use FindBin;
use lib ("$FindBin::RealBin/../../");
use CanvasXpress::Line;
use CanvasXpress::PlotOnLoader;

my $cgi = new CGI();

print $cgi->start_html(-title => "Testing Line plot",
                       -onLoad => "load_plots();");


my $tester = new CanvasXpress::Line("test_canvas");
my $plot_loader = new CanvasXpress::PlotOnLoader("load_plots");
$plot_loader->add_plot($tester);

my %inputs = ( replicate_names => ['sampleA', 'sampleB', 'sampleC', 'sampleD'],
               value_matrix => [ 
                   ['gene4', 4, 5, 13, 14],
#                   ['gene9', 12, 18, 4, 1],
#                   ['gene1', 1, 2, 10, 11],
#                   ['gene7', 11, 12, 3, 1],
#                   ['gene5', 5, 6, 14, 15],
#                   ['gene2', 2, 3, 11, 12],
#                   ['gene6', 12, 13, 1, 2],
#                   ['gene8', 16, 12, 1, 4],




               ],
               
               
               sample_annotations => { 
                   'sample_type' => ['liver', 'liver', 'kidney', 'kidney'],
               },
               
               feature_annotations => {
                   annots => ['gene1:name', 'gene2:name', 'gene3:name', 'gene4:name', 'gene5:name'],
               },
               
               events =>  { 'click' => "var gene = o['y']['vars'][0];\n"
                                . "document.location.href=\'feature_report.cgi?feature_name=\' + gene;\n",
                                
               }
               

    );


print $tester->draw(%inputs);

print $plot_loader->write_plot_loader();


print $cgi->end_html();

exit(0);

