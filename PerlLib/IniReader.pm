package IniReader;


use strict;
use warnings;
use Carp;

use Data::Dumper;


sub new {
    my $packagename = shift;
    my ($filename) = @_;
    
    my $self = { section_to_att_val => {},  # section -> att = value
                 
             };
    
    
    
    open (my $fh, $filename) or confess "Error, cannot open file $filename";
    
    my $conf_text = "";
    
    while (<$fh>) {
        if (/^[\:\#]/) { next; } ## comment line
        unless (/\w/) { next; }
        
        $conf_text .= $_;
    }
    $conf_text =~ s|\\\n||g;
    $conf_text =~ s/ +/ /g;
    
    
    print "CONF_TEXT:\n$conf_text\n";
    
    my $current_section = "";
    
    my @lines = split(/\n/, $conf_text);
    for (@lines) {
        print "$_\n";
        if (/\[([^\]]+)\]/) {
            $current_section = $1;
            $current_section = &_trim_flank_ws($current_section);
            print STDERR "Got section: $current_section\n";
        }
        elsif (/^(.*)=(.*)$/) {
            my $att = $1;
            my $val = $2;
            
            $att = &_trim_flank_ws($att);
            $val = &_trim_flank_ws($val);
            $self->{section_to_att_val}->{$current_section}->{$att} = $val;
            
        }
    }
    close $fh;
    
    bless ($self, $packagename);
    
    
    return($self);
}

####
sub get_section_headings {
    my $self = shift;
    my @section_headings = keys %{$self->{section_to_att_val}};
    
    return(@section_headings);
}

####
sub has_section_heading {
    my $self = shift;
    my ($heading) = @_;

    if (exists $self->{section_to_att_val}->{$heading}) {
        return(1);
    }
    else {
        return(0);
    }
}


####
sub get_section_attributes {
    my $self = shift;
    my $section = shift;
    
    my @attributes = keys %{$self->{section_to_att_val}->{$section}};
    
    return(@attributes);
}

####
sub get_value {
    my $self = shift;
    my ($section, $attribute) = @_;
    
    
    return ($self->{section_to_att_val}->{$section}->{$attribute});
}

####
sub get_section_hash {
    my $self = shift;
    my ($section) = @_;
    
    if (ref ($self->{section_to_att_val}->{$section}) eq 'HASH') {
        
        return(%{$self->{section_to_att_val}->{$section}});
    }
    else {
        print Dumper($self->{section_to_att_val});
        confess "Error, no section values recorded for $section";
    }
}


####
sub _trim_flank_ws {
    my ($string) = @_;
    
    $string =~ s/^\s+|\s+$//g;
    
    return($string);
}


1; #EOM

	  

	
