#!/usr/bin/env perl

use strict;
use warnings;

use CGI;

my $cgi = new CGI();
print $cgi->header();

print $cgi->start_html();
print "Running...\n";
print $cgi->end_html();

exit(0);


