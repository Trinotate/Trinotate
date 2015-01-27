#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use DBI;

my $usage = "usage: $0 sqlite.db\n\n";

my $sqlite_db = $ARGV[0] or die $usage;

$|++;

main: {
    
    my $dbproc = DBI->connect("DBI:SQLite:$sqlite_db");
    unless (ref $dbproc) {
        croak "Cannot connect to $sqlite_db: $DBI::errstr";
    }
    $dbproc->{RaiseError} = 1; #turn on raise error.  Must
    

    while (1) {
        
        print "sqlite.pl> ";
        my $query = <STDIN>;
        
        unless ($query) {
            last;
        }
        
        my $QUERYFAIL;
        
        chomp $query;
        
        my $statementHandle = $dbproc->prepare($query);
        if ( !defined $statementHandle) {
            print "Cannot prepare statement: $DBI::errstr\n";
            $QUERYFAIL = 1;
        } else {
            
            # Keep trying to query thru deadlocks:
            my $start_time = time();
            my $num_results = 0;
            do {
                $QUERYFAIL = 0; #initialize
                eval {
                    $statementHandle->execute() or die $!;
                    while (my @row = $statementHandle->fetchrow_array() ) {
                        $num_results++;
                        
                        my $counter = 0;
                        foreach my $ele (@row) {
                            $counter++;
                            if (! defined $ele) {
                                $ele = "";
                            }
                            print "$counter\t$ele\n";
                        }
                        print "\n";
                    }
                    
                };
                ## exception handling code:
                if ($@) {
                    print STDERR "failed query: <$query>\nErrors: $DBI::errstr\n";
                    $QUERYFAIL = 1;
                }
                
            } while (defined($statementHandle->errstr()) && $statementHandle->errstr() =~ /deadlock/);
            #release the statement handle resources
            print "Done.\n";
            
            $statementHandle->finish;
            print "statmenthandle finished.\n";
            

            my $end_time = time();

            my $num_seconds = $end_time - $start_time;
            print "\n\t(NUM_RESULTS=$num_results\tTime: $num_seconds seconds)\n\n";
        }
        

    }

    print "\n\nGoodbye! :)\n\n";
    

    exit(0);
}

