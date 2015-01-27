#!/usr/bin/env perl

use strict;
use warnings;

use DBI;

my $usage = "usage: $0 sqlite.db obo.tab\n\n";

my $sqlite_db = $ARGV[0] or die $usage;
my $obo_tab_file = $ARGV[1] or die $usage;

main: {

    
    my $dbh = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
    
    $dbh->do("PRAGMA synchronous=OFF");
    
    $dbh->do("delete from go");
    
    $dbh->{AutoCommit} = 0;
    

    my $insert_entry_dml = qq {
        INSERT INTO go
        VALUES (?,?,?,?)
    };
    
    my $insert_entry_dsh = $dbh->prepare($insert_entry_dml);


    my $counter = 0;
    open (my $fh, $obo_tab_file) or die $!;
    while (<$fh>) {
        chomp;
        my ($id, $name, $namespace, $def) = split(/\t/);
        $insert_entry_dsh->execute($id, $name, $namespace, $def);
        
        $counter++;
        if ($counter % 1000 == 0) {
            print STDERR "\r[$counter]   ";
            $dbh->commit;
        }
    }
    close $fh;

    $dbh->commit;
    
    $insert_entry_dsh->finish();
    
    print STDERR "\n\ndone.\n\n";
    

    $dbh->disconnect();

    exit(0);
}
