var BLCOUNT = 0;

/**
 * jQuery Buglist widget
 */
$.widget("agile.buglist", {

    /**
     * Default options
     */
    options: {
        order: false,
        sortable: true,
        itemTemplate: "#bug_item_template",
        connectWith: false,
    },
    /**
     * Initialize the widget
     */
    _create: function()
    {
        this._id = BLCOUNT++;
        console.log("created BL", this._id);
        this._items = {};
        this.element.addClass("buglist");

        this.element.sortable({
            connectWith: this.options.connectWith,
            stop: $.proxy(this, "_onSortStop"),
            receive: $.proxy(this, "_onSortReceive"),
            update: $.proxy(this, "_onSortUpdate"),
        });

        $.Widget.prototype._create.apply( this, arguments );
    },

    /**
     * Destroy the widget
     */
    destroy: function()
    {
        BLCOUNT--;
        this.clear();
        this.element.removeClass("buglist");
        this.element.sortable("destroy");
        $.Widget.prototype.destroy.apply(this);
    },

    clear: function()
    {
        this.element.children(":agile-blitem").blitem("destroy").remove();
        this._items = {};
    },

    _onParentReconnect: function(newConnection)
    {
        this._setOption("connectWith", newConnection);
    },

    /**
     * jQuery widget options setting method
     */
    _setOption: function(key, value)
    {
        $.Widget.prototype._setOption.apply( this, arguments );
        if (key == "connectWith") {
            this.element.sortable("option", "connectWith", value);
        }
    },

    /**
     * Add bug
     * @param bug: Bug object as received from the WS api
     * @returns: jQuery object of the created blitem
     */
    addBug: function(bug)
    {
        var element = $(this.options.itemTemplate)
            .clone().attr("id", null)
            .blitem({
                bug: bug,
                _buglist: this,
            });
        var item = element.data("blitem");
        this._items[bug.id] = item;
        this._placeItemElement(element);
        return element;
    },

    _placeItemElement: function(element)
    {
        var bug = element.blitem("bug");
        var blocked = this._items[bug.blocks[0]];
        if (blocked) {
            blocked.addDepends(element);
        } else if (this.element.find(":agile-blitem").index(element) == -1) {
            this.element.append(element);
        }
        for (var i = 0; i < bug.depends_on.length; i++) {
            var depend = this._items[bug.depends_on[i]];
            if (depend) {
                element.blitem("addDepends", depend.element);
            }
        }
    },

    _onSortStop: function(ev, ui)
    {
        console.log(this._id, "_onSortStop:", ev, ui);
        if (this.element.find(":agile-blitem").index(ui.item) == -1) {
            console.log(this._id, "_onSortStop: item removed");
            // remove item if it was moved to other list
            delete this._items[ui.item.blitem("bug").id];
        }
    },

    _onSortUpdate: function(ev, ui)
    {
        if (ui.sender) {
            console.log(this._id, "_onSortUpdate, target", ev, ui);
            ui.item.blitem("option", "_buglist", this);
            this._trigger("receive", ev, ui.item.blitem("bug"));
        } else {
            console.log(this._id, "_onSortUpdate, source", ev, ui);
            // Bounce the item to indicate where it ended
            var origMargin = ui.item.css("margin-left");
            ui.item.animate({"margin-left": "+=20"}, {queue: true})
                .animate({"margin-left": origMargin}, {queue: true});
        }
    },

    _onSortReceive: function(ev, ui)
    {
        console.log(this._id, "_onSortReceive", ev, ui);
        this._placeItemElement(ui.item);
        var index = this.element.find(":agile-blitem").index(ui.item);
        console.log("index", index);
        var item = ui.item.data("blitem");
        this._items[item.options.bug.id] = item;
    },
});

$.widget("agile.blitem", {
    /**
     * Default options
     */
    options: {
        bug: {},
        _buglist: null,
    },
    /**
     * Initialize the widget
     */
    _create: function()
    {
        this.element.addClass("blitem");
        // toggle details visibility on click
        this.element.find("button.expand").button({
            icons: {primary: "ui-icon-circle-triangle-s"},
            text: false,
        }).click(function() {
            $(this).find(".ui-button-icon-primary").toggleClass(
                "ui-icon-circle-triangle-s ui-icon-circle-triangle-n");
            $(this).siblings(".details").slideToggle();
        });

        this._dList = this.element.find("ul.dependson").sortable();
        this._dList.addClass("buglist");
        this._setBuglist(this.options._buglist);
        this._updateBug();
    },
    /**
     * Destroy the widget
     */
    destroy: function()
    {
        this.element.removeClass("blitem");
        this._dList.sortable("destroy");
        $.Widget.prototype.destroy.apply(this);
    },

    /**
     * jQuery widget options setting method
     */
    _setOption: function(key, value)
    {
        $.Widget.prototype._setOption.apply( this, arguments );
        if (key == "bug") {
            this._updateBug();
        }
        if (key == "_buglist") {
            this._setBuglist(value);
        }
    },

    _setBuglist: function(buglist)
    {
        this._dList.sortable("option", {
            connectWith: buglist.options.connectWith,
            stop: $.proxy(buglist, "_onSortStop"),
            receive: $.proxy(buglist, "_onSortReceive"),
            update: $.proxy(buglist, "_onSortUpdate"),
        });
    },

    _updateBug:function()
    {
        var bug = this.options.bug;
        // Find each element with a title atribute and set the content from
        // matching bug property
        this.element.find("[title]").each(function() {
            var element = $(this);
            var key = element.attr("title");
            var value = bug[key];
            if (!$.isArray(value)) value = [value];
            for(var i = 0; i < value.length; i++) {
                element.text(value[i]);
                // Special cases
                if (["id", "depends_on", "blocks"].indexOf(key) > -1) {
                    element.attr("href", "show_bug.cgi?id=" + value[i]);
                }
                // If there is more values, clone the element
                if (i+1 < value.length) {
                    element.after(element.clone());
                    element = element.next();
                    element.before(", ");
                }
            }
        });
    },

    addDepends: function(element)
    {
        this._dList.append(element);
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
