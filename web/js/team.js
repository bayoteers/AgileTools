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

        // MEMBERS
        var $memberTable = $("#teamMembers tbody");
        $memberTable.find("button.add").click(
                {input: $memberTable.find("input.newMember")},
                $.proxy(this, "_addMemberClick"));

        for (var i=0; i< teamData.members.length; i++) {
            var member = teamData.members[i];

            this.members[member.userid] = member;
            var $row = cloneTemplate("#memberTemplate");
            $row.data("memberId", member.userid);
            $row.find(".name").text(member.realname);
            $row.find("button.remove").click(
                        {memberId: member.userid},
                        $.proxy(this, "_removeMemberClick"));

            // MEMBER ROLES
            var $roles = $row.find(".roles");
            var $newRole = $roles.find("input.newRole");
            $roles.find("button.add").click(
                    {memberId: member.userid, input: $newRole},
                    $.proxy(this, "_addRoleClick"));
            member.roles = {};
            for (var j=0; j < teamData.roles[member.userid].length; j++) {
                var role = teamData.roles[member.userid][j];
                member.roles[role.id] = role;
                var $roleRow = cloneTemplate("#roleTemplate");
                $roleRow.find(".name").text(role.name);
                $roleRow.data("roleId", role.id);
                $roleRow.find("button.remove").click(
                        {memberId: member.userid, roleId: role.id},
                        $.proxy(this, "_removeRoleClick"));
                $roles.prepend($roleRow);
            }
            $memberTable.prepend($row);
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

    _addMemberClick: function(event)
    {
        alert("add member " + event.data.input.val());
    },
    _removeMemberClick: function(event)
    {
        alert("remove member " + event.data.memberId);
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
