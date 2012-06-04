
// Entry point, this should be moved on the template
$(function() {
    page = new PlaningPage();
});

/**
 * Helper to connect date picker fields
 */
var connectDateRange = function(from, to, extraOpts)
{
    var options = $.extend(
        {
            dateFormat: "yy-mm-dd",
            showWeek: true,
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
var formatDate = function(dateStr)
{
    return $.datepicker.formatDate("yy-mm-dd", new Date(dateStr));
};

/**
 * Class presenting the list container
 */
var ListContainer = Base.extend(
{
    constructor: function(selector)
    {
        this.element = $(selector);
        self._rpcwait = false;
        this.contentSelector = $("select[name='contentSelector']", this.element);
        this.contentSelector.change($.proxy(this, "_changeContent"));
        this.contentFilter = $("input[name='contentFilter']", this.element);
        $("button[name='createSprint']", this.element).click(
            $.proxy(this, "_openCreateSprint"));
        $("button[name='reload']", this.element).click(
            $.proxy(this, "_reload"));
        this.bugList = $("ul.bugList", this.element).buglist();
        this.footer = $("div.listFooter", this.element);
        this.header = $("div.listHeader", this.element);

        this.onChangeContent = $.Callbacks();
        this._changeContent();
        this._onWindowResize();
        $(window).on("resize", $.proxy(this, "_onWindowResize"));

        this._pool_id = null;
    },

    _onWindowResize: function()
    {
        var height = $(window).height();
        height = Math.max(height - 200, 200);
        this.bugList.css("height", height);
    },

    _reload: function()
    {
        this._changeContent();
    },

    /**
     * List content change related methods
     */
    _changeContent: function()
    {
        var id = this.contentSelector.val();
        var name = this.contentSelector.find(":selected").text();
        this.onChangeContent.fire(id, name);
        this.bugList.buglist("clear");
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
     * Sprint related methods
     */
    _openCreateSprint: function()
    {
        this._dialog = $("#sprint_editor_template").clone().attr("id", null);
        connectDateRange(this._dialog.find("[name='startDate']"),
                this._dialog.find("[name='endDate']"));

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
    _createSprint: function()
    {
        var params = {};
        params["team_id"] = SCRUM.team_id;
        params["start_date"] = this._dialog.find("[name='startDate']").val();
        params["end_date"] = this._dialog.find("[name='endDate']").val();
        params["capacity"] = this._dialog.find("[name='capacity']").val() || 0;
        var rpc = this.callRpc("Agile.Sprint", "create", params);
        rpc.done($.proxy(this, "_onCreateSprintDone"));
        this._dialog.dialog("close");
    },
    _onCreateSprintDone: function(result)
    {
        var option = $("<option>" + result.pool.name + "</option>");
        option.attr("value", result.pool.id);
        this.contentSelector.append(option);
        option.prop("selected", true);
        this.onChangeContent.fire(result.pool.id, result.pool.name);
        this._updateSprintInfo(result);
    },
    openSprint: function(id)
    {
        var rpc = this.callRpc("Agile.Sprint", "get", {id:id});
        rpc.done($.proxy(this, "_getSprintDone"));
    },
    _getSprintDone: function(result)
    {
        this._updateSprintInfo(result);
        var rpc = this.callRpc("Agile.Pool", "get", {id: result.pool.id});
        rpc.done($.proxy(this, "_onPoolGetDone"));
    },
    _updateSprintInfo: function(sprint)
    {
        var info = $("#sprint_info_template").clone().attr("id", null);
        info.find(".startDate").text(formatDate(sprint.start_date));
        info.find(".endDate").text(formatDate(sprint.end_date));
        info.find(".capacity").text(sprint.capacity);
        info.find("[name='edit']").click($.proxy(this, "_openEditSprint"));
        this.footer.html(info);
        this._sprint = sprint;
    },
    _openEditSprint: function()
    {
        if (!this._sprint) return;
        this._dialog = $("#sprint_editor_template").clone().attr("id", null);
        this._dialog.find("[name='startDate']").val(
                formatDate(this._sprint.start_date));
        this._dialog.find("[name='endDate']").val(
                formatDate(this._sprint.end_date));
        this._dialog.find("[name='capacity']").val(this._sprint.capacity);
        connectDateRange(this._dialog.find("[name='startDate']"),
                this._dialog.find("[name='endDate']"));
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
    _updateSprint: function()
    {
        if (!this._sprint) return;
        var params = {};
        params["id"] = this._sprint.id;
        params["start_date"] = this._dialog.find("[name='startDate']").val() ||
            this._sprint.start_date;
        params["end_date"] = this._dialog.find("[name='endDate']").val() ||
            this._sprint.end_date;
        params["capacity"] = this._dialog.find("[name='capacity']").val() || 0;
        var rpc = this.callRpc("Agile.Sprint", "update", params);
        rpc.done($.proxy(this, "_onUpdateSprintDone"));
        this._dialog.dialog("close");
    },
    _onUpdateSprintDone: function(result)
    {
        if (!this._sprint || this._sprint.id != result.id) return;
        for (var key in result.changes) {
            this._sprint[key] = result.changes[key][1];
        }
        this._updateSprintInfo(this._sprint);
    },

    /**
     * Backlog related methods
     */
    openBacklog: function(id)
    {
        this.footer.empty();
        var rpc = this.callRpc("Agile.Pool", "get", {id: id});
        rpc.done($.proxy(this, "_onPoolGetDone"));
    },

    /**
     * Unprioritized related methods
     */
    openUnprioritized: function()
    {
        var filter = $("#resposibility_filter_template").clone().attr("id", null);
        filter.change($.proxy(this, "_filterUnprioritized"));
        this.footer.html(filter);
        // TODO use filter;
        var rpc = this.callRpc("Agile.Team", "unprioritized_items", {id: SCRUM.team_id});
        rpc.done($.proxy(this, "_onUnprioritizedGetDone"));
    },

    _onPoolGetDone: function(result)
    {
        this._pool_id = result.id;
        this.bugList.buglist("option", {
            order: "pool_order",
            receive: $.proxy(this, "_onPoolReceive"),
            move: $.proxy(this, "_onPoolReceive"),
        });
        result.bugs.sort(function(a, b) {return b.pool_order - a.pool_order});
        for (var i = 0; i < result.bugs.length; i++) {
            this.bugList.buglist("addBug", result.bugs[i]);
        }
    },

    _onUnprioritizedGetDone: function(result)
    {
        this._pool_id = null;
        this.bugList.buglist("option", {
            order: "id",
            receive: $.proxy(this, "_onUnprioritizedReceive"),
            move: null, 
        });
        for (var i = 0; i < result.bugs.length; i++) {
            this.bugList.buglist("addBug", result.bugs[i]);
        }
    },

    _onPoolReceive: function(ev, data)
    {
        data.bug.pool_order = data.index + 1;
        this.callRpc("Agile.Pool", "add_bug", {
            id: this._pool_id,
            bug_id: data.bug.id,
            order: data.bug.pool_order,
        });
    },
    
    _onUnprioritizedReceive: function(ev, data)
    {
        if (data.bug.pool_id) {
            this.callRpc("Agile.Pool", "remove_bug", {
                id: data.bug.pool_id,
                bug_id: data.bug.id});
        }
    },

    /**
     * Helper to add the default error handler on rpc calls
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
 * Class presenting the common page functionality
 */
var PlaningPage = Base.extend(
{
    constructor: function()
    {
        this.left = new ListContainer(".listContainer.left");
        this.right = new ListContainer(".listContainer.right");
        this.left.bugList.buglist("option", "connectWith", this.right.bugList);
        this.right.bugList.buglist("option", "connectWith", this.left.bugList);
        this.left.onChangeContent.add($.proxy(this.right, "disableContentOption"));
        this.right.onChangeContent.add($.proxy(this.left, "disableContentOption"));
    },
});
