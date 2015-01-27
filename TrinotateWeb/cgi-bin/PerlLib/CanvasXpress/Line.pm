package CanvasXpress::Line;

use strict;
use warnings;
use Carp;
use base qw (CanvasXpress::BasePlot);


sub new {
    my $packagename = shift;
    my $self = $packagename->SUPER::new(@_);

    bless ($self, $packagename);
    
    $self->{graphType} = "Line";
    $self->{function} =~ s/PLOT/Line/;

    ## Note, can set 
    #   $self->{graphOrientation} = vertical|horizontal
        
    return($self);

}

1; #EOM

   
