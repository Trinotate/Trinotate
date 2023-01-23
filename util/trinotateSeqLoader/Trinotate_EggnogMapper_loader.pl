#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");
use Carp;
use DBI;
use Sqlite_connect;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);


my $usage = <<__EOUSAGE__;

###########################################################################
#
# Required:
#
# --sqlite <string>  Trinotate sqlite database
#
# --emapper <string>  emapper output
#
###########################################################################


__EOUSAGE__


    ;



my $sqlite_db;
my $emapper_output;
my $help_flag;

&GetOptions( 'sqlite=s' => \$sqlite_db,
             'emapper=s' => \$emapper_output,
             
             'help|h' => \$help_flag,
    );

if ($help_flag) {
    die $usage;
}


unless ($sqlite_db && $emapper_output) {
    die $usage;
}


main: {
    
    unless (-s $sqlite_db) {
        die "Error, cannot locate the $sqlite_db database file";
    }
        
    my $dbh = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
    $dbh->do("delete from EggnogMapper") or die $!;
    $dbh->disconnect();

    my $tmp_emapper_bulk_load_file = "tmp.emapper_bulk_load.$$";
    my $cmd = "bash -c \'set -eou pipefail && cat $emapper_output | egrep -v ^\# > $tmp_emapper_bulk_load_file \'";
    my $ret = system($cmd);
    if ($ret) {
        confess "Error, cmd: $cmd died with ret $ret";
    }
    
    &bulk_load_sqlite($sqlite_db, "EggnogMapper", $tmp_emapper_bulk_load_file);

    unlink($tmp_emapper_bulk_load_file);
    
    print STDERR "\n\nLoading complete..\n\n";
        
    exit(0);
    
}
