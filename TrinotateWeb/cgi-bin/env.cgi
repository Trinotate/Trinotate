#!/usr/bin/env perl

use strict;
use warnings;
use CGI;
use Data::Dumper;

my $cgi = new CGI();

$|++;

print $cgi->header();


print "<pre>" . Dumper(\%ENV);


exit(0);
