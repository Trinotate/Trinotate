#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use Getopt::Long qw(:config no_ignore_case bundling pass_through);
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
#  --sqlite <string>              path to the Trinotate sqlite database
#
#  --DE_dir <string>              DE analysis directory
#
#  AND
#
#  --transcript_mode              analysis is performed based on Trinity transcripts (isoforms)
#  OR
#  --component_mode               analysis is performed based on Trinity components (genes)
#
#  Misc:
#
#  --bulk_load                    use faster bulk-loading strategy
#
#  --max_load_each <int>          maximimum number of top DE features to load for a given pairwise analysis.
# 
#  --FDR_sig_only <float>         only load those results that are at most the FDR val
#  --PVAL_sig_only <float>        only load those results that are at most the P-value
#
#  --purge_prev_DE_results        removes those DE results for that feature type (transcript or component)
#
##################################################################################################


__EOUSAGE__

    ;


my $trin_sqlite;
my $DE_dir;
my $transcript_mode = 0;
my $component_mode = 0;
my $help_flag;
my $bulk_load_flag = 0;

my $FDR_sig_only;
my $PVAL_sig_only;

my $purge_prev_DE_results_flag;

my $MAX_LOAD_PER_PAIRWISE_ANALYSIS;

&GetOptions (  'h' => \$help_flag,
               
               'sqlite=s' => \$trin_sqlite,

               'DE_dir=s' => \$DE_dir,
               
               'transcript_mode' => \$transcript_mode,
               'component_mode' => \$component_mode,
               
               'FDR_sig_only=f' => \$FDR_sig_only,
               'PVAL_sig_only=f' => \$PVAL_sig_only,
               
               'bulk_load' => \$bulk_load_flag,

               'purge_prev_DE_results' => \$purge_prev_DE_results_flag,
               'max_load_each=i' => \$MAX_LOAD_PER_PAIRWISE_ANALYSIS,
               );


if ($help_flag) {
    die $usage;
}

if (@ARGV) {
    die "Error, don't understand parameters: @ARGV ";
}

unless ($trin_sqlite && $DE_dir
        && ($transcript_mode || $component_mode) ) {
    die $usage;
}

our $SEE = 0;


main: {

    my $dbproc = DBI->connect( "dbi:SQLite:$trin_sqlite" ) || die "Cannot connect: $DBI::errstr";


    $dbproc->do("PRAGMA synchronous=OFF");
    $dbproc->do("pragma journal_mode=memory");
    $dbproc->do("pragma cache_size=4000000");
    $dbproc->{AutoCommit} = 0;
    

    my $feature_type = ($transcript_mode) ? 'T' : 'G';
    

    if ($purge_prev_DE_results_flag) {
        my $query = "delete from Diff_expression where feature_type = ?";
        &RunMod($dbproc, $query, $feature_type);
        $dbproc->commit;
    }
    

    my %samples_n_reps_to_ID = &get_known_sample_ids($dbproc);
    
    
    my $ofh;
    my $bulk_load_file = "tmp.bulk_load_DE";
    if ($bulk_load_flag) {
        open ($ofh, ">$bulk_load_file") or die "Error, cannot write to file $bulk_load_file";
    }
    
    print STDERR "-loading the DE info\n";
    ## Load the DE info.
    {
        
        
        my @DE_result_files = <$DE_dir/*.DE_results>;
        unless (@DE_result_files) {
            die "Error, no DE_results files at $DE_dir/";
        }
        
        my %column_header_to_index = &parse_column_headers($DE_result_files[0]);
        
        ## want P-value and log2(FC) columns
        my $pval_index = $column_header_to_index{pval}
        || $column_header_to_index{PValue}
        || die "Error, cannot identify Pvalue column from " . Dumper(\%column_header_to_index);
        
        
        my $FDR_index = $column_header_to_index{padj}
        || $column_header_to_index{FDR}
        || die "Error, cannot identify FDR column from " . Dumper(\%column_header_to_index);
        
        
        my $log2FC_index = $column_header_to_index{log2FoldChange} 
        || $column_header_to_index{logFC} 
        || die "Error, cannot identify logFC column from " . Dumper(\%column_header_to_index);
        
        my $Mvalue_index = $column_header_to_index{baseMean}
        || $column_header_to_index{logCPM}
        || die "Error, cannot identify average counts column";
        
        
        my $query = "delete from Diff_expression where feature_type = ? ";
        &do_sql($dbproc, $query, $feature_type);
        $dbproc->commit;
    

        
        foreach my $DE_file (@DE_result_files) {
            # matrix.cond1_vs_cond2.
            

            print STDERR "\tloading DE from $DE_file\n";
            
            my $sampleA;
            my $sampleB;
            if ($DE_file =~ /matrix\.(\S+)_vs_(\S+)\.(edgeR|DESeq)/) {
                $sampleA = $1;
                $sampleB = $2;
            }
            else {
                die "Error, cannot extract sample info from filename: $DE_file";
            }
            
            my $sample_id_A = $samples_n_reps_to_ID{sample}->{$sampleA} or die "Error, cannot determine sample_id for $sampleA";
            my $sample_id_B = $samples_n_reps_to_ID{sample}->{$sampleB} or die "Error, cannot determine sample_id for $sampleB";
            
            ## purge earlier results:
            my $query = "delete from Diff_expression where sample_id_A = ? and sample_id_B = ? and feature_type = ?";
            &do_sql($dbproc, $query, $sample_id_A, $sample_id_B, $feature_type);
            $dbproc->commit;

            # do again with samples reversed (just in case)
            $query = "delete from Diff_expression where sample_id_A = ? and sample_id_B = ? and feature_type = ?";
            &do_sql($dbproc, $query, $sample_id_B, $sample_id_A, $feature_type);
            $dbproc->commit;

            
            
            open (my $fh, $DE_file) or die "Error, cannot open file $DE_file";
            my $header = <$fh>;
            my $counter = 0;
            while (<$fh>) {
                if (/^\#/) { next; }
                chomp;
                my $line = $_;
                
                
                my @x = split(/\t/);
                my $log_fold_change = $x[$log2FC_index];
                
                if ($log_fold_change eq "NA") { next; }
                
                my $fdr = $x[$FDR_index];
                my $pval = $x[$pval_index];
                
                if (defined($FDR_sig_only) && $fdr > $FDR_sig_only) { next; }
                if (defined($PVAL_sig_only) && $pval > $PVAL_sig_only) { next; }
                
                my $conc = $x[$Mvalue_index];
                if (exists $column_header_to_index{baseMean}) {
                    $conc = log($conc)/log(2);
                }
                
                my $feature_id = $x[0];
                
                $counter++;                
                


                if ($MAX_LOAD_PER_PAIRWISE_ANALYSIS && $counter >= $MAX_LOAD_PER_PAIRWISE_ANALYSIS) { 
                    last;
                }

                if ($bulk_load_flag) {

                    print $ofh join("\t", $sample_id_A, $sample_id_B, $feature_id, $feature_type, $conc, $log_fold_change, $pval, $fdr) . "\n";
                    
                }
                else {
                    ## populate Diff_expression table.
                    my $query = "insert into Diff_expression (sample_id_A, sample_id_B, feature_name, feature_type, log_avg_expr, log_fold_change, p_value, fdr) "
                        . " values (?,?,?,?,?,?,?,?)";
                    &do_sql($dbproc, $query, $sample_id_A, $sample_id_B, $feature_id, $feature_type, $conc, $log_fold_change, $pval, $fdr);
                    
                    
                    if ($counter % 1000 == 0) {
                        $dbproc->commit;
                    }
                }
                print STDERR "\r[$counter]   ";
            }
            print STDERR "\n";
            unless ($bulk_load_flag) {
                $dbproc->commit;
            }
        }
    }

    if ($bulk_load_flag) {
        &bulk_load_sqlite($trin_sqlite, "Diff_expression", $bulk_load_file);
        unlink($bulk_load_file);
    }
    
    print STDERR "Done loading DE data.\n";
    
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
sub get_known_sample_ids {
    my ($dbproc, $samples_href) = @_;

    my %sample_and_rep_ids;
    
    ## get existing assignments
    {
        my $query = "select sample_id, sample_name from Samples";
        my @results = &do_sql_2D($dbproc, $query);
        foreach my $result (@results) {
            my ($sample_id, $sample_name) = @$result;
            $sample_and_rep_ids{sample}->{$sample_name} = $sample_id;
        }
        
    }
    
    {
        my $query = "select replicate_id, replicate_name from Replicates";
        my @results = &do_sql_2D($dbproc, $query);
        foreach my $result (@results) {
            my ($replicate_id, $replicate_name) = @$result;
            $sample_and_rep_ids{replicate}->{$replicate_name} = $replicate_id;
        }
    }
    
    return(%sample_and_rep_ids);
}


####
sub parse_matrix {
    my ($matrix_file, $samples_n_reps_href) = @_;

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

    ## clear out any earlier results
    my $query = "delete from Expression where feature_type = ?";
    &do_sql($dbproc, $query, $feature_type);

    my $counter = 0;

    my @feature_ids = keys %$counts_matrix_href;
    
    foreach my $feature (@feature_ids) {
        
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
            
            my $query = "insert into Expression (feature_name, feature_type, replicate_id, frag_count, fpkm) "
                . " values (?,?,?,?,?)";
            &do_sql($dbproc, $query, $feature, $feature_type, $rep_id, $frag_count, $fpkm);
        
            $counter++;
            print STDERR "\r[$counter]  ";
            if ($counter % 1000 == 0) {
                $dbproc->commit;
            }
            
        }
    }
    print STDERR "\n";
    $dbproc->commit;
    
    return;
}
