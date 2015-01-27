package CanvasXpress::PlotOnLoader;

use strict;
use warnings;
use Carp;

sub new {
    my $packagename = shift;
    my $function_name = shift;

    unless ($function_name && $function_name =~ /\w/) {
        confess "Error, need name of function to be used for writing onLoad script.";
    }

    
    my $self = { plot_objs => [],
                 function => $function_name,
    };

    bless ($self, $packagename);

    return($self);
}

####
sub add_plot {
    my $self = shift;
    my $plot_obj = shift;

    unless (ref $plot_obj) {
        confess "Error, need plot obj as param";
        # could do actual checking of type here
    }
    
    push (@{$self->{plot_objs}}, $plot_obj);
    
    return;
}

####
sub write_plot_loader {
    my $self = shift;

    my $function_name = $self->{function};
    
    my $html = "<script>\n";
    
    $html .= " var $function_name = function() {\n";
    
    my @plots = $self->_get_plots();
    unless (@plots) {
        confess "Error, no plots stored in this PlotOnLoader obj.";
    }
    foreach my $plot (@plots) {
        my $function_name = $plot->{function};
        
        $html .= "        " . $function_name . "();\n";
    }
    $html .= "}\n";
    $html .= "</script>\n";
    
    return($html);
    
}

####
sub _get_plots {
    my $self = shift;
    my @plots = @{$self->{plot_objs}};

    return(@plots);
}

1; #EOM
