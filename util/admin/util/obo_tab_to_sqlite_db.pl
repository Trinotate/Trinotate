#!/usr/bin/env perl

use strict;
use warnings;

use DBI;

my $usage = "usage: $0 sqlite.db [go|go_slim] obo.tab\n\n";

my $sqlite_db = $ARGV[0] or die $usage;
my $tablename = $ARGV[1] or die $usage;
my $obo_tab_file = $ARGV[2] or die $usage;

unless ($tablename eq "go" || $tablename eq "go_slim") {
    die "Error, tablename must be 'go' or 'go_slim'";
}

main: {
    
    my $dbh = DBI->connect( "dbi:SQLite:$sqlite_db" ) || die "Cannot connect: $DBI::errstr";
    
    $dbh->do("PRAGMA synchronous=OFF");
    
    $dbh->do("delete from $tablename");
    
    $dbh->{AutoCommit} = 0;
    

    my $insert_entry_dml = qq {
        INSERT INTO $tablename
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
