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
#  --sqlite <string>              path to the Trinotate sqlite database
#
#  --samples_file <string>        file describing samples and replicates
#
#  Expression loading:
#
#  --count_matrix <string>        raw fragment counts matrix
#  --fpkm_matrix <string>         fpkm normalized expression value matrix
#
#  DE-results loading:
#
#  --DE_dir <string>              DE analysis directory
#
#  AND
#
#  --transcript_mode              analysis is performed based on Trinity transcripts (isoforms)
#  OR
#  --gene_mode                    analysis is performed based on Trinity 'genes'
#
#  Options:
#
#  --min_log_fold_change <float>    default: 1 (so 2-fold diff)
#  --max_FDR <float>                default: 0.1
#
##################################################################################################



__EOUSAGE__

    ;


my $sqlite;
my $count_matrix_file;
my $fpkm_matrix_file;
my $DE_dir;
my $transcript_mode = 0;
my $gene_mode = 0;
my $help_flag;
my $samples_file;

my $min_log_fold_change = 1;
my $max_FDR = 0.1;

&GetOptions (  'h' => \$help_flag,
               
               'sqlite=s' => \$sqlite,

               'samples_file=s' => \$samples_file,

               'count_matrix=s' => \$count_matrix_file,
               'fpkm_matrix=s' => \$fpkm_matrix_file,
               'DE_dir=s' => \$DE_dir,
               
               'transcript_mode' => \$transcript_mode,
               'gene_mode' => \$gene_mode,
               
               'min_log_fold_change=f' => \$min_log_fold_change,
               'max_FDR=f' => \$max_FDR,
               
               );


if ($help_flag) {
    die $usage;
}

unless ($sqlite
        &&
        $samples_file
        &&
        ($count_matrix_file && $fpkm_matrix_file ||  $DE_dir) 
        && ($transcript_mode || $gene_mode) ) {
    die $usage;
}

our $SEE = 0;


main: {

    my $dbproc = DBI->connect( "dbi:SQLite:$sqlite" ) || die "Cannot connect: $DBI::errstr";


    $dbproc->do("PRAGMA synchronous=OFF");
    $dbproc->{AutoCommit} = 0;
    
    
    my $feature_type = ($transcript_mode) ? 'T' : 'G';
    
    my %samples = &parse_samples_file($samples_file);
    
    print STDERR "Samples and replicates: " . Dumper(\%samples);
    
    my %samples_n_reps_to_ID = &get_sample_ids($dbproc, \%samples);
    
    print STDERR "Sample and replicate database identifiers: " . Dumper(\%samples_n_reps_to_ID);
    
    if ($count_matrix_file && $fpkm_matrix_file) {
        
        print STDERR "-parsing counts matrix: $count_matrix_file\n";
        my %counts_matrix = &parse_matrix($count_matrix_file, \%samples_n_reps_to_ID);
        
        print STDERR "-parsing fpkm matrix: $fpkm_matrix_file\n";
        my %fpkm_matrix = &parse_matrix($fpkm_matrix_file, \%samples_n_reps_to_ID);
        
        print STDERR "-populating Expression table\n";
        &populate_expression_table($dbproc, \%samples_n_reps_to_ID, \%counts_matrix, \%fpkm_matrix, $feature_type);
    }
        
    
    ## Load the DE info.
    if ($DE_dir) {
        
        print STDERR "-loading the DE info\n";
        
        my @DE_result_files = <$DE_dir/*.DE_results>;
        unless (@DE_result_files) {
            die "Error, no DE_results files at $DE_dir/";
        }
        
        my %column_header_to_index = &parse_column_headers($DE_result_files[0]);
        
        ## want P-value and log2(FC) columns
        my $pval_index = $column_header_to_index{pval}
        || $column_header_to_index{PValue}
        || $column_header_to_index{pvalue}
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
            if ($DE_file =~ /\S.*matrix\.(\S+)_vs_(\S+)\.(edgeR|DESeq|voom)/) {
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
                
                if (abs($log_fold_change) < $min_log_fold_change) { next; }
                

                my $fdr = $x[$FDR_index];
                
                if ($fdr > $max_FDR) { next; }


                my $pval = $x[$pval_index];
                my $conc = $x[$Mvalue_index];
                if (exists $column_header_to_index{baseMean}) {
                    $conc = log($conc)/log(2);
                }
                
                my $feature_id = $x[0];
                
                ## populate Diff_expression table.
                my $query = "insert into Diff_expression (sample_id_A, sample_id_B, feature_name, feature_type, log_avg_expr, log_fold_change, p_value, fdr) "
                    . " values (?,?,?,?,?,?,?,?)";
                &do_sql($dbproc, $query, $sample_id_A, $sample_id_B, $feature_id, $feature_type, $conc, $log_fold_change, $pval, $fdr);
              
                $counter++;                
                if ($counter % 1000 == 0) {
                    $dbproc->commit;
                }
                print STDERR "\r[$counter]   ";
            }
            print STDERR "\n";
            $dbproc->commit;
        }
    }


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
            
            unless ($frag_count > 0) { next; }

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
