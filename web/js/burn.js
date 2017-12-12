/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (C) 2012 Jolla Ltd.
 * Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>
 */

var initBurnDatePicker = function(container)
{
    var startInput = $("[name=burn_start]", container);
    var endInput = $("[name=burn_end]", container);

    startInput.datepicker({
            dateFormat:"yy-mm-dd",
            firstDay: 1,
            showWeek: true,
            maxDate: endInput.val(),
            onSelect: function(dateText) {
                endInput.datepicker("option", "minDate", dateText);
            }
        });
    endInput.datepicker({
            dateFormat:"yy-mm-dd",
            firstDay: 1,
            showWeek: true,
            minDate: startInput.val(),
            onSelect: function(dateText) {
                startInput.datepicker("option", "maxDate", dateText);
            }
        });

    $("[name=change_dates]", container).click(function() {
        var params = getQueryParams(window.location.search);
        var start = $("[name=burn_start]").val();
        var end = $("[name=burn_end]").val();
        if (start == params.burn_start &&
                end == params.burn_end) return;

        var type = $("[name=burn_type]:checked").val();
        params.burn_start = start;
        params.burn_end = end;
        params.burn_type = type;
        var query = getQueryString(params);
        window.location.href = window.location.pathname + query;
    });
};

var initBurnChart = function(data, container)
{
    var chartDiv = $("div.burnchart", container);
    var typeRadio = $("[name=burn_type]", container);
    typeRadio.change(function() {
        var newBurnType = typeRadio.filter(":checked").val();
        var oldBurnType = newBurnType == 'items' ? 'work' : 'items';
        plotBurn(chartDiv, data, newBurnType);
        try {
            if (document.URL.indexOf('burn_type') == -1) {
                var newUrl = document.URL + "&burn_type=" + newBurnType;
            } else {
                var newUrl = document.URL.replace(oldBurnType, newBurnType);
            }
            window.history.replaceState({}, document.title, newUrl);
        } catch(err) {}
    });

    data.chartOptions = {
        series: {
            lines: { show: true },
            points: { show: true }
        },
        xaxis: {
            mode: "time",
            min: data.start,
            max: data.end
        },
        yaxis: {
            min: 0
        },
        grid: {
            markings: getBurnMarkers(data)
        },
        colors: ['#EDC240', '#CB4B4B', '#AFD8F8']
    };
    plotBurn(chartDiv, data, typeRadio.filter(":checked").val() || 'items');
};

var plotBurn = function(chartDiv, data, type)
{
    var series;
    if (type == 'items') {
        series = [
            getIdealBurn(data, data.max_items),
            {
                label: "Open items",
                data: data.open_items,
                points: {show: false}
            }
        ];
        data.chartOptions.yaxis.axisLabel = BURN.itemUnit;
    } else {
        series = [
            getIdealBurn(data, data.max_work),
            {
                label: "Remaining",
                data: data.remaining
            },
            {
                label: "Actual",
                data: data.actual
            }
        ];
        data.chartOptions.yaxis.axisLabel = BURN.workUnit;
    }
    $.plot(chartDiv, series, data.chartOptions);
};

var getBurnMarkers = function(data)
{
    var markings = [];
    var day = new Date(data.start);
    day.setUTCHours(0);
    var end = new Date(data.end);
    // Don't mark weekends, if more than 3 months time span
    var markWeekends = (end - day) < 1000*60*60*24*90;
    var from = day.getTime();
    while (day < end) {
        if (markWeekends) {
            if (day.getDay() == 6) {
                // weekend starts from Saturday morning...
                from = day.getTime();
            } else if(day.getDay() == 1){
                // ...and ends to Monday morning
                markings.push({
                        color:'lightgray',
                        xaxis: {from: from, to: day.getTime()}
                });
            }
        }
        // Month marker
        if (day.getDate() == 1) {
                markings.push({
                    color:'darkgray',
                    xaxis: {
                        from: day.getTime(),
                        to: day.getTime()
                    }
                });
            }
        day.setDate(day.getDate() + 1);
    }
    // If end date is on weekend...
    if (markWeekends && day.getDay() <= 1) {
        markings.push({
                color:'lightgray',
                xaxis: {from: from, to: day.getTime()}
        });
    }
    // Today marker
    markings.push({ color: 'red', xaxis: {from: data.now, to: data.now} });

    return markings;
};

var getIdealBurn = function(data, start_value)
{
    var end = new Date(data.end);
    var day = new Date(data.start);
    day.setUTCHours(0);
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
        points: {show: false}
    };
}
