/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (C) 2012 Jolla Ltd.
 * Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>
 */

// Add $().reverse()
jQuery.fn.reverse = [].reverse;

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
        this._items = {};
        this._lastSearch = null;
        this._searchIndex = 0;
        this.element.addClass("buglist");
        this._emptyIndicator = $("<li>No items</li>")
            .addClass("ui-corner-all blitem")
            .appendTo(this.element);

        this.element.sortable({
            items: "> :agile-blitem",
            placeholder: "blitem-placeholder",
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
        this.clear();
        this.element.removeClass("buglist");
        this.element.sortable("destroy");
        $.Widget.prototype.destroy.apply(this);
    },

    /**
     * Removes all items from this list
     */
    clear: function()
    {
        this.element.children(":agile-blitem").blitem("destroy").remove();
        this._items = {};
        this.element.append(this._emptyIndicator);
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

    /**
     * Find correct position for new blitem element in this list using
     * the order option and bug dependencies.
     */
    _placeItemElement: function(element)
    {
        var bug = element.blitem("bug");
        var blocked = this._items[bug.blocks[0]];
        if (blocked) {
            blocked.addDepends(element);
        } else if (this.element.find(":agile-blitem").index(element) == -1) {
            var place = null;
            if (this.options.order) {
                var order = this.options.order;
                this.element.children(":agile-blitem").each(function() {
                    var tmp = $(this).blitem("bug");
                    if (tmp[order] > bug[order]) {
                        place = $(this);
                        return false;
                    }
                });
            }
            if (place) {
                place.before(element);
            } else {
                this.element.append(element);
            }
        }
        for (var i = 0; i < bug.depends_on.length; i++) {
            var depend = this._items[bug.depends_on[i]];
            if (depend) {
                element.blitem("addDepends", depend.element);
            }
        }
        this._emptyIndicator.remove();
    },

    /**
     * sortable stop event handler
     */
    _onSortStop: function(ev, ui)
    {
        if (this.element.find(":agile-blitem").index(ui.item) == -1) {
            // remove item if it was moved to other list
            delete this._items[ui.item.blitem("bug").id];
            if ($.isEmptyObject(this._items)) {
                this.element.append(this._emptyIndicator);
            }
        }
    },

    /**
     * sortable update even handler
     */
    _onSortUpdate: function(ev, ui)
    {
        var reverse = false;
        var trigger = "receive";
        var self = this;
        var items = this.element.find(":agile-blitem");

        if (!ui.sender) {
            if (items.index(ui.item) >= 0) {
                trigger = "move";
            } else {
                trigger = "remove";
            }
            /* TODO: This revese stuff is a bit hackish
             * When re-ordering the items inside single list, the backend
             * method Pool.add_bug() needs to be called in reverse order 
             * starting from the lowest dependency included in the block.
             * Otherwise the order is not updated correctly
             */
            reverse = ui.position.top > ui.originalPosition.top;
            // Bounce the item to indicate where it ended
            ui.item.blitem("bounce");
        }
        
        var movedItems = ui.item.add(":agile-blitem", ui.item);
        if (reverse) movedItems = movedItems.reverse();
        movedItems.each(function() {
            var index = items.index(this);
            self._trigger(trigger, ev, {
                bug: $(this).blitem("bug"),
                index: index,
                element: $(this),
            });
        });
    },

    /**
     * sortable receive handler
     */
    _onSortReceive: function(ev, ui)
    {
        // Place the item correctly in this list and update options
        this._placeItemElement(ui.item);
        var item = ui.item.data("blitem");
        item._setOption("_buglist", this);
        this._items[item.options.bug.id] = item;
    },

    /**
     * Free text search to find and highlight items in this list
     *
     * @param text - Text to be searched
     *
     * If same text is searched several times the list will scroll to next
     * matching matching item.
     */
    search: function(text)
    {
        this.element.find(":agile-blitem").blitem("highlight", false);
        if (this._lastSearch == text) {
            this._searchIndex++;
        } else {
            this._lastSearch = text;
            this._searchIndex = 0;
        }
        if (!text) return;
        var matches = this.element.find(":agile-blitem:contains("+text+")");
        matches.blitem("highlight", true);
        if (this._searchIndex >= matches.size()) this._searchIndex = 0;
        var topItem = matches.eq(this._searchIndex);
        if (topItem.size()) {
            topItem.blitem("bounce");
            var scrollTop = this.element.scrollTop();
            var lOffset = this.element.offset().top;
            var iOffset = topItem.offset().top;
            this.element.animate({scrollTop: scrollTop + iOffset - lOffset,});
        }
    },
});


/**
 * jQuery buglist item widget
 */
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
        // estimate button
        this.element.find("button.estimate").button({
            icons: {primary: "ui-icon-pencil"},
            text: false,
        }).click($.proxy(this, "_openEstimate"));

        this._dList = this.element.find("ul.dependson").sortable();
        this._dList.addClass("buglist");
        this._setBuglist(this.options._buglist);
        this._updateBug();
        this._originalMargin = this.element.css("margin-left");
    },

    /**
     * Destroy the widget
     */
    destroy: function()
    {
        this.element.removeClass("blitem blitem-hl")
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

    /**
     * Change the buglist where this item is connected
     */
    _setBuglist: function(buglist)
    {
        this._dList.sortable("option", {
            items: "> :agile-blitem",
            placeholder: "blitem-placeholder",
            connectWith: buglist.options.connectWith,
            stop: $.proxy(buglist, "_onSortStop"),
            receive: $.proxy(buglist, "_onSortReceive"),
            update: $.proxy(buglist, "_onSortUpdate"),
        });
    },

    /**
     * Update the bug info
     */
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
        if (bug.is_open) {
            this.element.removeClass("bz_closed");
        } else {
            this.element.addClass("bz_closed");
        }
    },

    /**
     * Add item that this item depends on to the sublist
     */
    addDepends: function(element)
    {
        var bug = element.blitem("bug");
        var place = null;
        var order = this.options._buglist.options.order;
        if (order) {
            this._dList.children(":agile-blitem").each(function() {
                var tmp = $(this).blitem("bug");
                if (tmp[order] > bug[order]) {
                    place = $(this);
                    return false;
                }
            });
        }
        if (place) {
            place.before(element);
        } else {
            this._dList.append(element);
        }
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

    /**
     * Toggle highlighting of this item
     */
    highlight: function(on) {
        if (on == null) {
            this.element.toggleClass("blitem-hl");
        } else if (on) {
            this.element.addClass("blitem-hl");
        } else {
            this.element.removeClass("blitem-hl");
        }
    },
    
    /**
     * Animated bounce of this item to highlight it's position
     */
    bounce: function()
    {
        this.element.animate({"margin-left": "+=20"}, {queue: true})
                .animate({"margin-left": this._originalMargin}, {queue: true});
    },

    // TODO: Move this out of here
    _openEstimate: function()
    {
        var form = $("#bug_estimate_editor_template").clone().attr("id", null);
        var bug = this.bug();
        form.data("bug_id", bug.id);
        form.find("span.summary").text(bug.summary);
        form.find("input").each(function() {
            $(this).val(bug[$(this).attr("name")])
        });
        var bugitem = this;
        form.dialog({
            title: "Estimate for item " + bug.id,
            modal: true,
            buttons: {
                "Update": function() {
                    var form = $(this);
                    var params = {ids: form.data("bug_id")};
                    $(this).find("input").each(function() {
                        params[$(this).attr("name")] = $(this).val();
                    });
                    var rpc = new Rpc("Bug", "update", params);
                    rpc.fail(function(error) { alert(error.message); });
                    rpc.done(function(result) {
                        var changes = result.bugs[0].changes;
                        for (var field in changes) {
                            bug[field] = changes[field].added;
                        }
                        bugitem.bug(bug);
                        form.dialog("close");
                        bugitem._trigger("update");
                    });
                },
                "Cancel": function() { $(this).dialog("close"); },
                },
            close: function() { $(this).dialog("destroy") },
        });
    },

});
