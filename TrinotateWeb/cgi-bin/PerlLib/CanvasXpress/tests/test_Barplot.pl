#!/usr/bin/env perl

use strict;
use warnings;
use CGI;

use FindBin;
use lib ("$FindBin::RealBin/../../");
use CanvasXpress::Barplot;
use CanvasXpress::PlotOnLoader;

my $cgi = new CGI();

print $cgi->start_html(-title => "Testing Barplot",
                       -onLoad => "load_plots();");


my $barplot_tester = new CanvasXpress::Barplot("test_canvas");
my $plot_loader = new CanvasXpress::PlotOnLoader("load_plots");
$plot_loader->add_plot($barplot_tester);


# structure of input hash:
#
#   %inputs = (
#                title => "title for chart",
#
#                var_name => "variable name",
#
#                data = [ ["barA", 13], ["barB", 27], ... ],
#
#
#   )
    


my %inputs = (  title => "my barplot",
                var_name => "myData",
                data => [ ["barA", 13],
                                ["barB", 100],
                                ["barC", 85] ]
    );



print $barplot_tester->draw(%inputs);

print $plot_loader->write_plot_loader();


print $cgi->end_html();

exit(0);

