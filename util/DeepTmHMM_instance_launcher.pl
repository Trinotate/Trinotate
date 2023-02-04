#!/usr/bin/env perl

use strict;
use warnings;
use File::Basename;
use Carp;

my $usage = "usage: $0 /path/to/target.pep\n\n";

my $target_pep = $ARGV[0] or die $usage;



my $workdir = dirname($target_pep);
chdir $workdir or die "Error, cannot cd to $workdir";

if (-e "biolib.ok") {
    print STDERR "-skipping $target_pep, already completed.\n";
    exit(0);
}


my $biolib = `which biolib`;
chomp $biolib;

unless ($biolib =~ /\w/) {
    confess "Error, cannot locate biolib";
}



my $cmd = "python3 $biolib run DTU/DeepTMHMM --fasta $target_pep";

my $ret = system($cmd);

if ($ret) {
    confess "Error, cmd: $cmd died with ret $ret";
}

system("touch biolib.ok");

exit(0);

