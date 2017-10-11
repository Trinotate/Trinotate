#!/usr/bin/env perl

package CanvasXpress::Sunburst;

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
                 function => "make_Sunburst_$canvas_id",

    };
    
    bless ($self, $packagename);

    return($self);

}

sub draw {
    my $self = shift;
    my %inputs = @_;

    # structure of input hash:
    #
    #   %inputs = ( title => "my plot title",
    #
    #               column_names => [colA, colB, colC],
    #
    #               column_contents => { colA => [a1, a2, a3, ...],
    #                                    colB => [b1, b2, b3, ...],
    #                                    colC => [c1, c2, c3, ...] },
    #
    #               
    #               row_values => [ 0.1, 0.2, 3.5, ... ],
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

    # build column contents
    $html .= "         \"x\": {\n";
    my @column_names = @{$inputs{column_names}};
    foreach my $column (@column_names) {
        $html .= "          \"$column\": [\n";
        my @column_contents = @{$inputs{column_contents}->{$column}};
        my $column_vals_text = "                \"" . join("\",\"", @column_contents) . "\"\n";
        $column_vals_text =~ s/\"NA\"/null/g;
        $html .= $column_vals_text;
        $html .= "                       ],";
    }
    chop $html; # rid final comma

    $html .= "         },\n";


    $html .= "\"y\": {\n"
        . "            \"vars\": [\n"
        . "                \"myData\"\n"
        . "             ],\n";

    $html .=  "        \"smps\": [\n";
    my @rownames = ();
    for (my $i = 1; $i <= $#{$inputs{'row_values'}}; $i++) {
        push (@rownames, "d$i");
    }
    $html .= " \"" . join("\",\"", @rownames) . "\"";
    $html .= "   ],\n";
    
    
    $html .= "\"data\": [\n";
    $html .=    "[ " . join(",", @{$inputs{'row_values'}}) . " ]\n";
    $html .= "   ]\n";
    $html .= "} \n"
        . "}, \n"
        . "{\n";
    $html .= " \"axisAlgorithm\": \"wilkinson\",\n"
        . "\"circularRotate\": -90,\n"
        . "\"circularType\": \"sunburst\",\n"
        . "\"colorScheme\": \"Bootstrap\",\n"
        . "\"decorationFontSize\": 6,\n"
        . "\"graphType\": \"Circular\",\n"
        . "\"hierarchy\": [\"" . join("\",\"", @column_names) . "\"],\n"
        . "\"ringsType\": [\n"
        . "\"dot\"\n"
        . "],\n"
        . "\"ringsWeight\": [\n"
        . "1\n"
        . "],\n"
        . "\"showTransition\": true,\n"
        . "\"subtitleFontSize\": 26,\n"
        . "\"title\": \"$inputs{title}\",\n"
        . "\"titleFontSize\": 28,\n"
        . "\"transitionStep\": 50,\n"
        . "\"transitionTime\": 1500,\n"
        . "\"xAxis\": [\n"
        . "\"vals\"\n"
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


# https://canvasxpress.org/html/sunburst-3.html

new CanvasXpress("canvas", {
  "x": {
    "Quarter": [
      "1st",
      "1st",
      "1st",
      "1st",
      "1st",
      "1st",
      "2nd",
      "2nd",
      "2nd",
      "3rd",
      "3rd",
      "3rd",
      "4th",
      "4th",
      "4th"
    ],
    "Month": [
      "Jan",
      "Feb",
      "Feb",
      "Feb",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ],
    "Week": [
      null,
      "Week 1",
      "Week 2",
      "Week 3",
      "Week 4",
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null
    ],
    "Color": [
      "red",
      "blue",
      "green",
      "grey",
      "red",
      "blue",
      "green",
      "grey",
      "red",
      "blue",
      "green",
      "grey",
      "red",
      "blue",
      "green"
    ]
  },
  "y": {
    "vars": [
      "Sales"
    ],
    "smps": [
      "Sales1",
      "Sales2",
      "Sales3",
      "Sales4",
      "Sales5",
      "Sales6",
      "Sales7",
      "Sales8",
      "Sales9",
      "Sales10",
      "Sales11",
      "Sales12",
      "Sales13",
      "Sales14",
      "Sales15"
    ],
    "data": [
      [
        3.5,
        1.2,
        0.8,
        0.6,
        0.5,
        1.7,
        1.1,
        0.8,
        0.3,
        0.7,
        0.6,
        0.1,
        0.5,
        0.4,
        0.3
      ]
    ]
  }
}, {
  "axisAlgorithm": "wilkinson",
  "circularRotate": -90,
  "circularType": "sunburst",
  "colorScheme": "Bootstrap",
  "decorationFontSize": 6,
  "graphType": "Circular",
  "hierarchy": [
    "Quarter",
    "Month",
    "Week"
  ],
  "ringsType": [
    "dot"
  ],
  "ringsWeight": [
    1
  ],
  "showTransition": true,
  "subtitleFontSize": 26,
  "title": "Rotated Sunburst",
  "titleFontSize": 28,
  "transitionStep": 50,
  "transitionTime": 1500,
  "xAxis": [
    "Sales"
  ],
  "xAxisTitle": ""
});

