var cloneTemplate = function(selector) {
    var $element = $(selector).clone();
    $element.attr("id", null);
    return $element;
};

var Team = Base.extend({
    constructor: function(teamData) {
        this.members = {};
        this.components = {};
        this.keywords = {};
        this.id = teamData.id;

        // MEMBERS
        this.memberTable = $("#teamMembers tbody");
        this.memberTable.find("button.add").click(
                {input: this.memberTable.find("input.newMember")},
                $.proxy(this, "_addMemberClick"));

        for (var i=0; i< teamData.members.length; i++) {
            var member = teamData.members[i];
            var $row = this._insertMember(member);

            // MEMBER ROLES
            var $roles = $row.find(".roles");
            var $newRole = $roles.find("input.newRole");
            $roles.find("button.add").click(
                    {memberId: member.userid, input: $newRole},
                    $.proxy(this, "_addRoleClick"));
            for (var j=0; j < teamData.roles[member.userid].length; j++) {
                var role = teamData.roles[member.userid][j];
                member.roles[role.id] = role;
                var $roleRow = cloneTemplate("#roleTemplate");
                $roleRow.find(".name").text(role.name);
                $roleRow.data("roleId", role.id);
                $roleRow.find("button.remove").click(
                        {memberId: member.userid, roleId: role.id},
                        $.proxy(this, "_removeRoleClick"));
                $roles.find("tr").last().before($roleRow);
            }
        }

        // COMPONENTS
        var $componentTable = $("#teamComponents tbody");
        $componentTable.find("button.add").click(
                {input: $componentTable.find("input.newComponent")},
                $.proxy(this, "_addComponentClick"));
        for (var i=0; i< teamData.components.length; i++) {
            var comp = teamData.components[i];
            this.components[comp.id] = comp;
            var $row = cloneTemplate("#responsibilityTemplate");
            $row.data("componentId", comp.id);
            $row.find(".name").text(comp.name);
            $row.find("button.remove").click(
                        {componentId: comp.id},
                        $.proxy(this, "_removeComponentClick"));
            $componentTable.prepend($row);

        }

        // KEYWORDS
        var $keywordTable = $("#teamKeywords tbody");
        $keywordTable.find("button.add").click(
                {input: $keywordTable.find("input.newKeyword")},
                $.proxy(this, "_addKeywordClick"));
        for (var i=0; i< teamData.keywords.length; i++) {
            var keyw = teamData.keywords[i];
            this.keywords[keyw.id] = keyw;
            var $row = cloneTemplate("#responsibilityTemplate");
            $row.data("keywordId", keyw.id);
            $row.find(".name").text(keyw.name);
            $row.find("button.remove").click(
                        {keywordId: keyw.id},
                        $.proxy(this, "_removeKeywordClick"));
            $keywordTable.prepend($row);
        }

        $("input.newMember").userautocomplete();
        $("button.add").button({
            icons:{primary:"ui-icon-circle-plus"},
            text: false,
        });
        $("button.remove").button({
            icons:{primary:"ui-icon-circle-minus"},
            text: false,
        });
        $("button").not(".add,.remove").button();
    },

    _insertMember: function(member)
    {
        member.roles = {};
        this.members[member.userid] = member;
        var $row = cloneTemplate("#memberTemplate");
        $row.data("memberId", member.userid);
        $row.find(".name").text(member.realname);
        $row.find("button.remove").click(
                    {memberId: member.userid},
                    $.proxy(this, "_removeMemberClick"));
        this.memberTable.find("tr").last().before($row);
        return $row;
    },

    rpc: function(method, params)
    {
        var rpc = new Rpc("Agile.Team", method, params);
        rpc.fail(function(error) {alert(method + " failed: " + error.message);});
        return rpc;
    },

    _addMemberClick: function(event)
    {
        this.rpc("add_member", {
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
        this.memberTable.find("input.newMember").val("");
    },

    _removeMemberClick: function(event)
    {
        this.rpc("remove_member", {
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
        alert("add role " + event.data.input.val() + " for "
                + event.data.memberId);
    },
    _removeRoleClick: function(event)
    {
        alert("remove role " + event.data.roleId + " from "
                + event.data.memberId);
    },
    _addComponentClick: function(event)
    {
        alert("add component " + event.data.input.val());
    },
    _removeComponentClick: function(event)
    {
        alert("remove component " + event.data.componentId);
    },
    _addKeywordClick: function(event)
    {
        alert("add keyword " + event.data.input.val());
    },
    _removeKeywordClick: function(event)
    {
        alert("remove keyword " + event.data.keywordId);
    },
});
