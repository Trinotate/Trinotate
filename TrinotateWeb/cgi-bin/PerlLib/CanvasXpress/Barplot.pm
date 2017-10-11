#!/usr/bin/env perl

package CanvasXpress::Barplot;

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
                 function => "make_barplot_$canvas_id",

    };
    
    bless ($self, $packagename);

    return($self);

}

sub draw {
    my $self = shift;
    my %inputs = @_;


    my $orientation = "vertical";
    
    # structure of input hash:
    #
    #   %inputs = (
    #                title => "title for chart",
    #
    #                var_name => "variable name",
    #
    #                data = [ ["barA", 13], ["barB", 27], ... ],
    #                
    #   )
    #
    #   Optional:    orientation => "vertical"|"horizontal"  (default: "vertical")
    #

    if ($inputs{orientation}) {
        $orientation = $inputs{orientation};
    }
    
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
        . "            \"vars\": [ \"$inputs{var_name}\" ],\n";
    
    $html .=  "        \"smps\": [\n";

    foreach my $data_pt (@{$inputs{data}}) {
        my $bar_name= $data_pt->[0];
        $html .= "\"$bar_name\",";
    }
    chop $html; # rid last comma

    $html .= "],\n";
        
    $html .= "\"data\": [ [\n";
    
    foreach my $data_pt (@{$inputs{data}}) {
        my $bar_val = $data_pt->[1];
        $html .= "$bar_val, ";
    }
        
    $html .= " ]  ]\n";
    $html .= "} \n"
        . "}, \n"
        . "{\n";

    $html .= "\"axisAlgorithm\": \"wilkinson\",\n"
        . "\"axisMinMaxTickTickWidth\": false,\n"
        . "\"graphOrientation\": \"$orientation\",\n"
        . "\"maxCols\": 2,\n"
        . "\"maxRows\": 4,\n"
        . "\"title\": \"$inputs{title}\",\n"
        . "\"xAxis\": [\n"
        . "\"Variable1\"\n"
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



new CanvasXpress("canvas", {
  "y": {
    "vars": [
      "Variable1"
    ],
    "smps": [
      "Sample1",
      "Sample2",
      "Sample3"
    ],
    "data": [
      [
        33,
        44,
        55
      ]
    ]
  }
}, {
  "axisAlgorithm": "wilkinson",
  "axisMinMaxTickTickWidth": false,
  "graphOrientation": "vertical",
  "maxCols": 2,
  "maxRows": 4,
  "title": "Simple Bar graph",
  "xAxis": [
    "Variable1"
  ],
  "xAxisTitle": ""
});

