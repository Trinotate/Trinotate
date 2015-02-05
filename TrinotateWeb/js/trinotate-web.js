$(document).ready(function (){
    // top nav tabs
    var active_tab = $('#topnav').data('active-tab');
    if (active_tab == ''){ // main page
        // navigate to indicated tab
        if (window.location.hash) {
            $('#topnav a[href="' + window.location.hash + '"]').trigger('click');
        } else {
            $('#topnav a[href="#overview"]').closest('li').addClass('active');
        }

        // set up top nav links
        $('#navbar ul.nav-tabs li').click(function(el) {
            $('#navbar ul.nav-tabs li').removeClass('active');
            $(this).addClass('active');
        });
    } else { // sub page
        // set active tab
        $('#topnav li').removeClass('active');
        $('#topnav').find('a[aria-controls="' + active_tab + '"]').closest('li').addClass('active');

        // enable top nav links to main page
        $('#navbar ul.nav-tabs li').click(function(el) {
            $('#navbar ul.nav-tabs li').removeClass('active');
            $(this).addClass('active');
            var url = 'index.cgi?sqlite_db=' + encodeURI($('#topnav').data('sqlite')) + $(this).find('a[role="tab"]').attr('href');
            window.location.href = url;
        });
    }

    // set SQLITE DB values
    $('.sqlite').val(encodeURI($('#topnav').data('sqlite')));


    // gene/transcript search case fix
    $('#gene-search input[type="submit"]').click(function (e){
        // since the SQLITE search is case-sensitive, change to upper case
        $('#feature_name').val($('#feature_name').val().toUpperCase());
        return true;
    });

    // expression sample selects
    var expressionPlotButtons = function () {
        if (!$('#expression-sample1 option:selected').prop('disabled') 
            && !$('#expression-sample2 option:selected').prop('disabled')) {
            // enable buttons
            $('#expression-plot-buttons button').prop('disabled', false);
        } else {
            // disable buttons
            $('#expression-plot-buttons button').prop('disabled', true);
        }
    }

    $('#expression-sample1').change(function(e){
        var selected_sample = $(this).find('option:selected').text();

        $('#expression-sample2 option').each(function(el){
            if ($(this).text() == selected_sample) {
                $(this).prop('disabled', true);
            } else if ($(this).text() != 'Sample1' && $(this).text() != 'Sample 2'){
                $(this).prop('disabled', false);
            }
        });

        expressionPlotButtons();
    });

    $('#expression-sample2').change(function(e){
        var selected_sample = $(this).find('option:selected').text();

        $('#expression-sample1 option').each(function(el){
            if ($(this).text() == selected_sample) {
                $(this).prop('disabled', true);
            } else {
                $(this).prop('disabled', false);
            }
        });

        expressionPlotButtons();
    });

    // expression plot buttons
    $('#DE-ma-vo').click(function (e) {
        var sample1 = $('#expression-sample1 option:selected').text();
        var sample2 = $('#expression-sample2 option:selected').text();
        var url = "DE_sample_pair.cgi?sample_pair=" + encodeURI(sample1 + ',' + sample2) + "&sqlite=" + encodeURI($('#topnav').data('sqlite'));
        //window.location.href = url;

        var win = window.open(url, "MA-VO-" + sample1 + "-" + sample2);
        win.focus();
});

    $('#DE-heatmap').click(function (e) {
        var sample1 = $('#expression-sample1 option:selected').text();
        var sample2 = $('#expression-sample2 option:selected').text();
        var url = "HeatmapNav.cgi?sample_pair=" + encodeURI(sample1 + ',' + sample2) + "&sqlite=" + encodeURI($('#topnav').data('sqlite'));
        var win = window.open(url, "Heatmap-" + sample1 + "-" + sample2);
        win.focus();
    });

    // in case we should enable buttons when navigating back to a valid selection
    expressionPlotButtons();
});

$('#topnav a').click(function (e) {
    e.preventDefault()
    $(this).tab('show')
})

