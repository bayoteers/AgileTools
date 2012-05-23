var bugItem = function(id) {
    var item = $('<li class="bugItem" id="bug_'+ id +'"/>');
    var even = !(id % 2);
    if (even) item.css("margin-left", "1em");
    item.append('<a class="idLink" href="#"># ' + id + '</a>');
    item.append('<span class="status">NEW</span>');
    if (even) {
        item.append('<span class="severity">task</span>');
    } else {
        item.append('<span class="severity">story</span>');
    }
    item.append('<span class="description">Description...</span>');
    item.append('<span class="estimates" title="original/actual/remaining">1/0/1</span>');
    item.append('<div class="details">Here be more detail of the bug...<br/>'+
            'Maybe load the first comment (aka description)</div>');
    item.click(function() {$(".details", this).slideToggle("fast")});
    return item;
}


// Entry point, this should be moved on the template
$(function() {
    page = new PlaningPage();
});

/**
 * Helper to add the default error handler on rpc calls
 */
var callRpc = function(namespace, method, params)
{
    var rpcObj = new Rpc(namespace, method, params);
    rpcObj.fail(function(error) {
        alert(namespace + "." + method + "() failed:" + error.message);
    });
    return rpcObj;
};

/**
 * Class presenting the list container
 */
var ListContainer = Base.extend(
{
    constructor: function(selector)
    {
        this.element = $(selector);
        this.contentSelector = $("select[name='contentSelector']", this.element);
        this.contentSelector.change($.proxy(this, "_changeContent"));
        this.contentFilter = $("input[name='contentFilter']", this.element);
        this.createSprint = $("button[name='createSprint']", this.element);
        this.createSprint.click($.proxy(this, "_openCreateSprint"));
        this.bugList = $("ul.bugList", this.element);
        this.footer = $("div.listFooter", this.element);

        this.onChangeContent = $.Callbacks();
    },
    _openCreateSprint: function()
    {
        this._dialog = $("#sprint_editor_template").clone();
        this._dialog.attr("id", null);
        $("[name='startDate'],[name='endDate']", this._dialog).datepicker({
            dateFormat:"yy-mm-dd",
        });
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
        var rpc = callRpc("Agile.Sprint", "create", params);
        rpc.done($.proxy(this, "_onSprintCreateDone"));
        this._dialog.dialog("close");
    },
    _onSprintCreateDone: function(result)
    {
        console.log(result);
        var option = $("<option>" + result.pool.name + "</option>");
        option.attr("value", result.pool.id);
        this.contentSelector.append(option);
        option.prop("selected", true);
    },

    _changeContent: function()
    {
        var id = this.contentSelector.val();
        var name = this.contentSelector.find(":selected").text();
        this.onChangeContent.fire(id, name);
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
    }

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
        this.left.onChangeContent.add($.proxy(this.right, "disableContentOption"));
        this.right.onChangeContent.add($.proxy(this.left, "disableContentOption"));
    },
});
