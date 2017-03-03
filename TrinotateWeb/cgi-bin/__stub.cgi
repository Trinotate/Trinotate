#!/usr/bin/env perl

use strict;
use warnings;

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib", "$FindBin::RealBin/PerlLib");
use DBI;
use Sqlite_connect;
use Trinotate;
use CanvasXpress::PlotOnLoader;
use URI::Escape;
use Data::Dumper;


our $SEE = 0;

main: {
    
    my $cgi = new CGI();
    print $cgi->header();
    
    my %params = $cgi->Vars();
    
    my $sqlite_db = $params{sqlite} or die "Error, need sqlite param";

    my $plot_loader_func_name = "load_plots_$$";
    
    print $cgi->start_html(-title => 'put title here',
                           -onLoad => $plot_loader_func_name . "();",
        );

    my $plot_loader = new CanvasXpress::PlotOnLoader($plot_loader_func_name);
    
    my $dbproc = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";

    print $plot_loader->write_plot_loader();
    
    $dbproc->disconnect;
        
    print $cgi->end_html();
    
    exit(0);

}

