var changeDates = function()
{
    var start = $("[name=burn_start]").val();
    var end = $("[name=burn_end]").val();
    if (start == BURN.start_date &&
            end == BURN.end_date) return;

    var type = $("[name=burn_type]:checked").val();
    var params = getQueryParams(window.location.search);
    params.burn_start = start;
    params.burn_end = end;
    params.burn_type = type;
    var query = getQueryString(params);
    window.location.href = window.location.pathname + query;
};

var initBurn = function()
{
    var dateOptions = {

    };
    var startInput = $("[name=burn_start]");
    var endInput = $("[name=burn_end]");

    startInput.datepicker({
            dateFormat:"yy-mm-dd",
            firstDay: 1,
            showWeek: true,
            maxDate: endInput.val(),
            onSelect: function(dateText) {
                endInput.datepicker("option", "minDate", dateText);
            },
        });
    endInput.datepicker({
            dateFormat:"yy-mm-dd",
            firstDay: 1,
            showWeek: true,
            minDate: startInput.val(),
            onSelect: function(dateText) {
                startInput.datepicker("option", "maxDate", dateText);
            },
        });
    $("#changeDates").click(changeDates);

    $("[name=burn_type]").change(function() {
        plotBurn($("[name=burn_type]:checked").val());
    });

    BURN.chartOptions = {
        series: {
            lines: { show: true },
            points: { show: true },
        },
        xaxis: {
            mode: "time",
            min: BURN.start,
            max: BURN.end,
        },
        grid: {
            markings: getBurnMarkers(),
        },
        colors: ['#EDC240', '#CB4B4B', '#AFD8F8',],
    };
    plotBurn(BURN.type);
};

var plotBurn = function(type) {
    var series;
    if (type == 'items') {
        series = [
            {
                data: [[BURN.start, BURN.start_open], [BURN.end, 0]],
                lines: {fill: true, lineWidth: 0},
                points: {show: false},
            },
            {
                label: "Open items",
                data: BURN.open_items,
                points: {show: false},
            },
        ];
    } else {
        series = [
            {
                data: [[BURN.start, BURN.start_rem], [BURN.end, 0]],
                lines: {fill: true, lineWidth: 0},
                points: {show: false},
            },
            {
                label: "Remaining",
                data: BURN.remaining,
            },
            {
                label: "Work done",
                data: BURN.actual,
            },
        ];
    }
    $.plot("#burnchart", series, BURN.chartOptions);
};

var getBurnMarkers = function() {
    // TODO
    var now = new Date();
    now = now.getTime();
    return [
        // Today markerd
        { color: 'red', xaxis: {from: now, to: now} },
    ];
};
