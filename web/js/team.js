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
            var $newRole = $roles.find("select.newRole");
            $roles.find("button.add").click(
                    {memberId: member.userid, input: $newRole},
                    $.proxy(this, "_addRoleClick"));

            for (var j=0; j < teamData.roles[member.userid].length; j++) {
                var role = teamData.roles[member.userid][j];
                this._insertRole(member, role);
            }
        }

        // COMPONENTS
        var $componentTable = $("#teamComponents tbody");
        $componentTable.find("button.add").click(
                {input: $componentTable.find("select.newComponent")},
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
                {input: $keywordTable.find("select.newKeyword")},
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
        member.row = $row;
        $row.data("memberId", member.userid);
        $row.find(".name").text(member.realname);
        $row.find("button.remove").click(
                    {memberId: member.userid},
                    $.proxy(this, "_removeMemberClick"));
        this.memberTable.find("tr").last().before($row);
        return $row;
    },

    _insertRole: function(member, role)
    {
        member.roles[role.id] = role;
        var $roleRow = cloneTemplate("#roleTemplate");
        $roleRow.find(".name").text(role.name);
        $roleRow.data("roleId", role.id);
        $roleRow.find("button.remove").click(
                {memberId: member.userid, roleId: role.id},
                $.proxy(this, "_removeRoleClick"));
        member.row.find(".roles").find("tr").last().before($roleRow);
        return $roleRow;
    },

    rpc: function(method, params)
    {
        var rpc = new Rpc("Agile.Team", method, params);
        rpc.fail(function(error) {alert("Operation failed: " + (error.message ||
                        "Probably internal error.."));});
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
        this.rpc("add_member_role", {
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
        this.rpc("remove_member_role", {
                    id: this.id, user: event.data.memberId,
                    role: event.data.roleId})
            .done($.proxy(this, "_removeMemberRoleDone"));
    },
    _removeMemberRoleDone: function(result)
    {
        if (!result.role) return;
        var member = this.members[result.userid];
        member.row.find(".roles tr").each(function() {
            var $row = $(this);
            if ($row.data("roleId") == result.role.id) {
                $row.remove();
            }
        });
        delete member.roles[result.role.id];
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
