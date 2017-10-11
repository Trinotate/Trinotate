#!/usr/bin/env perl

package CanvasXpress::Piechart;

use strict;
use warnings;
use Carp;

sub new {
    my $packagename = shift;
    my $canvas_id = shift;

    unless ($canvas_id && $canvas_id =~ /\w/) {
        confess "Error, need canvas id as parameter.";
    }
    

    my $self = { canvas_id => $canvas_id,
                 function => "make_piechart_$canvas_id",

    };
    
    bless ($self, $packagename);

    return($self);

}

sub draw {
    my $self = shift;
    my %inputs = @_;
    
    # structure of input hash:
    #
    #   %inputs = (
    #                pie_name => "name for the pie chart",
    #
    #                pie_slices = [ ["slice_name_A", 13], ["slice_name_B", 27], ... ],
    #
    #
    #   )
    
    my $canvas_id = $self->{canvas_id};
    my $function_name = $self->{function};

    my $html = "<!--[if IE]><script type=\"text/javascript\" src=\"canvasXpress-SF/js/excanvas.js\"></script><![endif]-->\n";


    if ($ENV{LOCAL_JS}) {
        $html .= "<script type=\"text/javascript\" src=\"/js/canvasXpress.min.js\"></script>\n";
    }
    else {
        $html .= "<script type=\"text/javascript\" src=\"http://canvasxpress.org/js/canvasXpress.min.js\"></script>\n";
    }

    #$html .= "<script type=\"text/javascript\" src=\"/cgi-bin/js/datadumper.js\"></script>\n";
    
    $html .= "<script>\n";

    $html .= "    var $function_name = function() {\n";
    $html .= "    var cx = new CanvasXpress(\"$canvas_id\", {\n";

    $html .= "\"y\": {\n"
        . "            \"vars\": [\n";
    foreach my $pie_slice (@{$inputs{pie_slices}}) {
        my $slice_name = $pie_slice->[0];
        $html .= "\"$slice_name\",\n";
    }
    chop $html; # rid last comma
    
    $html .= "             ],\n";

    $html .=  "        \"smps\": [\"$inputs{pie_name}\"],\n";
        
    $html .= "\"data\": [\n";
    
    foreach my $pie_slice (@{$inputs{pie_slices}}) {
        my $slice_val = $pie_slice->[1];
        $html .= "[$slice_val],\n";
    }
    chop $html; # rid last comma
        
    $html .= "   ]\n";
    $html .= "} \n"
        . "}, \n"
        . "{\n";

    $html .= "\"axisAlgorithm\": \"wilkinson\",\n"
        . "\"axisMinMaxTickTickWidth\": false,\n"
        . "\"graphType\": \"Pie\",\n"
        . "\"pieSegmentLabels\": \"outside\",\n"
        . "\"pieSegmentPrecision\": 1,\n"
        . "\"pieSegmentSeparation\": 2,\n"
        . "\"pieType\": \"solid\",\n"
        . "\"showTransition\": true,\n"
        . "\"smpLabelFontSize\": 24,\n"
        . "\"subtitleFontSize\": 26,\n"
        . "\"title\": \"$inputs{pie_name}\",\n"
        . "\"titleFontSize\": 28,\n"
        . "\"xAxis\": [\n"
        . "\"Sample1\"\n"
        . "],\n"
        . "\"xAxisTitle\": \"\"\n"
        . "});\n";
        
    $html .= "}\n\n";  # end of main js function 
    
    $html .= <<__EOJS__;
    
    </script>

        <div>

        <canvas id="$canvas_id" width="800" height="500"></canvas>

        </div>

__EOJS__

        ;

    return($html);
}


1; #EOM



__END__


   "y": {
    "vars": [
    "Variable1",
    "Variable2",
    "Variable3",
    "Variable4"
    ],
    "smps": [
    "Sample1"
    ],
    "data": [
      [5],
       [10],
       [25],
       [40]

      ]
    ,
    "desc": [
    "Magnitude1",
    "Magnitude2"
    ]
    }
    }, {
    "axisAlgorithm": "wilkinson",
    "axisMinMaxTickTickWidth": false,
    "graphType": "Pie",
    "pieSegmentLabels": "outside",
    "pieSegmentPrecision": 1,
    "pieSegmentSeparation": 2,
    "pieType": "solid",
    "showTransition": true,
    "smpLabelFontSize": 24,
    "subtitleFontSize": 26,
    "titleFontSize": 28,
    "xAxis": [
    "Sample1"
    ],
    "xAxisTitle": "Sample1"
    });
