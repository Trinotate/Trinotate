package CanvasXpress::BasePlot;

use strict;
use warnings;
use Carp;

## This class is abstract. Only instantiate superclasses.

sub new {
    my $packagename = shift;
    my $canvas_id = shift;

    unless ($canvas_id && $canvas_id =~ /\w/) {
        confess "Error, need canvas id as parameter.";
    }
    

    my $self = { canvas_id => $canvas_id,
                 function => "make_PLOT_$canvas_id",
                 graphType => "__Base__", # over-ride in superclass
    };
    
    bless ($self, $packagename);

    return($self);

}


sub draw {
    my $self = shift;
    my %inputs = @_;

    if ($self->{graphType} eq "__Base__") {
        confess "Error, BasePlot is abstract. Instantiate a superclass";
    }
    

    # structure of input hash:
    #
    #   %inputs = ( samples => [ 'sampleA', 'sampleB', 'sampleC', ...],
    #               value_matrix => [ ['featureA', valA, valB, valC, ...],
    #                                 ['featureB', valA, valB, valC, ...],  ... ,                                 
    #                                ],
    #               comparisons => [ ['sampleA', 'sampleB'],
    #                                ['sampleC', 'sampleA'],
    #                                ],
    #
    #                sample_annotations => {  
    #                                         tissue_type => ['liver', 'kidney', 'liver', 'kidney', ...],  # same as number of samples
    #                                         person =>      ['persA', 'persA',   'persB', 'persB', ...],
    #                                      },
    #
    #                feature_annotations => { 
    #                                         gene_name => ['gene_nameA', 'gene_nameB', 'gene_nameC', ...], # same as number of features
    #                                      },
    #
    #
    #             );
    #
    
    
    my $canvas_id = $self->{canvas_id};
    my $function_name = $self->{function};
    my $graph_type = $self->{graphType};
    
    
    my $html = "<!--[if IE]><script type=\"text/javascript\" src=\"canvasXpress-SF/js/excanvas.js\"></script><![endif]-->\n";

    if ( ($ENV{LOCAL_JS} && $ENV{LOCAL_JS} eq "1")  
        || 
        ($ENV{MONGOOSE_CGI} && $ENV{MONGOOSE_CGI} =~ /LOCAL_JS/) # backwards compat w/ mongoose implementation
        ) {
        $html .= "<script type=\"text/javascript\" src=\"/js/canvasXpress.min.js\"></script>\n";
    }
    else {
        $html .= "<script type=\"text/javascript\" src=\"http://canvasxpress.org/js/canvasXpress.min.js\"></script>\n";
    }
    
    $html .= "<script>\n";
    
    $html .= "    var $function_name = function() {\n";
    $html .= "    var cx = new CanvasXpress(\"$canvas_id\", {\n";
    

    ## reorganize some of the data.
    my @gene_ids;
    my @values;
    my $value_matrix_aref = $inputs{value_matrix};
    foreach my $row (@$value_matrix_aref) {
        my @data = @$row;
        my $gene_id = shift @data;
        push (@gene_ids, $gene_id);
        push (@values, [@data]);
    }
    

    $html .= "            \"y\": {\n";
    $html .= "                 \"vars\": [ \n";

    for (my $i = 0; $i <= $#gene_ids; $i++) {
        
        $html .= "                      \"$gene_ids[$i]\"";
        if ($i != $#gene_ids) {
            $html .= ",";
        }
        $html .= "\n";
    }
    $html .= "                ],\n";

    my @replicate_names = @{$inputs{replicate_names}};

    $html .= "                \"smps\": [\n";
    
    $html .= "                    \"" . join("\",\n                    \"", @replicate_names) . "\"\n";
    $html .= "                          ],\n";
    
    
    $html .= "            \"data\": [\n";
    
    for (my $i = 0; $i <= $#values; $i++) {
        $html .= "                  [ " . join(",", @{$values[$i]}) . "]";
        if ($i != $#values) {
            $html .= ",";
        }
        $html .= "\n";
    }
    $html .= "                   ]\n";
         
    $html .= "    }\n";


#$html .= "          \"x\": {\n";
#$html .= "          \"Desc\": [\n";
#$html .= "               \"Sample-1\",\n";
#$html .= "               \"Sample-2\",\n";
#$html .= "               \"Sample-3\"\n";
#$html .= "           ] },\n";


    if (my $sample_annotations_href = $inputs{sample_annotations}) {
        
        $html .= ",\n";
        $html .= "        \"x\": {\n";
        
        my @sample_annotation_labels = (keys %$sample_annotations_href);
        for (my $j = 0; $j <= $#sample_annotation_labels; $j++) {
            my $sample_annotation_label = $sample_annotation_labels[$j];
        
            $html .= "              \"$sample_annotation_label\": [\n";

            my @sample_annots = @{$sample_annotations_href->{$sample_annotation_label}};
            for (my $i = 0; $i <= $#sample_annots; $i++) {
                
                $html .= "                      \"$sample_annots[$i]\"";
                if ($i != $#sample_annots) {
                    $html .= ",";
                }
                $html .= "\n";
            }
            $html .= "      ]";
            if ($j != $#sample_annotation_labels) {
                $html .= ",";
            }
            $html .= "\n";
        }

        $html .= " }\n";
    }

    if (my $feature_annotations_href = $inputs{feature_annotations}) {
        
        $html .= ",\n";
        $html .= "        \"z\": {\n";
        
        my @feature_annotation_labels = (keys %$feature_annotations_href);
        for (my $j = 0; $j <= $#feature_annotation_labels; $j++) {
            my $feature_annotation_label = $feature_annotation_labels[$j];
        
            $html .= "              \"$feature_annotation_label\": [\n";

            my @feature_annots = @{$feature_annotations_href->{$feature_annotation_label}};
            for (my $i = 0; $i <= $#feature_annots; $i++) {
                
                $html .= "                      \"$feature_annots[$i]\"";
                if ($i != $#feature_annots) {
                    $html .= ",";
                }
                $html .= "\n";
            }
            $html .= "      ]";
            if ($j != $#feature_annotation_labels) {
                $html .= ",";
            }
            $html .= "\n";
        }

        $html .= " }\n";
    }
    $html .= "},\n";
    
    $html .= " {\n";
    $html .= "     \"graphType\": \"$graph_type\",\n";
    
    if (my $colorBy = $inputs{colorBy}) {
        $html .= "     \"colorBy\": \"$colorBy\",\n";
    }

    if (my $graphOrientation = $inputs{graphOrientation}) {
        $html .= "     \"graphOrientation\": \"$graphOrientation\",\n";
    }
    

    my @xAxis;
    my @yAxis;

    if (exists $inputs{comparisons}) {
    
        my @comparisons = @{$inputs{comparisons}};
        foreach my $comparison (@comparisons) {
            my ($sampA, $sampB) = @$comparison;
            push (@xAxis, $sampA);
            push (@yAxis, $sampB);
        }
        $html .= "      \"xAxis\": [\n";
        $html .= "          \"" . join("\",\n          \"", @xAxis) . "\"\n";
        $html .= "       ],\n";
        
        $html .= "      \"yAxis\": [\n";
        $html .= "          \"" . join("\",\n          \"", @yAxis) . "\"\n";
        $html .= "       ]\n";
    }
    

    if (my $events_href = $inputs{events}) {
        $html .= "},\n{\n";
                
        my @event_responses;
        
        if (my $click_js = $events_href->{click}) {
            
            my $js = "click : function(o) { $click_js }";
            push (@event_responses, $js);
        }
        if (my $mouseover_js = $events_href->{mousemove}) {
            my $js = "mousemove: function(o) { $mouseover_js }";
            push (@event_responses, $js);
        }

        if (my $dblclick_js = $events_href->{dblclick}) {
            my $js = "dblclick: function(o) { $dblclick_js }";
            push (@event_responses, $js);
        }
        
        $html .= join(",\n", @event_responses);
    }
        
    
    $html .= " });\n";
    
    $html .= "cx.draw();\n\n";
    
    $html .= "}\n";
    
    $html .= <<__EOJS__;

    
    </script>
        
      <div>
          <canvas id="$canvas_id" width="613" height="500"></canvas> 
      </div>

        
__EOJS__

    ;

    return($html);
}


1; #EOM

   
