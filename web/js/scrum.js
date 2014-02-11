/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (C) 2012 Jolla Ltd.
 * Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>
 */

/**
 * Helper to connect date picker fields
 */
function scrumDateRange(from, to, extraOpts)
{
    var options = $.extend(
        {
            dateFormat: 'yy-mm-dd',
            firstDay: 1,
            showWeek: true,
            showButtonPanel: true
        }, extraOpts);
    from.datepicker($.extend({}, options,
        {
            onSelect: function(selectedDate)
            {
                var date = $.datepicker.parseDate('yy-mm-dd', selectedDate, options);
                to.datepicker('option', 'minDate', date);
            }
        }
        )
    );
    to.datepicker($.extend({}, options,
        {
            onSelect: function(selectedDate)
            {
                var date = $.datepicker.parseDate('yy-mm-dd', selectedDate, options);
                from.datepicker('option', 'maxDate', date);
            }
        }
        )
    );
    from.datepicker('option', 'maxDate', to.datepicker('getDate'));
    to.datepicker('option', 'minDate', from.datepicker('getDate'));
};

/**
 * Helper to format date strings
 */
function scrumFormatDate(dateStr)
{
    return $.datepicker.formatDate('yy-mm-dd', new Date(dateStr));
};

/**
 * Helper to round the time units
 */
function roundTime(value)
{
    return Math.round(value * 100) / 100;
}

/**
 * Helper to get number of weekdays in date range
 */
function countDays(from, to, skip)
{
    if (skip == undefined) skip = [];
    var counter = new Date(from);
    count = 0;
    while (counter < to) {
        if (skip.indexOf(counter.getDay()) == -1) count++;
        counter.setDate(counter.getDate()+1);
    }
    return count;
};

var PoolController = ListController.extend({
    constructor: function(element, poolID)
    {
        this.base(element);
        this._selector = this._element.children("select.pool-selector");
        this._selector.change($.proxy(this, "_onPoolChange"));
        this._poolID = poolID;
    },

    load: function() {
        this.list.buglist('clear');
        this._footer.empty();
        this.callRpc('Agile.Pool', 'get', {id: this._poolID})
            .done($.proxy(this, '_onPoolGetDone'));
    },

    /**
     * Pool select change handler
     */
    _onPoolChange: function() {
        this._poolID = this._selector.val();
        this.load();
    },

    /**
     * Pool get RPC done handler
     */
    _onPoolGetDone: function(result)
    {
        this._poolID = result.id;
        this.list.buglist('option', {
            order: 'pool_order',
            receive: $.proxy(this, '_onReceive'),
            move: $.proxy(this, '_onReceive'),
            remove:$.proxy(this, '_calculateWork')
        });
        this._addBugs(result.bugs);
    },

    _addBugs: function(bugs)
    {
        bugs.sort(function(a, b) {return b.pool_order - a.pool_order});
        var elements = this.base(bugs);
        var self = this;
        elements.each(function(index, element) {
            element = $(element);
            var bug = element.blitem('bug');
            var addBugButton = $('<button class="add-child" type="button">Add child</button>');
            element.find('button.expand').first().after(addBugButton);
            addBugButton.button({
                icons: {primary: 'ui-icon-circle-plus'},
                text: false
            });
            addBugButton.bugentry({
                bug: new Bug(bug),
                clone: ['product', 'component', 'version'],
                defaults:{
                    blocks: bug.id
                },
                success: $.proxy(self, '_poolBugCreated')
            });
        });
        return elements;
    },

    _poolBugCreated: function(ev, data)
    {
        var params = {
            id: this._poolID,
            bug_id: data.bug_id
        };
        var parentItem = $(ev.target).parents(':agile-blitem');
        if (parentItem.size()) {
            var order = this.list.find(':agile-blitem').index(parentItem);
            if (order != -1) params.order = order + 2;
        }
        var self = this;
        this.callRpc('Agile.Pool', 'add_bug', params);
        this.callRpc('Bug', 'get', {ids: [data.bug_id]}).done(
                function(result) { self._addBugs(result.bugs) });
    },

    /**
     * buglist receive event handler for pool
     */
    _onReceive: function(ev, data)
    {
        data.bug.pool_order = data.index + 1;
        this.callRpc('Agile.Pool', 'add_bug', {
            id: this._poolID,
            bug_id: data.bug.id,
            order: data.bug.pool_order
        });
        data.element.removeClass('over-capacity');
    }
});

var SprintController = PoolController.extend({

    constructor: function(element, poolID)
    {
        this.base(element, poolID);
        this._sprint = null;
    },

    load: function()
    {
        this.list.buglist('clear');
        this._footer.empty();
        var rpc = this.callRpc('Agile.Sprint', 'get', {id:this._poolID});
        rpc.done($.proxy(this, '_getSprintDone'));
    },

    _getSprintDone: function(result)
    {
        this._updateSprintInfo(result);
        var rpc = this.callRpc('Agile.Pool', 'get', {id: result.id});
        rpc.done($.proxy(this, '_onPoolGetDone'));
    },

    _addBugs: function(bugs)
    {
        var elements = this.base(bugs);
        var self = this;
        elements.each(function(index, element) {
            $(element).blitem('option', 'update', $.proxy(self, '_calculateWork'));
        });
        if (elements.size()) this._calculateWork();
        return elements;
    },

    /**
     * buglist receive event handler for pool
     */
    _onReceive: function(ev, data)
    {
        this.base(ev, data);
        data.element.blitem('option', 'update', $.proxy(this, '_calculateWork'));
        this._calculateWork();
    },

    /**
     * Updates the sprint info in list footer
     */
    _updateSprintInfo: function(sprint)
    {
        this._element.children("#sprint_name").text(sprint.name);
        var info = $('#sprint_info_template').clone().attr('id', null);
        info.find('.start-date').text(scrumFormatDate(sprint.start_date));
        info.find('.end-date').text(scrumFormatDate(sprint.end_date));
        info.find('.estimated-cap').text(roundTime(sprint.capacity));
        info.find('button[name=edit]').click(
                    $.proxy(this, '_openEditSprint'));
        info.find('button[name=close]').click(
                    $.proxy(this, '_openCloseSprint'));
        if (sprint.committed) {
            info.find('button[name=close]').show();
            info.find('button[name=commit]').text('Uncommit')
                    .click($.proxy(this, '_unCommitSprint'));
        } else {
            info.find('button[name=close]').hide();
            info.find('button[name=commit]').text('Commit')
                    .click($.proxy(this, '_commitSprint'));
        }
        this._footer.empty().append(info);
        this._sprint = sprint;
    },

    /**
     * Edit sprint button handler
     */
    _openEditSprint: function()
    {
        this._dialog = $('#sprint_editor_template').clone().attr('id', null);
        var start = this._dialog.find('[name=start_date]');
        var end = this._dialog.find('[name=end_date]');
        start.val(scrumFormatDate(this._sprint.start_date));
        end.val(scrumFormatDate(this._sprint.end_date));
        scrumDateRange(start, end);

        this._dialog.find('[name=capacity]').val(this._sprint.capacity);
        this._dialog.dialog({
            title: 'Edit sprint',
            modal: true,
            buttons: {
                'Save': $.proxy(this, '_saveSprint'),
                'Cancel': function() { $(this).dialog('close') }
                },
            close: function() { $(this).dialog('destroy') }
        });
    },

    /**
     * Edit sprint dialog save button handler
     */
    _saveSprint: function()
    {
        var params = {};
        params.id = this._sprint.id;
        params.start_date = this._dialog.find('[name=start_date]').val() ||
            this._sprint.start_date;
        params.end_date = this._dialog.find('[name=end_date]').val() ||
            this._sprint.end_date;
        params.capacity = this._dialog.find('[name=capacity]').val() || 0;
        var rpc = this.callRpc('Agile.Sprint', 'update', params);
        rpc.done($.proxy(this, '_onUpdateSprintDone'));
    },

    /**
     * Sprint update RPC done handler
     */
    _onUpdateSprintDone: function(result)
    {
        this._dialog.dialog('close');
        for (var key in result.changes) {
            this._sprint[key] = result.changes[key][1];
        }
        this._updateSprintInfo(this._sprint);
        this._calculateWork();
    },

    /**
     * Close sprint button handler
     */
    _openCloseSprint: function()
    {
        if (!this._sprint) return;
        this._dialog = $('#sprint_editor_template').clone().attr('id', null);
        this._dialog.prepend('<b>Next sprint details</b>');
        var start = this._dialog.find('[name=start_date]');
        var end = this._dialog.find('[name=end_date]');
        var startDate = new Date(this._sprint.end_date);
        startDate.setDate(startDate.getDate() + 1);
        start.val(scrumFormatDate(startDate));
        scrumDateRange(start, end);

        this._dialog.dialog({
            title: 'Close sprint',
            modal: true,
            buttons: {
                'Close': $.proxy(this, '_closeSprint'),
                'Cancel': function() { $(this).dialog('close') }
                },
            close: function() { $(this).dialog('destroy') }
        });
    },

    /**
     * Close sprint dialog save button handler
     */
    _closeSprint: function()
    {
        var params = {};
        params.id = this._sprint.id;
        params.start_date = this._dialog.find('[name=start_date]').val();
        params.end_date = this._dialog.find('[name=end_date]').val();
        params.capacity = this._dialog.find('[name=capacity]').val();
        var rpc = this.callRpc('Agile.Sprint', 'close', params);
        rpc.done($.proxy(this, 'load'));
        this._dialog.dialog('close');
    },

    /**
     * Commit sprint button handler
     */
    _commitSprint: function() {
        var rpc = this.callRpc('Agile.Sprint', 'commit', {id: this._sprint.id});
        rpc.done($.proxy(this, 'load'));
    },

    /**
     * Uncommit sprint button handler
     */
    _unCommitSprint: function() {
        var rpc = this.callRpc('Agile.Sprint', 'uncommit', {id: this._sprint.id});
        rpc.done($.proxy(this, 'load'));
    },

    /**
     * Calculate the estimated amount of work in sprint
     */
    _calculateWork: function() {
        var work = 0;
        var capacity = Number(this._sprint.capacity || 0);
        var start = new Date(this._sprint.start_date);
        var end = new Date(this._sprint.end_date);
        var now = new Date();
        var days = countDays(start, end, [0,6]);
        var daysLeft = days;
        if (now > end) {
            daysLeft = 0;
        } else if (now > start) {
            daysLeft = countDays(now, end, [0,6]);
        }
        var remainingCap = daysLeft / days * capacity;

        this.list.find(':agile-blitem').each(function() {
            work += Number($(this).blitem('bug').remaining_time || 0);
            if (work > remainingCap) {
                $(this).addClass('over-capacity');
            } else {
                $(this).removeClass('over-capacity');
            }
        });
        var free = remainingCap - work;
        this._footer.find('.remaining-work').text(roundTime(work));
        this._footer.find('.remaining-cap').text(roundTime(remainingCap));
        this._footer.find('.free-cap').text(roundTime(free));
    }
});

var UnprioritizedController = ListController.extend({
    /**
     * Loads unprioritized items
     */
    load: function()
    {
        this.list.buglist('clear');
        var rpc = this.callRpc('Agile.Team', 'unprioritized_items',
                {id: SCRUM.team_id});
        rpc.done($.proxy(this, '_onUnprioritizedGetDone'));
    },

    /**
     * Team unprioritized_items RPC done handler
     */
    _onUnprioritizedGetDone: function(result)
    {
        this.list.buglist('option', {
            order: '-id',
            receive: $.proxy(this, '_onReceive'),
            move: null,
            remove: null
        });
        this._addBugs(result.bugs);
    },

    /**
     * buglist receive event handler for unprioritized items
     */
    _onReceive: function(ev, data)
    {
        if (data.bug.pool_id) {
            this.callRpc('Agile.Pool', 'remove_bug', {
                id: data.bug.pool_id,
                bug_id: data.bug.id
            });
        }
    }
});


function _initScrumPlanning() {
    var sprint;
    var backlog;
    $("div.columnbox").each(function() {
        var column = $(this);
        var container = column.children("div.list-container");
        var controller;
        switch(container.attr('id')) {
        case 'sprint':
            sprint = column;
            column.data("loaded", true);
            controller = new SprintController(container, SCRUM.sprint_id);
            controller.load();
            break;
        case 'backlog':
            backlog = column;
            column.data("loaded", true);
            if (SCRUM.backlog_id == 0) break;
            controller = new PoolController(container, SCRUM.backlog_id);
            controller.load();
            break;
        case 'unprioritized':
            controller = new UnprioritizedController(container);
            break;
        default:
            throw "Unknown container "+container.attr('id');
        }
        column.data("controller", controller);
    });
    _connectControllers(sprint, backlog);

    $("button.right").button({
        icons: { primary: "ui-icon-seek-next" },
        text: false
    }).click(function(){
        var button = $(this).button('disable');
        var hidden = $("div.columnbox").last();
        if(!hidden.data('loaded')) {
            hidden.data('controller').load();
            hidden.data('loaded', true);
        }
        var tohide = $("div.columnbox").first();
        var visible = tohide.next();
        hidden.show();
        tohide.animate({'margin-left': -tohide.width()},{
            complete: function() {
                $("div.pagebox").append(tohide);
                tohide.css("margin-left", 0);
                tohide.hide();
                button.button('enable');
            }
        });
        _connectControllers(visible, hidden);
    });

    $("button.left").button({
        icons: { primary: "ui-icon-seek-prev" },
        text: false
    }).click(function(){
        var button = $(this).button('disable');
        var hidden = $("div.columnbox").last();
        if(!hidden.data('loaded')) {
            hidden.data('controller').load();
            hidden.data('loaded', true);
        }
        var tohide = hidden.prev();
        var visible = tohide.prev();
        $("div.pagebox").prepend(hidden);
        hidden.css('margin-left', -hidden.width());
        hidden.show();
        hidden.animate({'margin-left': 0},{
            complete: function() {
                tohide.hide();
                button.button('enable');
            }
        });
        _connectControllers(visible, hidden);
    });
}

_connectControllers = function(colA, colB) {
    var contA = colA.data('controller');
    var contB = colB.data('controller');
    if (typeof(contA) == 'undefined' || typeof(contB) == 'undefined')
        return;
    contA.list.buglist('option', 'connectWith', contB.list);
    contB.list.buglist('option', 'connectWith', contA.list);
}

