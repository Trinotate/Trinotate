#!/usr/bin/env perl

use strict;
use warnings;
use CGI;

use FindBin;
use lib ("$FindBin::RealBin/../../");
use CanvasXpress::Piechart;
use CanvasXpress::PlotOnLoader;

my $cgi = new CGI();

print $cgi->start_html(-title => "Testing Piechart",
                       -onLoad => "load_plots();");


my $piechart_tester = new CanvasXpress::Piechart("test_canvas");
my $plot_loader = new CanvasXpress::PlotOnLoader("load_plots");
$plot_loader->add_plot($piechart_tester);


# structure of input hash:
#
#   %inputs = (
#                pie_name => "name for the pie chart",
#
#                pie_slices = [ ["slice_name_A", 13], ["slice_name_B", 27], ... ],
#
#
#   )


my %inputs = (  pie_name => "my piechart",

                pie_slices => [ ["sliceA", 13],
                                ["sliceB", 100],
                                ["sliceC", 85] ]
    );



print $piechart_tester->draw(%inputs);

print $plot_loader->write_plot_loader();


print $cgi->end_html();

exit(0);

