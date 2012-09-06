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

function initBurn()
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
        yaxis: {
            min: 0,
        },
        grid: {
            markings: getBurnMarkers(),
        },
        colors: ['#EDC240', '#CB4B4B', '#AFD8F8',],
    };
    plotBurn(BURN.type);
};

function plotBurn(type)
{
    var series;
    if (type == 'items') {
        series = [
            getIdealBurn(BURN.start_open),
            {
                label: "Open items",
                data: BURN.open_items,
                points: {show: false},
            },
        ];
    } else {
        series = [
            getIdealBurn(BURN.start_rem),
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

function getBurnMarkers()
{
    var now = new Date();
    now = now.getTime();
    var markings = [];
    var day = new Date(BURN.start);
    var end = new Date(BURN.end);
    var weekend = false;
    var from = 0;
    while (day < end) {
        if (day.getDay() != 0 && day.getDay() != 6) {
            if (weekend) {
                markings.push({
                    color:'lightgray',
                    xaxis: {from: from, to: day.getTime()},
                });
                weekend = false;
            }
        } else {
            if(!weekend) {
                from = day.getTime();
                weekend = true;
            }
        }
        day.setDate(day.getDate() + 1);
    }
    if (weekend) {
        markings.push({
            color:'lightgray',
            xaxis: {from: from, to: end.getTime()},
        });

    }
    // Today marker
    markings.push({ color: 'red', xaxis: {from: now, to: now} });

    return markings;
};

function getIdealBurn(start_value)
{
    var end = new Date(BURN.end);
    var day = new Date(BURN.start);
    var delta_days = Math.ceil((end - day) / 1000 / 60 / 60 / 24);
    var data = [];
    var week_days = 0;
    while (day < end) {
        if (day.getDay() != 0 && day.getDay() != 6) {
            week_days++;
        }
        data.push([day.getTime()]);
        day.setDate(day.getDate() + 1);
    }

    var per_day = start_value / (week_days || delta_days);
    var value = start_value;
    for (var i = 0; i < data.length; i++) {
        var day = new Date(data[i][0]);
        data[i].push(value);
        if (day.getDay() != 0 && day.getDay() != 6) {
            value = value - per_day;
        }
    }
    data.push([end.getTime(), 0]);

     return {
        data: data,
        lines: {fill: true, lineWidth: 0},
        points: {show: false},
    };
}
