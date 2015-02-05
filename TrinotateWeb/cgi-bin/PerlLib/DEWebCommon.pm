package DEWebCommon;

use strict;
use warnings;
use Carp;

use DBI;
use Sqlite_connect;

my $QUERY_DEBUG = 0;

####
sub get_expression_data {
    my ($dbproc, $params_href) = @_;

    ## get the names of the DE cache tables:
    my %FC_FDR_to_cache_table;

=not_doing
    {
        my $query = "select table_name, min_FC, max_FDR from DEcacheManager";
        my @results = &do_sql_2D($dbproc, $query);
        foreach my $result (@results) {
            my ($table_name, $min_FC, $max_FDR) = @$result;
            $FC_FDR_to_cache_table{$min_FC}->{$max_FDR} = $table_name;
        }
    }
=cut

    
    ########################################################
    ## extract parameters that limit the scope of the query
    
    # filter results based on fold change or FDR or sample type
    my $min_FC = $params_href->{min_FC};
    my $max_FDR = $params_href->{max_FDR};
    my $sample_pair = $params_href->{sample_pair};
    
    my $restrict_to_sample_pair_flag = $params_href->{restrict_to_sample_pair_flag};
    
    # restrict to specific DE cluster
    my $cluster_analysis_id = $params_href->{cluster_analysis_id};
    my $expr_cluster_id = $params_href->{expr_cluster_id};
    
    # restrict to an individual feature
    my $feature_name = $params_href->{feature_name};
        
    my $feature_type = $params_href->{feature_type};
    
    my $include_transcript_isoforms = $params_href->{include_transcript_isoforms}; # if gene feature, also retrieves that genes transcripts.
    
    
    # expression values
    my $center_vals = $params_href->{center_vals};  # 'average' or 'median'
    if ($center_vals && $center_vals !~ /average|median/) {
        confess "Error, center_vals param can be average or median, not $center_vals";
    }

    my $min_any_feature_expr = $params_href->{min_any_feature_expr};
    my $min_sum_feature_expr = $params_href->{min_sum_feature_expr};


    my $max_select = $params_href->{max_select} || 0;
    
    
    ########################################################
    
    # Rest below pulls data based on the above criteria
    

    my %sample_id_to_sample_name;
    my %sample_name_to_sample_id;
    my $query = "select sample_id, sample_name from Samples";
    my @results = &do_sql_2D($dbproc, $query);
    foreach my $result (@results) {
        my ($sample_id, $sample_name) = @$result;
        $sample_id_to_sample_name{$sample_id} = $sample_name;
        $sample_name_to_sample_id{$sample_name} = $sample_id;
    }
    
    
    my %replicate_id_to_info;
    $query = "select replicate_id, replicate_name, sample_id from Replicates";
    @results = &do_sql_2D($dbproc, $query);
    foreach my $result (@results) {
        my ($replicate_id, $replicate_name, $sample_id) = @$result;
        $replicate_id_to_info{$replicate_id} = { 
            sample_id => $sample_id,
            replicate_name => $replicate_name,
        };
    }
    
    
    ## get list of differentially expressed transcripts
    my %trans_diff_expr;
    my $select_stmt = "select distinct e.feature_name, T.annotation, e.replicate_id, e.fpkm ";
    my @tables = ("Expression e", "Transcript t");
    
    # connect e and t tables:
    my @where_conditions;

    if ($feature_name && defined($feature_type) && $feature_type eq 'G' && $include_transcript_isoforms) {
        #@where_conditions = (" e.feature_name in (T.gene_id, T.transcript_id) and T.gene_id = \"$feature_name\" ");
        @where_conditions = (   
              " ( \n"
            . "   (e.feature_name = T.gene_id and T.gene_id = \"$feature_name\" )\n"
            . "    or \n"
            . "   (e.feature_name = T.transcript_id and T.gene_id = \"$feature_name\" ) \n"
            . " )\n"
            );
        
                                
    }
    else {
        if ($feature_type) {
            @where_conditions = ($feature_type eq 'G') ? " e.feature_name = T.gene_id " : " e.feature_name = T.transcript_id ";    
        }
        else {
            ## try gene or transcript
            @where_conditions = ( " e.feature_name in (T.gene_id, T.transcript_id) ");
        }
        

        if ($feature_name) {
            push (@where_conditions, "e.feature_name = \"$feature_name\" ");
        }
    }
    
    
    if (#defined($min_FC) || defined($max_FDR) || 
        defined($sample_pair)) {
        
        push (@tables, "Diff_expression d");
        push (@where_conditions, "e.feature_name = d.feature_name");
        if ($feature_type) {
            push (@where_conditions, "e.feature_type = d.feature_type", "e.feature_type = \"$feature_type\"");
        }
    }
    
    if (defined($sample_pair)) {
        
        my ($sampleA, $sampleB) = split(/,/, $sample_pair);
        
        $sampleA = $sample_name_to_sample_id{$sampleA} or confess "Error, no sample_id for $sampleA";
        $sampleB = $sample_name_to_sample_id{$sampleB} or confess "Error, no sample_id for $sampleB";
        

        push (@where_conditions, " d.sample_id_A in (\"$sampleA\", \"$sampleB\") and d.sample_id_B in(\"$sampleB\", \"$sampleA\")  ");
    
        if ($restrict_to_sample_pair_flag) {
            push (@tables, "Samples s", "Replicates r");
            push (@where_conditions, " s.sample_id in (\"$sampleA\", \"$sampleB\") and s.sample_id = r.sample_id and r.replicate_id = e.replicate_id");
        }
    }
    
    my $created_tmp_table_flag = 0;
    my $cache_table;

    if (defined($min_FC) || defined($max_FDR)) {
        
        unless (defined $min_FC) {
            $min_FC = 1;
        }
        unless (defined $max_FDR) {
            $max_FDR = 1;
        }

        $cache_table = $FC_FDR_to_cache_table{$min_FC}->{$max_FDR};
        unless ($cache_table) {
            ## create one
            $created_tmp_table_flag = 1;

            $cache_table = "tmp_cache_table";
            
            my $query = "create temp table tmp_cache_table (feature_name, feature_type)";
            &RunMod($dbproc, $query);
            
            
            $query = "insert into tmp_cache_table "
                . " select distinct feature_name, feature_type "
                . " from Diff_expression d "
                . " where abs(d.log_fold_change) >= " . log($min_FC)/log(2)
                . " and d.fdr <= $max_FDR";
            &RunMod($dbproc, $query);
            

        }
            
        push (@tables, "$cache_table ct");
        push (@where_conditions, "ct.feature_name = e.feature_name and ct.feature_type = e.feature_type");
        
        
        #if (defined $min_FC) {
        #    my $min_log_FC = log($min_FC)/log(2);
        #    push (@where_conditions, "abs(d.log_fold_change) >= $min_log_FC");
        #}
        #if (defined $max_FDR) {
        #    push (@where_conditions, "d.fdr <= $max_FDR");
        #}
    }
    
    
    if ($cluster_analysis_id && $expr_cluster_id) {

        push (@tables, "ExprClusterAnalyses ECA", "ExprClusters EC");

        push (@where_conditions, "e.feature_name = EC.feature_name ",
              "EC.cluster_analysis_id = ECA.cluster_analysis_id",
              "ECA.cluster_analysis_id = \"$cluster_analysis_id\" ",
              "EC.expr_cluster_id = $expr_cluster_id ");
    }


    $query = $select_stmt . " from " . join(", ", @tables);

    if (@where_conditions) {
        $query .= " where " . join(" and ", @where_conditions);
    }

    if ($max_select) {
        $query .= " limit $max_select ";
        #$query .= " and e.feature_name in (select distinct e2.feature_name from Expression e2 order by e2.fpkm desc limit $max_select) ";
    }
    
    if ($QUERY_DEBUG) {
        print "<p>$query</p>\n";
        
        if (1) {
            use CGI;
            my $cgi = new CGI();
            print "<p>done.\n"; print $cgi->end_html();
            exit;
        }
    }

    print STDERR "$query\n";
    my $start = time();
    @results = &do_sql_2D($dbproc, $query);
    my $end = time();
    my $query_time = $end - $start;
    print STDERR "Query took: $query_time seconds.\n";
    
    if ($max_select && scalar(@results) == $max_select) {
        print "<p>WARNING: QUERY TRUNCATION due to SELECT LIMIT</p>\n";
    }
    
    
    my %feature_to_info;
    my %replicates;

    
    foreach my $result (@results) {

        my ($feature_name, $annot, $replicate_id, $fpkm) = @$result;
        
        $annot =~ s/\W/_/g;
        
       
        $feature_to_info{$feature_name}->{$replicate_id} = $fpkm;
        $feature_to_info{$feature_name}->{annotation} = $annot;
        
        $replicates{$replicate_id} = 1;
       
    }

    ## organize data for heatmap interface
    my @replicate_ids = sort { $replicate_id_to_info{$a}->{replicate_name} cmp $replicate_id_to_info{$b}->{replicate_name} } keys %replicate_id_to_info;
    
    my @feature_descriptions;
    my @feature_matrix;
    foreach my $feature_name (keys %feature_to_info) {
        my @row;
        
        my $max_feature_fpkm = 0;
        my $sum_feature_fpkm = 0;
        
        my $got_each_val = 1;
        
        foreach my $replicate_id (@replicate_ids) {
            my $fpkm = $feature_to_info{$feature_name}->{$replicate_id} || 0; # not storing zero expression values in db to save space.
            
            if ($fpkm > $max_feature_fpkm) {
                $max_feature_fpkm = $fpkm;
            }
            $sum_feature_fpkm += $fpkm;

            $fpkm = log($fpkm + 1)/log(2);
            push (@row, $fpkm);
        }
        
        if ($min_any_feature_expr && $max_feature_fpkm < $min_any_feature_expr) {
            next;
        }
        if ($min_sum_feature_expr && $sum_feature_fpkm < $min_sum_feature_expr) {
            next;
        }

    
        if ($center_vals) {
            
            my $center_val = ($center_vals eq "median") ? &median(@row) : &avg(@row);
            foreach my $val (@row) {
                $val -= $center_val;
            }
        }



        my $feature_annot = $feature_to_info{$feature_name}->{annotation};

        unshift(@row, $feature_name);
        #unshift (@row, "$feature_name\~$feature_annot"); # first element has to be feature name
        #                           hack to include annotation string in the visualizations.  //FIXME

        push (@feature_matrix, [@row]);
        

        push (@feature_descriptions, $feature_annot);
    }
    
    my @replicate_names;
    my @sample_names;
    
    foreach my $replicate_id (@replicate_ids) {
        my $replicate_name = $replicate_id_to_info{$replicate_id}->{replicate_name};
        push (@replicate_names, $replicate_name);
        my $sample_id = $replicate_id_to_info{$replicate_id}->{sample_id};
        my $sample_name = $sample_id_to_sample_name{$sample_id};
        push (@sample_names, $sample_name);
    }
    
    my %data = ( # the canvasXpress data table structure(
        sample_names => [@sample_names],      #          [         'sampA', 'sampB', ...]
        replicate_names => [@replicate_names],         
        value_matrix => [@feature_matrix],  # format:  [ 'gene', 'valA', 'valB', ...]
        
        #feature_descriptions => [@feature_descriptions],

        feature_to_info => \%feature_to_info, # useful for other data extractions
        #                                       feature_to_info{feature_name}->{replicate_id} = fpkm
        #                                                                    ->{annotation} = annot         
    );
    

    if ($created_tmp_table_flag) {
        ## drop it
        my $query = "drop table $cache_table";
        &RunMod($dbproc, $query);
    }


    return(%data);
}


sub sample_from_data {
    my ($data_href, $sample_size, $TOP_EXPRESSED_FLAG) = @_;

    my @new_value_matrix = @{$data_href->{value_matrix}};
    
    if (scalar(@new_value_matrix) < $sample_size) {
        confess "Error, can't sample a larger number of $sample_size from a smaller set of " . scalar(@new_value_matrix) . " points.";
    }

    use List::Util qw(shuffle max);
    if ($TOP_EXPRESSED_FLAG) {
        my @packed;
        foreach my $row (@new_value_matrix) {
            my $max_ele = max(@$row);
            push (@packed, [$max_ele, $row]);
        }
        @packed = reverse sort {$a->[0]<=>$b->[0]} @packed; # sort by max desc
        #unpack
        my @sorted_matrix;
        foreach my $p (@packed) {
            push (@sorted_matrix, $p->[1]);
        }
        @new_value_matrix = @sorted_matrix;        
    }
    else {
        @new_value_matrix = shuffle(@new_value_matrix);
    }
    
    @new_value_matrix = @new_value_matrix[0..($sample_size-1)];
    my @new_feature_descriptions; 
    
    my %new_feature_to_info;
    foreach my $row (@new_value_matrix) {
        my $feature_name = $row->[0];

        # deal with the annot name bundling hack above.
        my @parts = split(/\~/, $feature_name, 2);
        $feature_name = $parts[0];
        
        my $feature_info = $data_href->{feature_to_info}->{$feature_name} or confess "Error, no info for feature: $feature_name";
        $new_feature_to_info{$feature_name} = $feature_info;
        push (@new_feature_descriptions, $feature_info->{annotation});
    }

    my %new_data = ( sample_names => $data_href->{sample_names},
                     replicate_names => $data_href->{replicate_names},
                     value_matrix => \@new_value_matrix,
                     feature_to_info => \%new_feature_to_info,
        #             feature_descriptions => \@new_feature_descriptions,
        );
    
    return(%new_data);
}


sub median {
    my @nums = @_;
    
    @nums = sort {$a<=>$b} @nums;
        
    my $count = scalar (@nums);
    if ($count > 1 && $count % 2 == 0) {
        ## even number:
        my $half = $count / 2;
        return ( ($nums[$half-1], $nums[$half]) / 2);
    }
    else {
        ## odd number. Return middle value
        my $middle_index = int($count/2);
        return ($nums[$middle_index]);
    }
}

####
sub avg {
    my @vals = @_;

    my $sum = 0;
    foreach my $val (@vals) {
        $sum += $val;
    }

    my $avg = $sum/scalar(@vals);
    return($avg);
}


####
sub write_IGV_go_script {
    my ($sqlite_db) = @_;
    
    # href=\"http://localhost:60151/goto?locus=$molecule:" . &add_commas($start) . "-" . &add_commas($end) 

=notes

## Add this bit of code to the events parameter of the heatmap input %


events => {

    'click' => "var gene = o['y']['vars'][0]; IGV_go(gene);\n";
    }
        
=cut


 
    my $text = <<__EOJS__;

    <div id='mydiv'></div>
    <div id='mydiv2'></div>

<script>

var sqlite_db = \"$sqlite_db\";

    var IGV_go = function (gene) {

        var xmlhttp = new XMLHttpRequest();
        xmlhttp.onreadystatechange=function() {
            if (xmlhttp.readyState==4) {
                if (xmlhttp.status==200) {

                    var json = xmlhttp.responseText;
                    
                    var json_obj = eval("(" + json + ")");
                    //alert(json_obj);
                    var igv_loc = json_obj.scaffold + ":" + json_obj.lend + "-" + json_obj.rend;

                    document.getElementById("mydiv").innerHTML = "Found: " + gene + " IGV_loc: " + igv_loc + ", Annot: " + json_obj.annotation;;
                    var url="http://localhost:60151/goto?locus=" + igv_loc;
                    console.log(url);
                    //window.location.href=url;
                    IGV_set_location(url);

                }    
                else{
                    alert("couldnt find gene info for: " + gene);
                    document.getElementById("mydiv").innerHTML = "not finding: " + gene;
                }
            }
        }
        
        var url = "get_feature_loc.cgi?feature=" + encodeURIComponent(gene) + "&sqlite_db=" + encodeURIComponent(sqlite_db);
        console.log(url);
        xmlhttp.open("GET", url, true);
        xmlhttp.send(null);
        //alert("end of IGV_go()");
        
        return;
    };


    var IGV_set_location = function (url) {
        var xmlhttp = new XMLHttpRequest();
        console.log(url);
        xmlhttp.open("GET", url, true);
        xmlhttp.send(null);
        //alert("end of IGV_set_location()");
        
        return;
    };


    var launch_feature_report = function (gene) {
        
        var url = "feature_report.cgi?feature_name=" + encodeURIComponent(gene) + "&sqlite=" + encodeURIComponent(sqlite_db);
        window.open(url, '_blank');

    }


</script>

__EOJS__

;
   
    return ($text);
}

1; #EOM
