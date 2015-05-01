#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use CGI;

my $cgi = new CGI();
print $cgi->header();

print $cgi->start_html();
print "Running...\n";

print "ENV:<pre>" . Dumper(\%ENV) . "</pre>\n";


print $cgi->end_html();



exit(0);


