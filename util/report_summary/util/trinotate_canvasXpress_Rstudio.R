

cXp_taxonomy = function(filename, num_top_cats) {

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
    
    library(canvasXpress)
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

