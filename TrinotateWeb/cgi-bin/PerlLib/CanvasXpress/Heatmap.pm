package CanvasXpress::Heatmap;

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
                 function => "make_Heatmap_$canvas_id",

    };
    
    bless ($self, $packagename);

    return($self);

}




sub draw {
    my $self = shift;
    my %inputs = @_;

    # structure of input hash:
    #
    #   %inputs = ( samples => [ 'sampleA', 'sampleB', 'sampleC', ...],
    #               value_matrix => [ ['featureA', valA, valB, valC, ...],
    #                                 ['featureB', valA, valB, valC, ...],  ... ,                                 
    #                                ],
    #                    ## and optionally:
    #               feature_tree => "", # string containing the newick formatted tree
    #               sample_tree => "",  # ditto above
    #               feature_descriptions => ['name of feature A', 'name of feature B', ...],
    #               cluster_features => 0|1,   ## clustering done in browser, exclusive with feature_tree option
    #               cluster_samples => 0|1,
    #               dendrogramSpace => undef, # default is 6 apparently
    #             );
    #
    
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
    

#$html .= "          \"x\": {\n";
#$html .= "          \"Desc\": [\n";
#$html .= "               \"Sample-1\",\n";
#$html .= "               \"Sample-2\",\n";
#$html .= "               \"Sample-3\"\n";
#$html .= "           ] },\n";

    
    my @smp_overlays;
    
    if (my $sample_annotations_href = $inputs{sample_annotations}) {

        $html .= "        \"x\": {\n";
        
        my @sample_annotation_labels = (keys %$sample_annotations_href);
        for (my $j = 0; $j <= $#sample_annotation_labels; $j++) {
            my $sample_annotation_label = $sample_annotation_labels[$j];
            
            push (@smp_overlays, $sample_annotation_label);
            
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

        $html .= " },\n";
    }


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
    $html .= "            \"vars\": [ \n";

    for (my $i = 0; $i <= $#gene_ids; $i++) {
        
        $html .= "             \"$gene_ids[$i]\"";
        if ($i != $#gene_ids) {
            $html .= ",";
        }
        $html .= "\n";
    }
    $html .= "                ],\n";

    my @replicate_names = @{$inputs{replicate_names}};

    $html .= "                \"smps\": [\n";
    
    $html .= "            \"" . join("\",\"", @replicate_names) . "\"\n";
    $html .= "                          ],\n";
    
    
    $html .= "            \"data\": [\n";
    
    for (my $i = 0; $i <= $#values; $i++) {
        $html .= "[ " . join(",", @{$values[$i]}) . "]";
        if ($i != $#values) {
            $html .= ",";
        }
        $html .= "\n";
    }
    $html .= "                   ]\n";
    $html .= "      }\n";
        
    if (my $feature_descriptions_aref = $inputs{feature_descriptions}) {
        $html .= "     ,\n";
        $html .= "   \"z\": { \n";
        $html .= "            \"Desc\": [\n";
#$html .= "                       \"Expression\"\n";
        for (my $i = 0; $i <= $#gene_ids; $i++) {
            my $feature_descr = $feature_descriptions_aref->[$i];
            $feature_descr =~ s/[\'\"]/ /g;
            $html .= "             \"$feature_descr\"\n";
            if ($i != $#gene_ids) {
                $html .= ",";
            }
            $html .= "\n";
        }
        $html .= "                   ] },\n";
    };

    if (my $feature_tree = $inputs{feature_tree}) {
    
        $html .= "    ,\n";
        ## gene tree
        $html .= "  \"t\" : {\n";
        $html .= "     \"vars\" : \"$feature_tree\"\n";
        $html .= "    }\n"; 
        
    }
    
    $html .= " },\n";
    
    $html .= " {\n";
    $html .= "     \"graphType\": \"Heatmap\"\n";
    $html .= "     ,\"zoomSamplesDisable\": true\n";
    $html .= "     ,\"smpLabelScaleFontFactor\" : 2\n";

    #$html .= "     ,\"widthFactor\" : 4\n";
    #$html .= "     ,\"sampleSeparationFactor\" : 4\n";
    #$html .= "     ,\"variableSeparationFactor\" : 4\n";

    if (@smp_overlays) {
        $html .= ",'smpOverlays': [\'" . join("\',\'", @smp_overlays) . "\']\n";
    }
    
    #$html .= "      ,\"smpLabelDescription\": \"Desc\"\n";
    if ($inputs{feature_descriptions}) {
        $html .= "      ,\"varLabelDescription\": \"Desc\"\n";
    }
    if ($inputs{feature_tree}) {
        $html .= "     ,\"showVarDendrogram\": true\n";
    }
    if (exists $inputs{dendrogramSpace}) {
        my $dendrogramSpace = $inputs{dendrogramSpace};
        $html .= "     ,\"dendrogramSpace\" : $dendrogramSpace\n";
    }
    #if (exists ($inputs{showSmpDendrogram})) {
    #    $html .= "    ,\"showSmpDendrogram\" : " . (($inputs{showSmpDendrogram}) ? "true" : "false") . "\n";
    #}
    #if (exists ($inputs{showVarDendrogram})) {
    #    $html .= "    ,\"showVarDendrogram\" : " . (($inputs{showVarDendrogram}) ? "true" : "false") . "\n";
    #}


    if (exists($inputs{setMinX})) {
        $html .= ", \"setMinX\" : $inputs{setMinX}\n";
    }
    if (exists($inputs{setMaxX})) {
        $html .= ", \"setMaxX\" : $inputs{setMaxX}\n";
    }

    #$html .= "     ,\"setMaxX\" : 5\n";
    #$html .= "     ,\"setMinX\" : 2\n";
    
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
    
    if ($inputs{cluster_features} ) {
        $html .= "cx.clusterVariables();\n";
    }
    if ($inputs{cluster_samples}) {
        $html .= "cx.clusterSamples();\n";
    }
    #$html .= "cx.setDimensions(700, 500);\n"; # width,height
    
    if (exists ($inputs{showSmpDendrogram})) {
        $html .= "cx.showSmpDendrogram = " . (($inputs{showSmpDendrogram}) ? "true" : "false") . ";\n";
    }
    if (exists ($inputs{showVarDendrogram})) {
        $html .= "cx.showVarDendrogram = " . (($inputs{showVarDendrogram}) ? "true" : "false") . ";\n";
    }
    

    #$html .= "cx.showVarDendrogram = false;\n";
    #$html .= "cx.showSmpDendrogram = false;\n";
    #$html .= "cx.draw();\n";

    $html .= " }\n";
    
    $html .= <<__EOJS__;
    
    </script>
        
      <div>

         <canvas id="$canvas_id" width="800" height="500"></canvas> 
        
      </div>
        
__EOJS__

    ;

    return($html);
}
 

#<canvas id="$canvas_id" width="600" height="500"></canvas> 

1; #EOM

   
