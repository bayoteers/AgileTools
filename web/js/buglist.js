/**
 * Buglist widget
 */
$.widget("agile.buglist", {

    /**
     * Default options
     */
    options: {
        sortable: true,
        itemTemplate: "#bug_item_template",
        connectWith: ".bugList",
        minHeight: 200,
    },
    /**
     * Initialize the widget
     */
    _create: function()
    {
        this._items = {};
        this.element.sortable({
            connectWith: this.options.connectWith
        });
        $.Widget.prototype._create.apply( this, arguments );
    },

    addBugs: function(bugs)
    {
        if (!$.isArray(bugs)) bugs = [bugs];
        for (var i=0; i < bugs.length; i++) {
            var bug = bugs[i];
            if (this._items[bug.id]) {
                this._items[bug.id].remove();
            }
            var item = $(this.options.itemTemplate)
                .clone().attr("id", null);
            this._items[bug.id] = item;

            var after = null;
            var level = 0;
            if (!$.isEmptyObject(bug.blocks)) {
                var upper = this.getBugItems(bug.blocks);
                if (upper.length) {
                    after = upper[0];
                    level = after.blitem("option", "level") + 1;
                }
            }

            item.blitem({bug: bug, level: level});
            if (after) {
                after.after(item);
            } else {
                this.element.append(item);
            }

            if (!$.isEmptyObject(bug.dependson)) {
                var lower = this.getBugItems(bug.dependson);
                for (var j=lower.length-1; j >= 0; j--) {
                    lower[j].blitem("option", "level",
                            item.blitem("option", "level") + 1);
                    item.after(lower[j]);
                }
            }
        }
    },

    getBugItems: function(ids)
    {
        if (!ids) {
            ids = [];
            for (var id in this._items) {
                ids.push(id);
            }
        } else if (!$.isArray(ids)){
            ids = [ids];
        }
        var bugs = [];
        for (var i = 0; i < ids.length; i++) {
            var bug = this._items[ids[i]];
            if (bug) {
                bugs.push(bug);
            }
        }
        return bugs;
    },

    /**
     * Destroy the widget
     */
    destroy: function()
    {
        this.element.sortable("destroy");
        this.element.find(":agile-blitem").remove();
        $.Widget.prototype.destroy.apply(this);
    },

});

$.widget("agile.blitem", {
    /**
     * Default options
     */
    options: {
        bug: {},
        level: 0,
        indent: 10,
    },
    /**
     * Initialize the widget
     */
    _create: function()
    {
        // toggle details visibility on click
        this.element.find("button.expand").button({
            icons: {primary: "ui-icon-circle-triangle-s"},
            text: false,
        }).click(function() {
            $(this).find(".ui-button-icon-primary").toggleClass(
                "ui-icon-circle-triangle-s ui-icon-circle-triangle-n");
            $(this).siblings(".details").slideToggle();
        });
        this._updateData();
        this._updateLevel();
    },

    _updateData:function()
    {
        var bug = this.options.bug;
        this.element.find("[title]").each(function() {
            var element = $(this);
            var key = element.attr("title");
            var value = bug[key];
            if (!$.isArray(value)) value = [value];
            for(var i = 0; i < value.length; i++) {
                element.text(value[i]);
                // Special cases
                if (["id", "dependson", "blocks"].indexOf(key) > -1) {
                    element.attr("href", "show_bug.cgi?id=" + value[i]);
                }
                if (i+1 < value.length) {
                    element.after(element.clone());
                    element = element.next();
                    element.before(" ");
                }
            }
        });
        this.element.data("bug_id", bug.id);
    },

    _updateLevel:function()
    {
        this.element.css("margin-left",
                this.options.level * this.options.indent);
    },

    _setOption: function(key, value)
    {
        $.Widget.prototype._setOption.apply( this, arguments );
        if (key == "bug") {
            this._updateData();
        }
        if (key == "level" || key == "indent") {
            this._updateLevel();
        }
    },

    /**
     * Destroy the widget
     */
    destroy: function()
    {
        $.Widget.prototype.destroy.apply(this);
    },

    /**
     * Shortcut for blitem("option", "bug")
     */
    bug: function(bug)
    {
        if (bug) {
            this._setOption("bug", bug);
        } else {
            return this.options.bug;
        }
    },

});
