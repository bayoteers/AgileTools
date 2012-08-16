/**
 * The contents of this file are subject to the Mozilla Public
 * License Version 1.1 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 *
 * The Original Code is the AgileTools Bugzilla Extension.
 *
 * The Initial Developer of the Original Code is Pami Ketolainen
 * Portions created by the Initial Developer are Copyright (C) 2012 the
 * Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Pami Ketolainen <pami.ketolainen@gmail.com>
 *
 */


/**
 * Helper to connect date picker fields
 */
function scrumDateRange(from, to, extraOpts)
{
    var options = $.extend(
        {
            dateFormat: "yy-mm-dd",
            firstDay: 1,
            showWeek: true,
            showOn: "button",
            showButtonPanel: true,
        }, extraOpts);
    from.datepicker($.extend({}, options,
        {
            onSelect: function(selectedDate)
            {
                var date = $.datepicker.parseDate("yy-mm-dd", selectedDate, options);
                to.datepicker("option", "minDate", date);
            },
        }
        )
    );
    to.datepicker($.extend({}, options,
        {
            onSelect: function(selectedDate)
            {
                var date = $.datepicker.parseDate("yy-mm-dd", selectedDate, options);
                from.datepicker("option", "maxDate", date);
            },
        }
        )
    );
    from.datepicker("option", "maxDate", to.datepicker("getDate"));
    to.datepicker("option", "minDate", from.datepicker("getDate"));
};

/**
 * Helper to format date strings
 */
function scrumFormatDate(dateStr)
{
    return $.datepicker.formatDate("yy-mm-dd", new Date(dateStr));
};

/**
 * Severity hierarchy used when adding new items
 * TODO: Move this to admin options
 */
var scrumItemSeverity = {
    goal: "story",
    story: "task",
    task: "task",
    defect: "task",
};

/**
 * Class presenting the list container
 *
 * TODO: Split the sprint/backlog/unrpioritized controllers to separate classes
 */
var ListContainer = Base.extend(
{
    constructor: function(selector)
    {
        this.element = $(selector).first();
        if(!this.element.size()) throw("List container element '" + selector +
                                       "' not found");
        self._rpcwait = false;
        this._pool_id = null;
        this.onChangeContent = $.Callbacks();

        this.contentSelector = $("select[name='content_selector']", this.element)
                .change($.proxy(this, "_changeContent"));
        this.content = $(".list-content", this.element).buglist();
        this.footer = $(".list-footer", this.element);
        this.header = $(".list-header", this.element);

        $("button[name='create_sprint']", this.header).click(
            $.proxy(this, "_openCreateSprint"));
        $("button[name='reload']", this.header).click(
            $.proxy(this, "_reload"));

        $("input[name='content_search']", this.header).keyup(
            $.proxy(this, "_search"));

        this._onWindowResize();
        $(window).on("resize", $.proxy(this, "_onWindowResize"));

        this._reload();
    },

    /**
     * Adjust the list height to changed window size
     */
    _onWindowResize: function()
    {
        var height = $(window).height();
        height = Math.max(height - 200, 200);
        this.content.css("height", height);
    },

    /**
     * Reloads the list content
     * Currently just calls _changeContent, but could me smarter
     */
    _reload: function()
    {
        this._changeContent();
    },

    /**
     * Content search field key handler
     */
    _search: function(ev)
    {
        var text = $(ev.target).val();
        this.content.buglist("search", text);
    },

    /**
     * Content selector change handler.
     */
    _changeContent: function()
    {
        var id = this.contentSelector.val();
        var name = this.contentSelector.find(":selected").text();
        this.onChangeContent.fire(id, name);
        this.content.buglist("clear");
        if (/sprint/.test(name)) {
            this.openSprint(id);
        } else if (/backlog/.test(name)) {
            this.openBacklog(id);
        } else if (id == -1) {
            this.openUnprioritized();
        } else {
            alert("Sorry, don't know how to open '" + name + "'");
        }
    },

    /**
     * Callback for onChangeContent from other list to make the option in this
     * list unselecteble
     */
    disableContentOption: function(id, name)
    {
        this.contentSelector.find(":disabled").prop("disabled", false);
        var option = this.contentSelector.find("[value='" + id + "']").prop("disabled", true);
        if (option.size() == 0) {
            option = $("<option>" + name + "</option>");
            option.attr("value", id);
            option.prop("disabled", true);
            this.contentSelector.append(option);
        }
    },

    /**
     * Craete sprint button handler.
     */
    _openCreateSprint: function()
    {
        this._dialog = $("#sprint_editor_template").clone().attr("id", null);
        var start = this._dialog.find("[name='start_date']");
        var end = this._dialog.find("[name='end_date']");
        scrumDateRange(start, end);
        start.datepicker("option", "defaultDate", "+1")
        end.datepicker("option", "defaultDate", "+7")

        this._dialog.dialog({
            title: "Create sprint",
            modal: true,
            buttons: {
                "Create": $.proxy(this, "_createSprint"),
                "Cancel": function() { $(this).dialog("close") },
                },
            close: function() { $(this).dialog("destroy") },
        });
    },

    /**
     * Create sprint dialog Create button handler
     */
    _createSprint: function()
    {
        var params = {};
        params["team_id"] = SCRUM.team_id;
        params["start_date"] = this._dialog.find("[name='start_date']").val();
        params["end_date"] = this._dialog.find("[name='end_date']").val();
        params["capacity"] = this._dialog.find("[name='capacity']").val() || 0;
        params["move_open"] = this._dialog.find("[name='move_open']").prop("checked");
        var rpc = this.callRpc("Agile.Sprint", "create", params);
        rpc.done($.proxy(this, "_onCreateSprintDone"));
        this._dialog.dialog("close");
    },

    /**
     * Create sprint RPC done handler
     */
    _onCreateSprintDone: function(result)
    {
        var newOption = $("<option>" + result.pool.name + "</option>")
            .attr("value", result.pool.id)
            .appendTo(this.contentSelector)
            .prop("selected", true);
        this.contentSelector.find("option").not(newOption).each(function() {
            var element = $(this);
            if (/sprint/.test(element.text()) && element.text() < result.pool.name) {
                element.before(newOption);
                return false;
            }
        });
        this._changeContent();
    },

    /**
     * Loads sprint with specified id in this container
     */
    openSprint: function(id)
    {
        var rpc = this.callRpc("Agile.Sprint", "get", {id:id});
        rpc.done($.proxy(this, "_getSprintDone"));
    },

    /**
     * Get sprint RPC done hnadler
     */
    _getSprintDone: function(result)
    {
        this._updateSprintInfo(result);
        var rpc = this.callRpc("Agile.Pool", "get", {id: result.pool.id});
        rpc.done($.proxy(this, "_onPoolGetDone"));
    },

    /**
     * Updates the sprint info in list footer
     */
    _updateSprintInfo: function(sprint)
    {
        var info = $("#sprint_info_template").clone().attr("id", null);
        info.find(".start-date").text(scrumFormatDate(sprint.start_date));
        info.find(".end-date").text(scrumFormatDate(sprint.end_date));
        info.find(".capacity").text(sprint.capacity);
        info.find("[name='edit']").click($.proxy(this, "_openEditSprint"));
        this.footer.empty().append(info);
        this._sprint = sprint;
    },

    /**
     * Edit sprint button handler
     */
    _openEditSprint: function()
    {
        if (!this._sprint) return;
        this._dialog = $("#sprint_editor_template").clone().attr("id", null);
        var start = this._dialog.find("[name='start_date']");
        var end = this._dialog.find("[name='end_date']");
        start.val(scrumFormatDate(this._sprint.start_date));
        end.val(scrumFormatDate(this._sprint.end_date));
        scrumDateRange(start, end);

        this._dialog.find("[name='capacity']").val(this._sprint.capacity);
        this._dialog.find("[name='move_open']").parents("tr").first().hide();
        this._dialog.dialog({
            title: "Edit sprint",
            modal: true,
            buttons: {
                "Save": $.proxy(this, "_updateSprint"),
                "Cancel": function() { $(this).dialog("close") },
                },
            close: function() { $(this).dialog("destroy") },
        });
    },

    /**
     * Edit sprint dialog save button handler
     */
    _updateSprint: function()
    {
        if (!this._sprint) return;
        var params = {};
        params["id"] = this._sprint.id;
        params["start_date"] = this._dialog.find("[name='start_date']").val() ||
            this._sprint.start_date;
        params["end_date"] = this._dialog.find("[name='end_date']").val() ||
            this._sprint.end_date;
        params["capacity"] = this._dialog.find("[name='capacity']").val() || 0;
        var rpc = this.callRpc("Agile.Sprint", "update", params);
        rpc.done($.proxy(this, "_onUpdateSprintDone"));
        this._dialog.dialog("close");
    },

    /**
     * Sprint update RPC done handler
     */
    _onUpdateSprintDone: function(result)
    {
        if (!this._sprint || this._sprint.id != result.sprint) return;
        for (var key in result.changes) {
            this._sprint[key] = result.changes[key][1];
        }
        this._updateSprintInfo(this._sprint);
        this._calculateWork();
    },

    /**
     * Loads backlog
     */
    openBacklog: function(id)
    {
        this.footer.empty();
        var rpc = this.callRpc("Agile.Pool", "get", {id: id});
        rpc.done($.proxy(this, "_onPoolGetDone"));
    },

    /**
     * Loads unrpioritized items
     */
    openUnprioritized: function()
    {
        var filter = $("#resposibility_filter_template").clone().attr("id", null);
        filter.change($.proxy(this, "_filterUnprioritized"));
        this.footer.html(filter);
        this._filterUnprioritized();

    },

    /**
     * Apply the unrpioritized items filter selections
     */
    _filterUnprioritized: function(ev)
    {
        var params = {id: SCRUM.team_id};
        if (ev) {
            this.content.buglist("clear");
            var items = $(ev.target).val();
            if (! $.isEmptyObject(items)) {
                var include = {};
                for (var i = 0; i < items.length; i++) {
                    var item = items[i].split(':');
                    if (!include[item[0]]) include[item[0]] = [];
                    include[item[0]].push(item[1]);
                }
                params.include = include;
            }
        }
        var rpc = this.callRpc("Agile.Team", "unprioritized_items", params);
        rpc.done($.proxy(this, "_onUnprioritizedGetDone"));
    },

    /**
     * Pool get RPC done handler
     */
    _onPoolGetDone: function(result)
    {
        this._pool_id = result.id;
        this.content.buglist("option", {
            order: "pool_order",
            receive: $.proxy(this, "_onPoolReceive"),
            move: $.proxy(this, "_onPoolReceive"),
            remove:$.proxy(this, "_calculateWork"),
        });
        result.bugs.sort(function(a, b) {return b.pool_order - a.pool_order});
        for (var i = 0; i < result.bugs.length; i++) {
            var bug = result.bugs[i];
            var element = this.content.buglist("addBug", bug);
            element.blitem("option", "update", $.proxy(this, "_calculateWork"));
            var addBugButton = $('<button class="add-child" type="button">Add child</button>');
            element.find('button.expand').first().after(addBugButton);
            addBugButton.button({
                icons: {primary: "ui-icon-circle-plus"},
                text: false,
            });
            addBugButton.bugentry({
                fields: ['summary','product', 'component', 'severity', 'estimated_time', 'blocked', 'description'],
                defaults:{
                    product: bug.product,
                    component: bug.component,
                    blocked: bug.id,
                    severity: scrumItemSeverity[bug.severity],
                },
                success: $.proxy(this, "_poolBugCreated"),
            });
        }
        this._calculateWork();
    },

    /**
     * Team unprioritized_items RPC done handler
     */
    _onUnprioritizedGetDone: function(result)
    {
        this._pool_id = null;
        this.content.buglist("option", {
            order: "id",
            receive: $.proxy(this, "_onUnprioritizedReceive"),
            move: null,
            remove: null,
        });
        for (var i = 0; i < result.bugs.length; i++) {
            this.content.buglist("addBug", result.bugs[i]);
        }
    },

    /**
     * buglist receive event handler for pool
     */
    _onPoolReceive: function(ev, data)
    {
        data.bug.pool_order = data.index + 1;
        this.callRpc("Agile.Pool", "add_bug", {
            id: this._pool_id,
            bug_id: data.bug.id,
            order: data.bug.pool_order,
        });
        data.element.blitem("option", "update", $.proxy(this, "_calculateWork"));
        this._calculateWork();
    },
    
    /**
     * buglist receive event handler for unprioritized items
     */
    _onUnprioritizedReceive: function(ev, data)
    {
        if (data.bug.pool_id) {
            this.callRpc("Agile.Pool", "remove_bug", {
                id: data.bug.pool_id,
                bug_id: data.bug.id});
        }
    },

    _poolBugCreated: function(ev, data)
    {
        var params = {
            id: this._pool_id,
            bug_id: data.bug_id,
        };
        var parentItem = $(ev.target).parents(":agile-blitem");
        if (parentItem.size()) {
            var order = this.content.find(":agile-blitem").index(parentItem);
            if (order != -1) params.order = order + 2;
        }
        this.callRpc("Agile.Pool", "add_bug", params);
        this.callRpc("Bug", "get", {ids: [data.bug_id]}).done(
                $.proxy(this, "_onPoolGetDone"));
    },

    /**
     * Calculate the estimated amount of work in sprint
     */
    _calculateWork: function() {
        if(!this._sprint) {
            this.content.find(":agile-blitem").removeClass("over-capacity");
            return;
        }
        var work = 0;
        var capacity = Number(this.footer.find(".capacity").text() || 0);
        this.content.find(":agile-blitem").each(function() {
            work += Number($(this).blitem("bug").remaining_time || 0);
            if (work > capacity) {
                $(this).addClass("over-capacity");
            } else {
                $(this).removeClass("over-capacity");
            }
        });
        this.footer.find(".estimated-time").text(work);
        var free = capacity - work;
        this.footer.find(".free-capacity").text(free);
    },

    /**
     * Helper to queue RPC calls and add default error handler
     */
    callRpc: function(namespace, method, params)
    {
        var rpcObj = new Rpc(namespace, method, params, false);
        var self = this;
        rpcObj.fail(function(error) {
            alert(namespace + "." + method + "() failed:" + error.message);
            self.element.clearQueue("rpc");
            self._rpcwait = false;
        });
        rpcObj.done(function() {
            self._rpcwait = false;
            self.element.dequeue("rpc");
        });
        self.element.queue("rpc", function() {
            self._rpcwait = true;
            rpcObj.start()
        });
        if (!this._rpcwait) this.element.dequeue("rpc");
        return rpcObj;
    },
});

/**
 * Page initialization function
 */
function scrumInitPage() {
        var left = new ListContainer("#list_1");
        var right = new ListContainer("#list_2");
        left.content.buglist("option", "connectWith", right.content);
        right.content.buglist("option", "connectWith", left.content);
        left.onChangeContent.add($.proxy(right, "disableContentOption"));
        right.onChangeContent.add($.proxy(left, "disableContentOption"));
}

