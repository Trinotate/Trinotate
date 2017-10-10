#!/usr/bin/env perl

use strict;
use warnings;
use CGI;

use FindBin;
use lib ("$FindBin::RealBin/../../");
use CanvasXpress::Sunburst;
use CanvasXpress::PlotOnLoader;

my $cgi = new CGI();

print $cgi->start_html(-title => "Testing Sunburst",
                       -onLoad => "load_plots();");


my $sunburst_tester = new CanvasXpress::Sunburst("test_canvas");
my $plot_loader = new CanvasXpress::PlotOnLoader("load_plots");
$plot_loader->add_plot($sunburst_tester);


#   %inputs = ( column_names => [colA, colB, colC],
#
#               column_contents => { colA => [a1, a2, a3, ...],
#                                    colB => [b1, b2, b3, ...],
#                                    colC => [c1, c2, c3, ...] },
#
#
#               row_values => [ 0.1, 0.2, 3.5, ... ],


my %inputs = ( column_names => [ 'Quarter', 'Month', 'Week' ],

               column_contents => { 
                   'Quarter' => [ 
                       "1st",
                       "1st",
                       "1st",
                       "1st",
                       "1st",
                       "1st",
                       "2nd",
                       "2nd",
                       "2nd",
                       "3rd",
                       "3rd",
                       "3rd",
                       "4th",
                       "4th",
                       "4th"
                       ],
                       
                       "Month" =>  [
                           "Jan",
                           "Feb",
                           "Feb",
                           "Feb",
                           "Feb",
                           "Mar",
                           "Apr",
                           "May",
                           "Jun",
                           "Jul",
                           "Aug",
                           "Sep",
                           "Oct",
                           "Nov",
                           "Dec"
                       ],
                           "Week" =>  [
                               "NA",
                               "Week 1",
                               "Week 2",
                               "Week 3",
                               "Week 4",
                               "NA",
                               "NA",
                               "NA",
                               "NA",
                               "NA",
                               "NA",
                               "NA",
                               "NA",
                               "NA",
                               "NA"
                           ]
               },

               'row_values' => [   3.5,
                                   1.2,
                                   0.8,
                                   0.6,
                                   0.5,
                                   1.7,
                                   1.1,
                                   0.8,
                                   0.3,
                                   0.7,
                                   0.6,
                                   0.1,
                                   0.5,
                                   0.4,
                                   0.3
               ]
    );


print $sunburst_tester->draw(%inputs);

print $plot_loader->write_plot_loader();


print $cgi->end_html();

exit(0);

