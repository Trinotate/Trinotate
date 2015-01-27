package EMBL_parser;

use strict;
use warnings;
use Carp;

sub new {
    my $packagename = shift;
    my $filename = shift;
    
    my $fh;
    if ($filename =~ /\.gz$/) {
        open ($fh, "gunzip -c $filename | ");
    }
    else {
        open ($fh, $filename) or confess "Error, cannot open file $filename";
    }
    
    my $self = {   fh => $fh,
                   filename => $filename,
               };

    bless ($self, $packagename);
    
    return($self);
}

sub next {
    my $self = shift;

    my $fh = $self->{fh};

    my $record_text = "";
    while (my $line = <$fh>) {
        $record_text .= $line;
        if ($line =~ m|^//|) {
            last;
        }
    }
    
    if ($record_text) {
        my $embl_record = EMBL_record->new($record_text);
        return($embl_record);
    }
    else {
        return undef;
    }
    
}

######################
######################

package EMBL_record;

use strict;
use warnings;

use Carp;


####
sub new {
    my $packagename = shift;
    my $record_text = shift;

    unless ($record_text) {
        confess "Error, need record text to build record obj";
    }

    my $self = {
        record => $record_text,
        sections => {}, # key => text separated by newlines for those entries with the same token

    };

    bless ($self, $packagename);

    $self->init($record_text);
    
    return($self);
}

####
sub init {
    my $self = shift;
    my $record_text = shift;

    my @lines = split(/\n/, $record_text);

    my $prev_tok = "";
    foreach my $line (@lines) {
        $line .= "\n";
        if ($line =~ /^(\S{2})\s+(.*)$/s) {
            $prev_tok = $1;
            $self->{sections}->{$prev_tok} .= $2;
        }
        else {
            if (! $prev_tok) {
                confess "Error, have line $line but no prev_tok";
            }
            $self->{sections}->{$prev_tok} .= $line;
        }
    }

    return;
}



1; #EOM
