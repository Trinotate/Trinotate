#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::Bin/../PerlLib");
use Pipeliner;
use Carp; 
use Cwd qw'abs_path cwd'; 
use Getopt::Long qw(:config posix_default no_ignore_case bundling pass_through);
use Fasta_reader;
use Process_cmd;
use File::Basename;
use threads;
use Thread_helper;

my $usage = <<__EOUSAGE__;

###########################
#
# --pep_file <str>    proteins in fasta file format
#
# --seqs_per_chunk    chunk size for running DeepTmHMM
#
# --CPU <int>         number of simultaneous executions
#
###########################3


__EOUSAGE__


    ;


my $util_dir = "$FindBin::Bin/";

my $help_flag;
my $pep_file;
my $seqs_per_chunk;
my $CPU = 4;

&GetOptions (                                                                                                                                         
    'h' => \$help_flag,                                                                                                                               
    'pep_file=s' => \$pep_file,
    'seqs_per_chunk=i' => \$seqs_per_chunk,
    'CPU=i' => \$CPU,
    );


if ($help_flag) {
    die $usage;
}

unless ($pep_file && $seqs_per_chunk) {
    die $usage;
}


unless (`which biolib` =~ /\w/) {
    confess "Error, cannot locate biolib and so can't launch deepTmHMM";
};

my $workdir = abs_path(cwd() . "/deep_tmhmm_workdir");
                       
if (! -d $workdir) {
    &process_cmd("mkdir -p $workdir");
}

my $fasta_reader = new Fasta_reader($pep_file);

my $chunk_no = 0;
my $seq_count = 0;

my @chunk_files;

my $chunk_ofh;

chdir ($workdir) or die "Error, cannot cd to $workdir";

my $chunks_listing_filename = "chunks.$seqs_per_chunk.list";
if (-e "$chunks_listing_filename" && -e "$chunks_listing_filename.ok") {
    # chunks already written. Just reuse them.
    print STDERR "-chunks already written. Reusing them from: $chunks_listing_filename\n";
    @chunk_files = `cat $chunks_listing_filename`;
    chomp @chunk_files;
}
else {
    print STDERR "-writing chunks.\n";
    while (my $seq_obj = $fasta_reader->next()) {
        
        $seq_count += 1;
        my $chunk = int($seq_count / $seqs_per_chunk) + 1;
        if ($chunk > $chunk_no) {
            $chunk_no = $chunk;
            my $chunk_dir = "$workdir/chunk-$chunk_no";
            if (! -d $chunk_dir) {
                &process_cmd("mkdir -p $chunk_dir");
            }
            
            my $chunk_filename = "$chunk_dir/peptides.chunk-$chunk_no.pep.fa";
            close $chunk_ofh if $chunk_ofh;
            print STDERR "-writing $chunk_filename\n";
            open($chunk_ofh, ">$chunk_filename") or die "Error, cannot write to $chunk_filename";
            push (@chunk_files, $chunk_filename);
        }
        
        
        my $fasta_entry = $seq_obj->get_FASTA_format();
        print $chunk_ofh $fasta_entry;
        
    }
    
    close $chunk_ofh if $chunk_ofh;
    
    open (my $ofh, ">$chunks_listing_filename") or die "Error, cannot write to $chunks_listing_filename";
    print $ofh join("\n", @chunk_files);
    close $ofh;
    
    system("touch $chunks_listing_filename.ok");
}


my @tmhmm_commands;

## run DeepTmHMM on each of the chunks
foreach my $chunk_file (@chunk_files) {
    my $cmd = "$util_dir/DeepTmHMM_instance_launcher.pl $chunk_file";
    push (@tmhmm_commands, $cmd);
}


print STDERR "-have " . scalar(@tmhmm_commands) . " tmhmm commands to execute.\n";

sub run_cmd {
    my ($cmd) = @_;
    print STDERR "run_cmd( $cmd )\n";
    my $ret = system($cmd);
    if ($ret) {
        die "Error, cmd: $cmd died with ret $ret";
    }
}


my $thread_helper = new Thread_helper($CPU);

foreach my $tmhmm_cmd (@tmhmm_commands) {
    print STDERR "-preparing to launch $tmhmm_cmd\n";
    $thread_helper->wait_for_open_thread();
    my $thread = threads->create(\&run_cmd, $tmhmm_cmd);
    print STDERR "-launched thread: $tmhmm_cmd\n";
    $thread_helper->add_thread($thread, $tmhmm_cmd);
}
$thread_helper->wait_for_all_threads_to_complete();

my @failures = $thread_helper->get_failed_threads();
if (@failures) {
    print STDERR "-sorry, some jobs failed:\n";
    foreach my $failure (@failures) {
        my $tid = $failure->tid;
        my $cmd = $thread_helper->{thread_id_to_command}->{$tid};
        print STDERR "-failure: $cmd\n";
    }
    exit(1);
}
else {
    print STDERR "-all tmhmm jobs completed.\n";
}

exit(0);



