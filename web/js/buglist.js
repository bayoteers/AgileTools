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

// Add case-insensitive :contains selector
jQuery.expr[':'].icontains = function(a, i, m) {
  return jQuery(a).text().toUpperCase()
      .indexOf(m[3].toUpperCase()) >= 0;
};


/**
 * jQuery Buglist widget
 */
$.widget("agile.buglist", {

    /**
     * Options:
     * order:        Bug field used to sort the list. If prefixed with '-', sort
     *               in descending order. (Default false = no sorting)
     * sortable:     If true the items in the list can be dragged around
     *               (Default true)
     * connectWith:  CSS selector to connect the sortable list with others
     *               (Default false = not connected)
     */
    options: {
        order: false,
        sortable: true,
        connectWith: false
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
        if (this.options.sortable) {
            this.element.sortable({
                containment: "document",
                scroll: false,
                items: "> :agile-blitem",
                placeholder: "blitem-placeholder",
                connectWith: this.options.connectWith,
                stop: $.proxy(this, "_onSortStop"),
                receive: $.proxy(this, "_onSortReceive"),
                update: $.proxy(this, "_onSortUpdate"),
                sort: _scrollWindow
            });
        }

        var fields = $("#blitem-template").text().match(/\{([^\}]+)\}/g) || [];
        this._blitemFields = fields.map(function(f){return f.slice(1,-1)});

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
        if (this.options.sortable && key == "connectWith") {
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
        var element = $("#blitem-template")
            .clone().attr("id", null)
            .blitem({
                bug: bug,
                buglist: this,
                fields: this._blitemFields
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

        var blocked = this.element.find(":agile-blitem").filter(function() {
            return bug.blocks.indexOf($(this).blitem("bug").id) != -1;
        }).first()

        if (blocked.size()) {
            blocked.blitem("addDepends", element);
        } else if (this.element.find(":agile-blitem").index(element) == -1) {
            var place = null;
            if (this.options.order) {
                var reverse = false;
                var order = this.options.order;
                if (order.charAt(0) == '-') {
                    order = order.slice(1);
                    reverse = true;
                }
                this.element.children(":agile-blitem").each(function() {
                    var tmp = $(this).blitem("bug");
                    if ((reverse && tmp[order] < bug[order]) ||
                        (tmp[order] > bug[order]))
                    {
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
        // Add the child items
        var movedItems = ui.item.add(":agile-blitem", ui.item);
        if (reverse) movedItems = movedItems.reverse();
        movedItems.each(function() {
            var element = $(this);
            var bug = element.blitem("bug");
            var index = items.index(this);
            self._trigger(trigger, ev, {
                bug: bug,
                index: index,
                element: element
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
        item._setOption("buglist", this);
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
        var matches = this.element.find(":agile-blitem:icontains("+text+")");
        matches.blitem("highlight", true);
        if (this._searchIndex >= matches.size()) this._searchIndex = 0;
        var topItem = matches.eq(this._searchIndex);
        if (topItem.size()) {
            topItem.blitem("bounce");
            var scrollTop = this.element.scrollTop();
            var lOffset = this.element.offset().top;
            var iOffset = topItem.offset().top;
            this.element.animate({scrollTop: scrollTop + iOffset - lOffset});
        }
    }
});

/**
 * sortable sort handler
 * XXX: sortable scrolling doesn't seem to work, so we do the window
 *      scrolling here
 */
var _scrollWindow = function(ev, ui) {
    var d = $(document);
    var scrollTop = d.scrollTop();
    if(ui.offset.top > 0 && ui.offset.top < scrollTop ) {
        d.scrollTop(ui.offset.top - 10);
    } else {
        var bottom = ui.offset.top + ui.helper.height();
        var scrollBottom = scrollTop + $(window).height();
        if(bottom > scrollBottom) {
            d.scrollTop(scrollTop + bottom - scrollBottom + 10);
        }
    }
};

/**
 * jQuery buglist item widget
 */
$.widget("agile.blitem", {
    /**
     * Default options
     */
    options: {
        bug: {},
        buglist: null,
        fields: []
    },
    /**
     * Initialize the widget
     */
    _create: function()
    {
        this._bug = new Bug(this.options.bug);
        this._bug.updated($.proxy(this, '_updateBug'));

        this.element.addClass("blitem");

        // toggle details button
        var details = this.element.find("ul.blitem-details").hide();
        this.element.find("button.blitem-expand")
            .button({ icons: {primary: "ui-icon-triangle-1-s"}, text: false })
            .click(function() {
                details.slideToggle();
                $(this).find(".ui-button-icon-primary")
                    .toggleClass('ui-icon-triangle-1-s ui-icon-triangle-1-n');
            });
        // edit button
        this.element.find("button.blitem-edit")
            .button({ icons: { primary: "ui-icon-pencil" }, text: false })
            .bugentry({ mode: 'edit', bug: this._bug });

        this._fields = {}
        for (var i = 0; i < this.options.fields.length; i++) {
            var name = this.options.fields[i];
            this._fields[name] = this.element.find(
                ":contains('{"+name+"}')").last();
        }

        this._dList = this.element.find(".blitem-dependson");
        this._dList.addClass("buglist");

        this._setBuglist(this.options.buglist);
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
            this._bug = new Bug(value);
            this._updateBug();
        }
        if (key == "buglist") {
            this._setBuglist(value);
        }
    },

    /**
     * Change the buglist where this item is connected
     */
    _setBuglist: function(buglist)
    {
        if (this.options.buglist.options.sortable) {
            this._dList.sortable({
                sort: _scrollWindow,
                items: "> :agile-blitem",
                placeholder: "blitem-placeholder",
                connectWith: buglist.options.connectWith,
                stop: $.proxy(buglist, "_onSortStop"),
                receive: $.proxy(buglist, "_onSortReceive"),
                update: $.proxy(buglist, "_onSortUpdate")
            });
        }
    },

    /**
     * Update the bug info
     */
    _updateBug:function()
    {
        var bug = this._bug;

        var classes = [
            "bz_" + bug.value('status'),
            bug.value('resolution') ? "bz_" + bug.value('resolution'): "",
            "bz_" + bug.value('priority'),
            "bz_" + bug.value('severity')
        ];
        if (!bug.value('is_open'))
            classes.push("bz_closed");
        if (bug.value('groups'))
            classes.push("bz_secure");
        this._fields['summary'].removeClass().addClass(classes.join(" "));

        for(name in this._fields) {
            this._fields[name].empty();
            var value = bug.value(name);
            if (name == 'id' || name == 'depends_on' || name == 'blocks') {
                if (!$.isArray(value))
                    value = [value];
                value = value.map(function(i) {
                    return '<a target="_blank" href="show_bug.cgi?id='+ i +'">'+ i +'</a>';
                });
            }
            if ($.isArray(value))
                value = value.join(', ');
            this._fields[name].html(value).attr('title', BB_FIELDS[name].display_name);
        }
    },

    /**
     * Add item that this item depends on to the sublist
     */
    addDepends: function(element)
    {
        var bug = element.blitem("bug");
        var place = null;
        var order = this.options.buglist.options.order;
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
});

var ListController = Base.extend(
{
    constructor: function(element)
    {
        this._element = element;
        this.list = element.find('.list-content');
        this._header = element.find('.list-header');
        this._footer = element.find('.list-footer');
        this._rpcwait = false;

        this.list.buglist();

        this._header.append($('<button type="button">Reload</button>')
            .click($.proxy(this, 'load')));
        this._header.append('Search: ')
            .append($('<input>').keyup($.proxy(this, '_search')));
    },

    destroy: function()
    {
        this.list.buglist("destroy");
    },

    /**
     * Content search field key handler
     */
    _search: function(ev)
    {
        var text = $(ev.target).val();
        this.list.buglist('search', text);
    },

    /**
     * Helper to queue RPC calls and add default error handler
     */
    callRpc: function(namespace, method, params)
    {
        var rpcObj = new Rpc(namespace, method, params, false);
        var self = this;
        rpcObj.fail(function(error) {
            alert('Error: ' + error.message);
            self._element.clearQueue('rpc');
            self._rpcwait = false;
        });
        rpcObj.done(function() {
            self._rpcwait = false;
            self._element.dequeue('rpc');
        });
        self._element.queue('rpc', function() {
            self._rpcwait = true;
            rpcObj.start()
        });
        if (!this._rpcwait) this._element.dequeue('rpc');
        return rpcObj;
    },

    _addBugs: function(bugs)
    {
        var elements = $();
        for (var i = 0; i < bugs.length; i++) {
            var element = this.list.buglist('addBug', bugs[i]);
            elements = elements.add(element);
        }
        return elements;
    },
    load: function() {
    }
});
