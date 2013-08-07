/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (C) 2012-2013 Jolla Ltd.
 * Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>
 */

/**
 * Confirmation support to colorbox.close()
 *
 * Adds new configuration option to colorbox
 *
 *      onCloseConfirm: callback
 *
 * Where callback is a function which should return true if it is ok to close
 * the box.
 */
$.colorbox.originalClose = $.colorbox.close;
$.colorbox.close = function() {
    element = $.colorbox.element();
    var confirmClose = element.data().colorbox.onCloseConfirm;
    if (typeof confirmClose != "function") {
        $.colorbox.originalClose();
    } else {
        if (confirmClose() == true) $.colorbox.originalClose();
    }
}

var Team = Base.extend({
    constructor: function(teamData) {
        var self = this;
        this.members = {};
        this.id = teamData.id;
        this.responsibility_query = teamData.responsibility_query;

        // MEMBERS
        this.memberTable = $("#team_members tbody");
        this.memberTable.find("button.add").click(
                {
                    input: this.memberTable.find("input.member-new"),
                },
                $.proxy(this, "_addMemberClick"));

        for (var i=0; i< teamData.members.length; i++) {
            var member = teamData.members[i];
            var $row = this._insertMember(member);

            // MEMBER ROLES
            for (var j=0; j < teamData.roles[member.userid].length; j++) {
                var role = teamData.roles[member.userid][j];
                this._insertRole(member, role);
            }
        }

        // BACKLOGS
        this.backlogList = $("ul#backlog_list_"+this.id);
        this.backlogList.find("li").each(function() {
            var $item = $(this);
            var $button = $("<button>")
                .attr("type", "button")
                .attr("value", $item.attr("id"))
                .addClass("remove editor")
                .text("Detach backlog");
            $item.append($button);
            $button.button({
                icons:{primary:"ui-icon-circle-minus"},
                text: false,
            }).click($.proxy(self, "_detachBacklog"));
        });
        $("button#add_new_backlog").button({
                icons:{primary:"ui-icon-circle-plus"},
                text: false,
            }).click($.proxy(this, "_createBacklog"));
        $("button#add_existing_backlog").button({
                icons:{primary:"ui-icon-circle-plus"},
                text: false,
            }).click($.proxy(this, "_attachBacklog"));

        // UNPRIORITIZED ITEMS
        var editQueryButton = $("<button>")
            .attr('type', 'button')
            .addClass("add editor")
            .text('Edit query');
        $("li#unprioritized_items_"+this.id).append(editQueryButton);
        editQueryButton.button({
                icons:{primary:"ui-icon-pencil"},
                text: false,
            }).click($.proxy(this, "_openQueryEdit"));

        $("input.member-new").userautocomplete();
        $("table").not("#templates").find("button.add").button({
            icons:{primary:"ui-icon-circle-plus"},
            text: false,
        });
        $("button").not(".add,.remove").button();
    },

    _insertMember: function(member)
    {
        member.roles = {};
        this.members[member.userid] = member;
        var $row = $("#member_template").clone().attr("id", null);
        member.row = $row;
        $row.data("memberId", member.userid);
        $row.find(".name").text(member.realname);
        $row.find("button.remove")
            .button({
                icons:{primary:"ui-icon-circle-minus"},
                text: false,})
            .click({
                memberId: member.userid},
                $.proxy(this, "_removeMemberClick"));
            
        var $roles = $row.find(".roles");
        $roles.find("button.add")
            .button({
                icons:{primary:"ui-icon-circle-plus"},
                text: false,})
            .click({
                memberId: member.userid,
                input: $roles.find("select.role-new"),
                }, $.proxy(this, "_addRoleClick"));

        this.memberTable.find("tr").last().before($row);
        return $row;
    },

    _insertRole: function(member, role)
    {
        member.roles[role.id] = role;
        var $roleRow = $("#role_template").clone().attr("id", null);
        $roleRow.find(".name").text(role.name);
        $roleRow.data("roleId", role.id);
        $roleRow.find("button.remove")
            .button({
                icons:{primary:"ui-icon-circle-minus"},
                text: false,
            }).click({
                memberId: member.userid,
                roleId: role.id
                }, $.proxy(this, "_removeRoleClick"));
        member.row.find(".roles").find("li").last().before($roleRow);
        return $roleRow;
    },

    team_rpc: function(method, params)
    {
        var rpc = new Rpc("Agile.Team", method, params);
        rpc.fail(function(error) {alert("Operation failed: " + (error.message ||
                        "Probably internal error.."));});
        return rpc;
    },
    backlog_rpc: function(method, params)
    {
        var rpc = new Rpc("Agile.Backlog", method, params);
        rpc.fail(function(error) {alert("Operation failed: " + (error.message ||
                        "Probably internal error.."));});
        return rpc;
    },

    _addMemberClick: function(event)
    {
        this.team_rpc("add_member", {
                    id: this.id, user: event.data.input.val()})
            .done($.proxy(this, "_addMemberDone"));
    },

    _addMemberDone: function(result) {
        for (var i=0; i < result.length; i++) {
            var member = result[i];
            if (this.members[member.userid] == undefined) {
                this._insertMember(member);
            }
        }
        this.memberTable.find("input.member-new").val("");
    },

    _removeMemberClick: function(event)
    {
        this.team_rpc("remove_member", {
                    id: this.id, user: event.data.memberId})
            .done($.proxy(this, "_removeMemberDone"));

    },

    _removeMemberDone: function(result)
    {
        var ids = [];
        for (var i=0; i < result.length; i++) {
            ids.push(result[i].userid);
        }
        var team = this;
        this.memberTable.children("tr").not(".editor").each(function() {
            var $row = $(this);
            var id = $row.data("memberId");
            if(id && ids.indexOf(id) == -1) {
                $row.remove();
                delete team.members[id];
            }
        });
    },

    _addRoleClick: function(event)
    {
        this.team_rpc("add_member_role", {
                    id: this.id, user: event.data.memberId,
                    role: event.data.input.val()})
            .done($.proxy(this, "_addMemberRoleDone"));
    },
    _addMemberRoleDone: function(result)
    {
        if (!result.role) return;
        var member = this.members[result.userid];
        this._insertRole(member, result.role)
    },

    _removeRoleClick: function(event)
    {
        this.team_rpc("remove_member_role", {
                    id: this.id, user: event.data.memberId,
                    role: event.data.roleId})
            .done($.proxy(this, "_removeMemberRoleDone"));
    },
    _removeMemberRoleDone: function(result)
    {
        if (!result.role) return;
        var member = this.members[result.userid];
        member.row.find(".roles li").each(function() {
            var $row = $(this);
            if ($row.data("roleId") == result.role.id) {
                $row.remove();
            }
        });
        delete member.roles[result.role.id];
    },

    _attachBacklog: function(event) {
        var id = $("select#existing_backlog").val();
        var element = $("select#existing_backlog :selected");
        var that = this;
        this.backlog_rpc("update", {id: id, team_id: this.id})
            .done(function(result) {
                element.remove();
                that.backlogList.append("<li>"+result.backlog.name+
                                " (pool ID "+result.backlog.pool_id +")</li>");
            });

    },
    _detachBacklog: function(event) {
        var element_id = $(event.currentTarget).val();
        var element = this.backlogList.find("#"+element_id);
        var id = element_id.split('_')[1];
        this.backlog_rpc("update", {id: id, team_id: null})
            .done(function(result) {
                var option = $("<option>")
                    .attr("value", result.backlog.pool_id)
                    .text(result.backlog.name);
                $("select#existing_backlog").append(option);
                element.remove();
            });
    },
    _createBacklog: function(event) {
        var name = $("input#new_backlog").val();
        var that = this;
        this.backlog_rpc("create", {name: name, team_id: this.id})
            .done(function(result){
                that.backlogList.append(
                    "<li>"+result.name+
                    " (pool ID "+result.pool_id +")</li>");
                $("input#new_backlog").val("");
            });
    },

    /**
     * Opens the responsibility query editor
     */
    _openQueryEdit: function()
    {
        $.colorbox({
                width: "90%",
                height: "90%",
                iframe: true,
                fastIframe: false,
                href: "query.cgi" + this.responsibility_query,
                onCloseConfirm: $.proxy(this, "_confirmQueryClose"),
                onCleanup: $.proxy(this, "_getSearchQuery"),
                onComplete: $.proxy(this, "_onEditBoxReady")
        })
    },
    /**
     * Hide unneeded elements from the page in edit box and disable some
     * controls from the search form
     */
    _onEditBoxReady: function()
    {
        $("#cboxContent iframe").load(function(event){
            var contents = $(event.target).contents();
            contents.find("div#header").hide();
            contents.find("div#footer").hide();
            if (!contents[0].location.pathname.match("query.cgi")) return;

            // Disable the preset condition controls
            var cover = $("<div>").css({
                    position: 'absolute',
                    top: 0, left: 0,
                    width: '100%', height: '100%',
                    color: '#000000',
                    background: '#ffffff',
                    opacity: 0.8,
                    'z-index': 10000
                });
            contents.find("div#container_resolution").append(
                cover.clone().attr('title', 'Resolution is forced to ---'))
                .css('position', 'relative');
            cover.attr('title', 'This is required condition');
            contents.find(".custom_search_condition").first().append(cover)
                .css('position', 'relative');
        });
    },
    /**
     * Get the query string from buglist page open in edit box
     */
    _getSearchQuery: function()
    {
        try {
            var loc = $("#cboxContent iframe").contents()[0].location;
            if (loc.pathname.match("buglist.cgi")) {
                // Remove the ? from beginning
                var query = loc.search.substring(1);
                this.team_rpc('update', {id: this.id,
                        responsibility_query: query}
                ).done($.proxy(this, "_queryUpdated"))
            }
        } catch(e) {
            if (window.console) console.error(e);
            alert("Failed to get the query string");
        }
    },
    /**
     * Updates the responsibility query if it changed
     */
    _queryUpdated: function(changes)
    {
        if(changes.responsibility_query != undefined) {
            this.responsibility_query = changes.responsibility_query[1];
            $("li#unprioritized_items_" + this.id + " a")
                .attr('href', 'buglist.cgi' + this.responsibility_query);
        }
    },

    /**
     * Confirm that query edit box is on buglist page before closing
     */
    _confirmQueryClose: function()
    {
        var path = "";
        try {
            path = $("#cboxContent iframe").contents()[0].location.pathname;
        } catch(e) {
            if (window.console) console.error(e);
            return true;
        }
        if (path.match("buglist.cgi") == null) {
            return confirm(
                "After entering the search parameters, "
                + "you need to click 'search' to open "
                + "the buglist before closing. "
                + "Do you really want to close?");
        } else {
            return true;
        }
    },
});
