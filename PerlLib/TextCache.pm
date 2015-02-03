#!/usr/bin/env perl

package TextCache;
use strict;
use warnings;
use Carp;

my $cache_dir = $ENV{WEBSERVER_TMP} || "tmp/tcache";

## static method
sub get_cached_page {
    my ($token) = @_;

    my $cached_file = &__get_cached_filename($token);

    if (-e $cached_file) {
        my $text = `cat $cached_file`;
        
        return($text);
    }

    else {
        return(undef);
    }
}

####
sub cache_page {
    my ($token, $page_text) = @_;

    &__ensure_cache_dir();

    my $cached_file = &__get_cached_filename($token);

    open (my $ofh, ">$cached_file") or confess "Error, cannot write to file: $cached_file";
    print $ofh $page_text;
    close $ofh;

    return ($cached_file);
}



####
sub set_cache_dir {
    my ($cache_dir_setting) = @_;

    $cache_dir = $cache_dir_setting;

    &__ensure_cache_dir();

    return;
}


###############################
## Private methods below
###############################


###
sub __get_cached_filename {
    my ($token) = @_;

    $token =~ s/\W/_/g;
    
    my $filename = "$cache_dir/$token.txt";
    
    return($filename);
}

####
sub __ensure_cache_dir {
    
    unless (-d $cache_dir) {
        my $cmd = "mkdir -p $cache_dir";
        my $ret = system($cmd);
        if ($ret) {
            confess "Error, cmd: $cmd died with ret $ret";
        }
    }

    return;
}


1; #EOM
