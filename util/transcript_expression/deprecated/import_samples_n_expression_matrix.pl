#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use Getopt::Long qw(:config no_ignore_case bundling);
use FindBin;
use lib ("$FindBin::RealBin/../../PerlLib");
use DBI;
use Sqlite_connect;
use Data::Dumper;

my $usage = <<__EOUSAGE__;

#################################################################################################
#
# Required:
#
#  --sqlite <string>         path to the Trinotate sqlite database
#
#  --samples_file <string>        file describing samples and replicates
#
#  --count_matrix <string>        raw fragment counts matrix
#  --fpkm_matrix <string>         fpkm normalized expression value matrix
#
#  AND
#
#  --transcript_mode              analysis is performed based on Trinity transcripts (isoforms)
#  OR
#  --component_mode               analysis is performed based on Trinity components (genes)
#
# Optional:
#  
#  --restrict <string>            features to restrict loading to (first column should be the feature ID)
#
#  --bulk_load                    use sqlite bulk loading feature   ** highly recommended for large matrices **
#
##################################################################################################


__EOUSAGE__

    ;


my $sqlite;
my $count_matrix_file;
my $fpkm_matrix_file;
my $transcript_mode = 0;
my $component_mode = 0;
my $help_flag;
my $samples_file;
my $restrict;
my $bulk_load_flag = 0;

&GetOptions (  'h' => \$help_flag,
               
               'sqlite=s' => \$sqlite,

               'samples_file=s' => \$samples_file,

               'count_matrix=s' => \$count_matrix_file,
               'fpkm_matrix=s' => \$fpkm_matrix_file,
                
               'transcript_mode' => \$transcript_mode,
               'component_mode' => \$component_mode,
               
               'restrict=s' => \$restrict,
               
               'bulk_load' => \$bulk_load_flag,
               
               );


if ($help_flag) {
    die $usage;
}

unless ($sqlite
        &&
        $samples_file
        &&
        $count_matrix_file && $fpkm_matrix_file
        && ($transcript_mode || $component_mode) ) {
    die $usage;
}


unless (-s $sqlite) {
    die "Error, cannot find db: $sqlite ";
}

our $SEE = 0;


main: {

    my $dbproc = DBI->connect( "dbi:SQLite:$sqlite" ) || die "Cannot connect: $DBI::errstr";


    $dbproc->do("PRAGMA synchronous=OFF");
    $dbproc->{AutoCommit} = 0;
    

    my $feature_type = ($transcript_mode) ? 'T' : 'G';
    
    my %samples = &parse_samples_file($samples_file);
    
    my %samples_n_reps_to_ID = &get_sample_ids($dbproc, \%samples);

    print STDERR "Samples and replicates: " . Dumper(\%samples_n_reps_to_ID);
    
    my %restricted_ids;
    if ($restrict) {
        %restricted_ids = &get_restricted_ids($restrict);
    }
    
    print STDERR "-parsing counts matrix: $count_matrix_file\n";
    my %counts_matrix = &parse_matrix($count_matrix_file, \%samples_n_reps_to_ID, \%restricted_ids);

    print STDERR "-parsing fpkm matrix: $fpkm_matrix_file\n";
    my %fpkm_matrix = &parse_matrix($fpkm_matrix_file, \%samples_n_reps_to_ID, \%restricted_ids);
    
    print STDERR "-populating Expression table\n";
    &populate_expression_table($dbproc, \%samples_n_reps_to_ID, \%counts_matrix, \%fpkm_matrix, $feature_type);
    
    exit(0);
                        
}


####
sub parse_column_headers {
    my ($DE_result_file) = @_;

    open (my $fh, $DE_result_file) or die "Error, cannot open file $DE_result_file";
    my $top_line = <$fh>;
    my $second_line = <$fh>;
    close $fh;

    chomp $top_line;
    #$top_line =~ s/\.(genes|isoforms)\.results//g;
    my @columns = split(/\t/, $top_line);
    
    chomp $second_line;
    my @second_line_columns = split(/\t/, $second_line);
    if (scalar(@columns) == scalar(@second_line_columns) -1) {
        # weird R thing where the header can be off by one due to row.names
        unshift (@columns, "id");
    }
    
    my %indices;
    for (my $i = 0; $i <= $#columns; $i++) {
        $indices{$columns[$i]} = $i;
    }

    return(%indices);
}
    
####
sub parse_samples_file {
    my ($samples_file) = @_;

    my %sample_to_reps;

    open (my $fh, $samples_file) or die "Error, cannot open file: $samples_file";
    while (<$fh>) {
        chomp;
        unless (/\w/) { next; }
        if (/^\#/) { next; }
        
        my ($sample, $rep_name, @rest) = split(/\t/);
        
        if (defined ($sample) && defined ($rep_name) ) {
            $sample_to_reps{$sample}->{$rep_name} = 1;
        }
    }
    close $fh;
    
    return(%sample_to_reps);
}

####
sub get_sample_ids {
    my ($dbproc, $samples_href) = @_;

    my %sample_and_rep_ids;
    
    my $max_sample_no = 0;
    my $max_rep_no = 0;

    ## get existing assignments
    {
        my $query = "select sample_id, sample_name from Samples";
        my @results = &do_sql_2D($dbproc, $query);
        foreach my $result (@results) {
            my ($sample_id, $sample_name) = @$result;
            $sample_and_rep_ids{sample}->{$sample_name} = $sample_id;
            $sample_id =~ s/\D//g;
            if ($sample_id > $max_sample_no) {
                $max_sample_no = $sample_id;
            }
        }
    }
    
    {
        my $query = "select replicate_id, replicate_name from Replicates";
        my @results = &do_sql_2D($dbproc, $query);
        foreach my $result (@results) {
            my ($replicate_id, $replicate_name) = @$result;
            $sample_and_rep_ids{replicate}->{$replicate_name} = $replicate_id;
            $replicate_id =~ s/\D//g;
            if ($replicate_id > $max_rep_no) {
                $max_rep_no = $replicate_id;
            }
        }
    }

    ## insert those that don't already exist.
    foreach my $sample (keys %$samples_href) {
        
        my $sample_id = $sample_and_rep_ids{sample}->{$sample};
        unless ($sample_id) {
            ## insert it
            $sample_id = "S" . ++$max_sample_no;
            &do_sql($dbproc, "insert into Samples (sample_id, sample_name) values (?,?)", $sample_id, $sample);
            $sample_and_rep_ids{sample}->{$sample} = $sample_id;;
        }
        
        foreach my $replicate (keys %{$samples_href->{$sample}}) {

            unless ($sample_and_rep_ids{replicate}->{$replicate}) {
                ## insert it
                my $rep_id = "R" . ++$max_rep_no;
                &do_sql($dbproc, "insert into Replicates (replicate_id, replicate_name, sample_id) values (?,?,?)",
                        $rep_id, $replicate, $sample_id);
                $sample_and_rep_ids{replicate}->{$replicate} = $rep_id;
            }
        }
    }


    $dbproc->commit;
    
    return(%sample_and_rep_ids);
}


####
sub parse_matrix {
    my ($matrix_file, $samples_n_reps_href, $restricted_ids_href) = @_;

    my %matrix;
    
    open (my $fh, $matrix_file) or die "Error, cannot open file $matrix_file";
    my $header = <$fh>;
    chomp $header;
    $header =~ s/^\s+//;
    #$header =~ s/\.(genes|isoforms)\.results//g;
    my @fields = split(/\t/, $header);

    ## Ensure that each column value is a recognizable replicate name
    my %replicates = %{$samples_n_reps_href->{replicate}};
    my $rep_name_ok = 1;
    for my $i (1..$#fields) {
        my $replicate_name = $fields[$i];
        unless (exists $replicates{$replicate_name}) {
            print STDERR "ERROR: Do not recognize column name \"$replicate_name\" as a replicate name as specified in the sampels description file.\n";
            $rep_name_ok = 0;
        }
    }
    if (! $rep_name_ok) {
        die "Error, at least one column name in file $matrix_file could not be recognized as a replicate name.  Please check for consistency between your samples description file and your matrix column headers.\n";
    }
    
    while (<$fh>) {
        chomp;
        my @x = split(/\t/);
        my $trans_id = shift @x;
        
        if (%$restricted_ids_href  && ! $restricted_ids_href->{$trans_id}) { next; }
        
        unless (scalar(@x) == scalar(@fields) ) {
            die "Error, number of fields in row is different from number of replicates";
        }
        
        for (my $i = 0; $i <= $#fields; $i++) {
            my $rep_name = $fields[$i];
            my $expr = $x[$i];
            
            $matrix{$trans_id}->{$rep_name} = $expr;
        }
    }
    close $fh;

    return(%matrix);
}

####
sub populate_expression_table {
    my ($dbproc, $samples_n_reps_to_ID_href, $counts_matrix_href, $fpkm_matrix_href, $feature_type) = @_;


    my %already_loaded;
    {
        my $query = "select feature_name from Expression where feature_type = ?";
        my @results = &do_sql($dbproc, $query, $feature_type);
        %already_loaded = map { + $_ => 1 } @results;
    }
    

    my $counter = 0;

    my @feature_ids = keys %$counts_matrix_href;


    my $ofh;
    my $bulk_load_file = "tmp.expression_matrix_load.dat";
    if ($bulk_load_flag) {
        $dbproc->disconnect;
        
        open ($ofh, ">$bulk_load_file") or die "Error, cannot write to $bulk_load_file";
    }
    
    my $num_features = scalar(@feature_ids);

    foreach my $feature (@feature_ids) {
        
        $counter++;
        
        if ($already_loaded{$feature}) { next; }
        
        my @replicates = keys %{$counts_matrix_href->{$feature}};
        foreach my $replicate (@replicates) {
            my $rep_id = $samples_n_reps_to_ID_href->{replicate}->{$replicate} or die "Error, no replicate_id for [$replicate]";
            
            my $frag_count = $counts_matrix_href->{$feature}->{$replicate};
            unless (defined $frag_count) {
                die "Error, no frag count for $feature, $replicate";
            }
            
            my $fpkm = $fpkm_matrix_href->{$feature}->{$replicate};
            unless (defined $fpkm) {
                die "Error, no fpkm measurement for $feature, $replicate";
            }
            
            
            if ($bulk_load_flag) {
                #CREATE TABLE Expression (feature_name, feature_type, replicate_id, frag_count REAL, fpkm REAL);
                print $ofh join("\t", $feature, $feature_type, $rep_id, $frag_count, $fpkm) . "\n";
            }
            else {
                my $query = "insert into Expression (feature_name, feature_type, replicate_id, frag_count, fpkm) "
                    . " values (?,?,?,?,?)";
                &do_sql($dbproc, $query, $feature, $feature_type, $rep_id, $frag_count, $fpkm);
                
                if ($counter % 10000 == 0) {
                    $dbproc->commit;
                    
                }
                
            }
            
            if ($counter % 10000) {
                my $pct_done = $counter/$num_features * 100;
                print STDERR "\r[" . sprintf("%.4f", $pct_done)  .  "% done.]      ";
            }
        }
    }
    print STDERR "\n";
    
    if ($bulk_load_flag) {
        close $ofh;
        &bulk_load_sqlite($sqlite, "Expression", $bulk_load_file);
        unlink($bulk_load_file);
    }
    else {
        $dbproc->commit;
    }
    
        
    return;
}

####
sub get_restricted_ids {
    my  ($restrict) = @_;

    my %restricted_ids;

    open (my $fh, $restrict) or die $!;
    while (<$fh>) {
        my @x = split(/\t/);
        my $id = $x[0];
        $restricted_ids{$id} = 1;
    }
    close $fh;

    return(%restricted_ids);
}


####
sub process_cmd {
    my ($cmd) = @_;

    print STDERR "CMD: $cmd\n";
    my $ret = system($cmd);

    if ($ret) {
        die "Error, cmd: $cmd died with ret $ret";
    }

    return;
}

