#!/usr/bin/env perl

package main;
our ($SEE, $DEBUG);

#our $SEE = 1;

package Sqlite_connect;

require 5.6.0;
require Exporter;
use Carp;
use strict;
use Data::Dumper;
use DBI;

our @ISA = qw(Exporter);

## export the following for general use
our @EXPORT = qw ($QUERYFAIL do_sql do_sql_first_row do_sql_2D connect_to_db RunMod first_result_sql very_first_result_sql AutoCommit bulk_load_sqlite);

our $QUERYFAIL = 0; #intialize.  Status flag, indicating the success of a query.

############### DATABASE CONNECTIVITY ################################
####
sub connect_to_db {
    my ($db_name) = @_;
    
    my $dbproc = DBI->connect("DBI:SQLite:$db_name");
    unless (ref $dbproc) {
        croak "Cannot connect to $db_name: $DBI::errstr";
    }
    $dbproc->{RaiseError} = 1; #turn on raise error.  Must use exception handling now.
    return($dbproc);
}


sub do_sql {
    my ($dbproc, $query, @values) = @_;

    my @results_2D = &do_sql_2D($dbproc, $query, @values);
   

    my @results;
    foreach my $result (@results_2D) {

        my $line = join("\t", @$result);
        push (@results, $line);
    }


    return(@results);
}

sub do_sql_first_row {
    my ($dbproc, $query, @values) = @_;

    my @results = &do_sql($dbproc, $query, @values);
    my $result = shift @results;

    return($result);
}



## return results in 2-Dimensional array.
sub do_sql_2D {
    my ($dbproc,$query, @values) = @_;
    my ($statementHandle,@x,@results);
    my ($i,$result,@row);
    
    eval {

        ## Use $QUERYFAIL Global variable to detect query failures.
        $QUERYFAIL = 0; #initialize
        print STDERR "QUERY: $query\tVALUES: @values\n" if($::DEBUG||$::SEE);
        $statementHandle = $dbproc->prepare($query);
        if ( !defined $statementHandle) {
            print STDERR "Cannot prepare statement: $DBI::errstr\n";
            $QUERYFAIL = 1;
        } else {
            
            # Keep trying to query thru deadlocks:
            do {
                $QUERYFAIL = 0; #initialize
                eval {
                    $statementHandle->execute(@values) or die $!;
                    while ( @row = $statementHandle->fetchrow_array() ) {
                        push(@results,[@row]);
                    }
                };
                ## exception handling code:
                if ($@) {
                    print STDERR "failed query: <$query>\tvalues: @values\nErrors: $DBI::errstr\n";
                    $QUERYFAIL = 1;
                }
                
            } while ($statementHandle->errstr() =~ /deadlock/);
            #release the statement handle resources
            $statementHandle->finish;
        }
        if ($QUERYFAIL) {
            confess "Failed query: <$query>\tvalues: @values\nErrors: $DBI::errstr\n";
        }
    };
    
    if ($@) {
        confess $@;
    }
    
    return(@results);
}

sub RunMod {
    my ($dbproc,$query, @values) = @_;
    my ($result);
    if($::DEBUG||$::SEE) {print STDERR "QUERY: $query\tVALUES: @values\n";}
    if($::DEBUG) {
        $result = "NOT READY";
    } else {
        eval {
            $dbproc->do($query, undef, @values);
        };
        if ($@) { #error occurred
            confess "failed query: <$query>\tvalues: @values\nErrors: $DBI::errstr\n";
            
        }
    }
}


sub first_result_sql {
    my ($dbproc, $query, @values) = @_;
    my @results = &do_sql_2D ($dbproc, $query, @values);
    return ($results[0]);
}

sub very_first_result_sql {
    my ($dbproc, $query, @values) = @_;
    my @results = &do_sql_2D ($dbproc, $query, @values);
    if ($results[0]) {
        return ($results[0]->[0]);
    } else {
        return (undef());
    }
}

sub get_last_insert_rowid {
    my ($dbproc) = @_;

    my $query = "select LAST_INSERT_ROWID()";
    my $row_id = &very_first_result_sql($dbproc, $query);

    return($row_id);
}


####
sub AutoCommit {
    my ($dbproc, $auto_commit_setting) = @_;
    
    unless ($auto_commit_setting == 0 || $auto_commit_setting == 1) {
        confess "Error, auto_commit_setting must be 0 or 1";
    }

    if ($auto_commit_setting == 0) {
        &RunMod($dbproc, "PRAGMA synchronous=OFF");
    }
    
    $dbproc->{AutoCommit} = $auto_commit_setting;
    
    return;
}


####
sub bulk_load_sqlite {
    my ($sqlite_db, $table, $bulk_load_file) = @_;

    my $cmd = "echo \""
        . "pragma journal_mode=memory;\n"
        . "pragma synchronous=0;\n"
        . "pragma cache_size=4000000;\n"
        . ".mode tabs\n"
        . ".import $bulk_load_file $table\""
        . " | sqlite3 $sqlite_db";

    print STDERR "CMD: $cmd\n";
    my $ret = system($cmd);
    if ($ret) {
        confess "Error, cmd: $cmd died with ret $ret";
    }
    return;
}


1; #EOM
