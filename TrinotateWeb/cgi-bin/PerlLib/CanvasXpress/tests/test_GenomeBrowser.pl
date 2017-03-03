#!/usr/bin/env perl

use strict;
use warnings;
use CGI;

use FindBin;
use lib ("$FindBin::RealBin/../../");
use CanvasXpress::GenomeBrowser;
use CanvasXpress::PlotOnLoader;

my $cgi = new CGI();

print $cgi->start_html(-title => "Testing GenomeBrowser",
                       -onLoad => "load_plots();");


my $plot_loader = new CanvasXpress::PlotOnLoader("load_plots");


my $genome_seq = "ATGATTACA" x 30;

my $genome_browser = new CanvasXpress::GenomeBrowser("canvas_gb$$", $genome_seq);
$plot_loader->add_plot($genome_browser);


## create a track, add elements
my $track = new CanvasXpress::GenomeBrowser::Track("track 1", "box");

my $element_A = new CanvasXpress::GenomeBrowser::Element("ele A", [ [2,50], [75,100] ]);
$track->add_element($element_A);

my $element_B = new CanvasXpress::GenomeBrowser::Element("ele B", [ [ 10,20], [60,75] ]);
$track->add_element($element_B);

$genome_browser->add_track($track);


## create another track, add elements
my $track2 = new CanvasXpress::GenomeBrowser::Track("track 2", "box");

my $element_C = new CanvasXpress::GenomeBrowser::Element("ele C", [ [102,150], [175,200] ]);
$track2->add_element($element_C);

my $element_D = new CanvasXpress::GenomeBrowser::Element("ele D", [ [ 110,120], [160,175] ]);
$track2->add_element($element_D);

$genome_browser->add_track($track2);



print $genome_browser->draw();


print $plot_loader->write_plot_loader();


print $cgi->end_html();

exit(0);

