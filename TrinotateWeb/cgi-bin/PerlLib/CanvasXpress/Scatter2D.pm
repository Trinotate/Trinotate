package CanvasXpress::Scatter2D;

use strict;
use warnings;
use Carp;
use base qw (CanvasXpress::BasePlot);


sub new {
    my $packagename = shift;
    my $self = $packagename->SUPER::new(@_);

    bless ($self, $packagename);
    
    $self->{graphType} = "Scatter2D";
    $self->{function} =~ s/PLOT/Scatter2D/;
        
    return($self);

}

1; #EOM

   
