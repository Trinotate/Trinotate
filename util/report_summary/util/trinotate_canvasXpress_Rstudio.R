library(canvasXpress)

# functions available:
#   cXp_taxonomy
#


## Taxonomy view
cXp_taxonomy = function(filename, num_top_cats=50) {

    data = read.table(filename, header=T, row.names=NULL, sep="\t", stringsAsFactors=F)

    total_counts = sum(data$count)
    
                                        # restict to num top categories
    top_data = data[1:min(num_top_cats, nrow(data)),]
    
    remaining_counts = total_counts - sum(top_data$count)
    
                                        # add the remaining counts as 'other'
    top_data = rbind(top_data, c('other', rep(NA, 5), remaining_counts))
    
                                        # assign row names
    row.names = paste0("tax", 1:nrow(top_data))
    rownames(top_data) <- row.names
    
                                        # build the count table
    count_info = rbind(NULL, as.numeric(top_data$count))
    colnames(count_info) = rownames(top_data)
    rownames(count_info) <- c("counts")
    
                                        # remove count column
    top_data = top_data[,-ncol(top_data)]
    
    canvasXpress(
        data=count_info,
        smpAnnot=top_data,
        circularArc=360,
        circularRotate=-90,
        circularType="sunburst",
        colorScheme="Bootstrap",
        graphType="Circular",
        hierarchy=list("L1", "L2", "L3", "L4", "L5", "L6"),
        showTransition=TRUE,
        title="Taxonomic Representation of Top Blastx Hits",
        transitionStep=50,
        transitionTime=1500
    )
}

## Species pie chart
cXp_species = function(filename, min_pct=2) {
    data = read.table(filename, header=T, sep="\t", stringsAsFactors=F) 
    
    data$pct = data$count / sum(data$count) * 100
    
    top_data = data[data$pct >= min_pct,]
    
    remaining_counts = sum(data$count) - sum(top_data$count)
    remaining_pct = 100 - sum(top_data$pct)
    top_data = rbind(top_data, c('other', remaining_counts, remaining_pct))
    
    y_data = data.frame(pct=top_data$count)
    rownames(y_data) = top_data$species
    
    
    canvasXpress(
      data=y_data,
      #smpAnnot=x,
      #varAnnot=z,
      graphType="Pie",
      layout="1x1",
      pieSegmentLabels="inside",
      pieSegmentPrecision=0,
      pieSegmentSeparation=1,
      showPieGrid=TRUE,
      showPieSampleLabel=TRUE,
      showTransition=TRUE,
      #xAxis=list("Sample1"),
      title="Top Species"
    )
    
}



