# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the AgileTools Bugzilla Extension.
#
# The Initial Developer of the Original Code is Pami Ketolainen
# Portions created by the Initial Developer are Copyright (C) 2012 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Pami Ketolainen <pami.ketolainen@gmail.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Team

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools::Team

    my $team = new Bugzilla::Extension::AgileTools::Team(1);

    my $team_id = $team->id;
    my $name = $team->name;
    my $group = $team->group;
    my $group_id = $team->group_id;
    my $process_id = $team->process_id;

    my @members = @{$team->memebers};
    $team->add_member("john.doe@example.com");
    $team->add_member($user_id);
    my $member = Bugzilla::User->check("john.doe@example.com");
    $team->remove_member($member);
    $team->remove_member($user_id);

    my @component_resposibilities = @{$team->components};
    my @keyword_resposibilities = @{$team->keywords};

    $team->add_responsibility("component", $component_id);
    $team->remove_responsibility("keyword", $keyword_id);

    my $user = new Bugzilla::User(1);
    my @teams = @{$user->agile_teams};

=head1 DESCRIPTION

Team.pm presents a AgileTools Team object inherited from L<Bugzilla::Object>
and has all the same methods, plus the ones described below.

=cut

use strict;
use warnings;
package Bugzilla::Extension::AgileTools::Team;

use base qw(Bugzilla::Object);

use Bugzilla::Extension::AgileTools::Util qw(get_user);
use Bugzilla::Extension::AgileTools::Constants;

use Bugzilla::Constants;
use Bugzilla::Group;
use Bugzilla::User;
use Bugzilla::Error;
use Bugzilla::Util qw(trim trick_taint detaint_natural);

use Scalar::Util qw(blessed);
use List::Util qw(first);

use constant DB_TABLE => 'agile_teams';

use constant DB_COLUMNS => qw(
    id
    name
    group_id
    process_id
);

use constant NUMERIC_COLUMNS => qw(
    group_id
    process_id
);

use constant UPDATE_COLUMNS => qw(
    name
    process_id
);

use constant VALIDATORS => {
    name => \&_check_name,
    process_id => \&_check_process_id,
};

# Allowed team responsibility types an corresponding classes
use constant _RESP_CLASS => {
    component => "Bugzilla::Component",
    keyword => "Bugzilla::Keyword",
};

# Accessors
###########

sub group_id   { return $_[0]->{group_id}; }
sub process_id { return $_[0]->{process_id}; }

sub group {
    my $self = shift;
    $self->{group} ||= Bugzilla::Group->new($self->group_id);
    return $self->{group};
}

# Mutators
##########

sub set_name       { $_[0]->set('name', $_[1]); }
sub set_process_id { $_[0]->set('process_id', $_[1]); }

# Validators
############

sub _check_name {
    my ($invocant, $name) = @_;
    $name = trim($name);
    $name || ThrowUserError("agile_empty_name");

    # If we're creating a Team or changing the name...
    if (!ref($invocant) || lc($invocant->name) ne lc($name)) {
        ThrowUserError("agile_team_exists", { name => $name })
            if defined Bugzilla::Extension::AgileTools::Team->new({name => $name});

        # Check that there is no group with that name...
        ThrowUserError("group_exists", { name => "team ".$name })
            if defined Bugzilla::Group->new({name => "team ".$name})
    }
    return $name;
}

sub _check_process_id {
    my ($invocant, $id) = @_;
    if (!defined AGILE_PROCESS_NAMES->{$id}) {
        ThrowUserError("agile_unkown_process", { id => $id });
    }
    return $id;
}


=head1 METHODS

=head2 For managing team members

=over

=item C<members>

    Description: Gets the list of team members.
    Returns:     Array ref of L<Bugzilla::User> objects.

=cut

sub members {
    my $self = shift;
    return [] unless $self->id;
    if (!defined $self->{members}) {
        $self->{members} = $self->group->members_non_inherited();
    }
    return $self->{members};
}

=item C<add_member($user)>

    Description: Adds a new member to the team.
    Params:      $user - User object, name or id

=cut

sub add_member {
    my ($self, $member) = @_;
    $member = get_user($member);

    return if defined  first { $_->id == $self->id } @{$member->agile_teams};

    my $dbh = Bugzilla->dbh;
    $dbh->do("INSERT INTO user_group_map (
        user_id, group_id, isbless, grant_type
        ) VALUES (?, ?, ?, ?)", undef,
        ($member->id, $self->group->id, 0, GRANT_DIRECT));
}

=item C<remove_member($user)>

    Description: Removes a new member from the team.
    Params:      $user - User object, name or id

=cut

sub remove_member {
    my ($self, $member) = @_;
    $member = get_user($member);

    return if !defined first {$_->id == $self->id} @{$member->agile_teams};

    my $dbh = Bugzilla->dbh;
    $dbh->do("DELETE FROM user_group_map
        WHERE user_id = ? AND group_id = ? AND grant_type = ?", undef,
        ($member->id, $self->group->id, GRANT_DIRECT));

    # Remove user roles
    my $roles = Bugzilla::Extension::AgileTools::Role->get_user_roles(
        $self, $member);
    for my $role (@{$roles}) {
        $role->remove_user_role($self, $member);
    }
}

=item C<roles>

    Description: Get all team members roles
    Returns:     Hash ref where keys are userids and values are array refs of
                 L<Bugzilla::Extension::AgileTools::Role> objects

=cut

sub roles {
    my ($self) = @_;
    if (!defined $self->{roles}) {
        $self->{roles} = {};
        foreach my $member (@{$self->members}) {
            $self->{roles}->{$member->id} = $member->agile_team_roles($self);
        }
    }
    return $self->{roles};
}

=back

=head2 For managing team responsibilities

=over

=cut

=item C<components>

    Description: Shorthand for C<Team::responsibilities>
    Returns:     Array ref of L<Bugzilla::Component> objects

=cut

sub components {
    return $_[0]->responsibilities("component");
}

=item C<keywords>

    Description: Shorthand for C<Team::responsibilities>
    Returns:     Array ref of L<Bugzilla::Keyword> objects

=cut

sub keywords {
    return $_[0]->responsibilities("keyword");
}

=item C<responsibilities($type)>

    Description: Gets the list of responsibilities the team has
    Params:      $type - Responsibility type, 'component' or 'keyword'
    Returns:     Array ref of requested type responsibility objects

=cut

sub responsibilities {
    my ($self, $type) = @_;
    return [] unless $self->id;
    my $item_class = $self->_RESP_CLASS->{$type};
    ThrowUserError("agile_bad_responsibility_type", {type => $type} )
        unless defined $item_class;
    trick_taint($type);
    my $cache = $type."s";
    my $table = "agile_team_".$type."_map";

    if (!defined $self->{$cache}) {
        my $dbh = Bugzilla->dbh;
        my $item_ids = $dbh->selectcol_arrayref(
            "SELECT ".$type."_id FROM ".$table."
             WHERE team_id = ?", undef, $self->id);

        $self->{$cache} = $item_class->new_from_list($item_ids);
    }
    return $self->{$cache};
}

=item C<add_responsibility($type, $item)>

    Description: Adds new component into team responsibilities.
    Params:      $type - 'component' or 'keyword'
                 $item - Object or id to add.
    Returns:     Number of Objecs added
    Notes:       Throws an error if object with given id does not exist.

=cut

sub add_responsibility {
    my ($self, $type, $item) = @_;

    my $item_class = $self->_RESP_CLASS->{$type};
    ThrowUserError("agile_bad_responsibility_type", {type => $type} )
        unless defined $item_class;
    trick_taint($type);

    if (!blessed $item) {
        if ($item =~ /^\d+$/) {
            $item = $item_class->check({id => $item});
        } else {
            ThrowCodeError("bad_arg", { argument => $item,
                    function => "Team::add_responsibility" });
        }
    }

    my $cache = $type."s";
    my $table = "agile_team_".$type."_map";
    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();

    # Check that item is not already included
    my $included = $dbh->selectrow_array(
        "SELECT 1 FROM ".$table."
          WHERE team_id = ? AND ".$type."_id = ?",
        undef, ($self->id, $item->id));
    my $rows = 0;
    if (!$included) {
        $rows = $dbh->do("INSERT INTO ".$table."
            (team_id, ".$type."_id) VALUES (?, ?)",
            undef, ($self->id, $item->id));

        # Push the new item in cache if cache has been fetched
        push(@{$self->{$cache}}, $item)
                if defined $self->{$cache};
    }
    $dbh->bz_commit_transaction();
    return $rows;
}

=item C<remove_responsibility($type, $item)>

    Description: Removes component from team responsibilities
    Params:      $type - 'component' or 'keyword'
                 $item - Object or id to remove.
    Returns:     Number of objects removed.

=cut

sub remove_responsibility {
    my ($self, $type, $item) = @_;
    ThrowUserError("agile_bad_responsibility_type", {type => $type} )
        unless defined $self->_RESP_CLASS->{$type};
    trick_taint($type);

    my $item_id;
    if (blessed $item) {
        $item_id = $item->id;
    } elsif ($item =~ /^\d+$/) {
        $item_id = $item;
    } else {
        ThrowCodeError("bad_arg", { argument => $item,
                function => "Team::remove_responsibility" });
    }
    ThrowCodeError("bad_arg", { argument => $item,
                function => "Team::remove_responsibility" })
        unless detaint_natural($item_id);

    my $cache = $type."s";
    my $table = "agile_team_".$type."_map";
    my $dbh = Bugzilla->dbh;

    my $rows = $dbh->do(
        "DELETE FROM ".$table."
               WHERE team_id = ? AND ".$type."_id = ?",
               undef, ($self->id, $item_id));

    if ($rows && defined $self->{$cache}) {
        my @items;
        foreach my $obj (@{$self->{$cache}}) {
            next if ($obj->id == $item_id);
            push(@items, $obj);
        }
        $self->{$cache} = \@items;
    }
    return $rows;
}

=back

=head2 For user permissions

=over

=item C<user_can_edit($user)>

    Description: Tests if user is allowed to edit the team.
    Params:      $user - (optional) C<User> object. Current logged in user is used
                         if not given.
    Returns:     1 if user is allowed to edit the team, 0 otherwise.

=cut

sub user_can_edit {
    my ($self, $user) = @_;
    $user ||= Bugzilla->user;
    return 0 unless defined $user;

    $user = get_user($user);
    $self->{user_can_edit} = {} unless defined $self->{user_can_edit};

    if (!defined $self->{user_can_edit}->{$user->id}) {
        my $can_edit = 0;
        if ($user->in_group("admin")) {
            $can_edit = 1;
        } else {
            my $roles = Bugzilla::Extension::AgileTools::Role->get_user_roles(
                    $self, $user);
            foreach my $role (@{$roles}) {
                if ($role->can_edit_team) {
                    $can_edit = 1;
                }
            }
        }
        $self->{user_can_edit}->{$user->id} = $can_edit;
    }
    return $self->{user_can_edit}->{$user->id};
}

# Overridden Bugzilla::Object methods
#####################################

sub update {
    my $self = shift;

    my($changes, $old) = $self->SUPER::update(@_);

    if ($changes->{name}) {
        # Reflect the name change on the group
        my $new_name = "team ".$changes->{name}->[1];
        $self->group->set_all({
                name => $new_name,
                description => "'" . $new_name . "' team member group",
            }
        );
        $self->group->update();
    }

    if (wantarray) {
        return ($changes, $old);
    }
    return $changes;
}

sub create {
    my ($class, $params) = @_;

    $class->check_required_create_fields($params);
    my $clean_params = $class->run_create_validators($params);

    # Greate the group and put ID in params
    my $group = Bugzilla::Group->create({
            name => "team ".$params->{name},
            description => "'" . $params->{name} . "' team member group",
            # isbuggroup = 0 means system group
            isbuggroup => 0,
        }
    );
    $clean_params->{group_id} = $group->id;

    return $class->insert_create_data($clean_params);
}

sub remove_from_db {
    my $self = shift;
    my $group = $self->group;
    
    $self->SUPER::remove_from_db(@_);

    # Remove users from the group and change the group to non system group
    # before deleting, so that if it fails, the group can be manually removed
    # in the admin interface.
    my $dbh = Bugzilla->dbh;
    $dbh->do("DELETE FROM user_group_map
        WHERE group_id = ?", undef, $group->id);
    $dbh->do("UPDATE groups
                 SET isbuggroup = 1
               WHERE id = ?", undef, $group->id);
    $group->{isbuggroup} = 1;
    $group->remove_from_db();
}

=back

=head1 RELATED METHODS

=head2 Bugzilla::User object methods

The L<Bugzilla::User> object is also extended to provide easy access to teams
where particular user is a member.

    my $teams = Bugzilla->user->agile_teams;

=over

=item C<Bugzilla::User::agile_teams>

    Description: Returns the list of teams the user is member in.
    Returns:     Array ref of C<Bugzilla::Extension::AgileTools::Team> objects.

=cut

BEGIN {
    *Bugzilla::User::agile_teams = sub {
        my $self = shift;
        return $self->{agile_teams} if defined $self->{agile_teams};

        my @group_ids = map { $_->id } @{$self->direct_group_membership};
        my $team_ids = Bugzilla->dbh->selectcol_arrayref("
            SELECT id FROM agile_teams
             WHERE group_id IN (". join(",", @group_ids) .")");
        $self->{agile_teams} = Bugzilla::Extension::AgileTools::Team->
                new_from_list($team_ids);
        return $self->{agile_teams};
    };
}

1;

__END__

=back

=head1 NOTES

None of the methods check if user is allowed to modify the teams. This should be
done by higher level controller methods using this as only a interface to the
stored data.

=head1 SEE ALSO

L<Bugzilla::Object>
