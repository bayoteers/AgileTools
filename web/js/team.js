/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (C) 2012 Jolla Ltd.
 * Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>
 */

var Team = Base.extend({
    constructor: function(teamData) {
        var self = this;
        this.members = {};
        this.components = {};
        this.keywords = {};
        this.id = teamData.id;
        this.responsibilities = {component:{}, keyword:{}};

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


        this.respTables = {};
        // COMPONENTS
        var $componentTable = $("#team_components tbody");
        $componentTable.find("button.add").click(
                {
                    input: $componentTable.find("select.component-new"),
                    type: "component",
                },
                $.proxy(this, "_addRespClick"));
        this.respTables["component"] = $componentTable;
        for (var i=0; i< teamData.components.length; i++) {
            var comp = teamData.components[i];
            this._insertResp("component", comp);
        }

        // KEYWORDS
        var $keywordTable = $("#team_keywords tbody");
        $keywordTable.find("button.add").click(
                {
                    input: $keywordTable.find("select.keyword-new"),
                    type: "keyword",
                },
                $.proxy(this, "_addRespClick"));
        this.respTables["keyword"] = $keywordTable;
        for (var i=0; i< teamData.keywords.length; i++) {
            var keyw = teamData.keywords[i];
            this._insertResp("keyword", keyw);
        }

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

    _insertResp: function(type, item)
    {
        this.responsibilities[type][item.id] = item;
        var $row = $("#responsibility_template").clone().attr("id", null);
        $row.data("itemId", item.id);
        $row.find(".name").text(item.name);
        $row.find("button.remove")
            .button({
                icons:{primary:"ui-icon-circle-minus"},
                text: false,
            }).click({
                itemId: item.id,
                type: type,
                }, $.proxy(this, "_removeRespClick"));

        this.respTables[type].find("tr").last().before($row);
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

    _addRespClick: function(event)
    {
        this.team_rpc("add_responsibility", {
                    id: this.id,
                    type: event.data.type,
                    item_id: event.data.input.val()})
            .done($.proxy(this, "_addRespDone"));
    },

    _addRespDone: function(result)
    {
        var type = result.type;
        for (var i=0; i < result.items.length; i++) {
            var item = result.items[i];
            if (this.responsibilities[type][item.id] == undefined) {
                this._insertResp(type, item);
            }
        }

    },
    _removeRespClick: function(event)
    {
        this.team_rpc("remove_responsibility",
                {
                    id: this.id,
                    type: event.data.type,
                    item_id: event.data.itemId,
                }
            ).done($.proxy(this, "_removeRespDone"));
    },
    _removeRespDone: function(result)
    {
        var type = result.type;
        var ids = [];
        for (var i=0; i < result.items.length; i++) {
            ids.push(result.items[i].id);
        }
        var team = this;
        this.respTables[type].children("tr").not(".editor").each(function() {
            var $row = $(this);
            var id = $row.data("itemId");
            if(id && ids.indexOf(id) == -1) {
                $row.remove();
                delete team.responsibilities[type][id];
            }
        });
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
});
