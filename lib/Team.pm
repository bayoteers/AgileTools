# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Team - Bugzilla Object class presenting a team

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

Object inherited from L<Bugzilla::Object>.

=cut

use strict;
use warnings;
package Bugzilla::Extension::AgileTools::Team;

use base qw(Bugzilla::Object);

use Bugzilla::Extension::AgileTools::Backlog;
use Bugzilla::Extension::AgileTools::Constants;
use Bugzilla::Extension::AgileTools::Sprint;
use Bugzilla::Extension::AgileTools::Util qw(get_user);

use Bugzilla::Constants;
use Bugzilla::Group;
use Bugzilla::User;
use Bugzilla::Error;
use Bugzilla::Util qw(trim trick_taint detaint_natural);

use DateTime;
use Scalar::Util qw(blessed);
use List::Util qw(first);

use constant DB_TABLE => 'agile_team';

=head1 FIELDS

=over

=item C<name> (mutable) - Name of the team

=item C<group_id> - ID of the group associated with the team

=item C<process_id> (mutable) - ID of the development process the team uses.
        See: L<extensions::AgileTools::lib::Constants/Process types>

=itme C<current_sprint_id> - ID of the sprint/pool containing the teams current
        sprint.

=back

=cut

use constant DB_COLUMNS => qw(
    id
    name
    group_id
    process_id
    current_sprint_id
);

use constant NUMERIC_COLUMNS => qw(
    group_id
    process_id
    current_sprint_id
);

use constant UPDATE_COLUMNS => qw(
    name
    process_id
    current_sprint_id
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

=head1 METHODS

=head2 Accessors

For all L</FIELDS> there is $object->fieldname method

Additionally there are accessors for

=cut

sub group_id   { return $_[0]->{group_id}; }
sub process_id { return $_[0]->{process_id}; }
sub current_sprint_id { return $_[0]->{current_sprint_id}; }

=item C<group> - Get the L<Bugzilla::Group> object matching team->group_id

=cut

sub group {
    my $self = shift;
    $self->{group} ||= Bugzilla::Group->new($self->group_id);
    return $self->{group};
}

=item C<backlogs> - Arrayref of Backlog objects linked to this team

=cut

sub backlogs {
    my $self = shift;
    $self->{backlogs} ||= Bugzilla::Extension::AgileTools::Backlog->match(
            {team_id => $self->id});
    return $self->{backlogs};
}

=back

=head2 Mutators

For all mutable L</FIELDS> there is $object->set_fieldname($value) method

=cut

sub set_name       { $_[0]->set('name', $_[1]); }
sub set_process_id { $_[0]->set('process_id', $_[1]); }
sub set_current_sprint_id { $_[0]->set('current_sprint_id', $_[1]); }

# Validators
############

sub _check_name {
    my ($invocant, $name) = @_;
    $name = trim($name);
    $name || ThrowUserError("agile_missing_field", {field=>'name'});

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

    ThrowUserError("agile_unkown_process", { id => $id })
        unless ($id =~ /\d*/);

    ThrowUserError("agile_unkown_process", { id => $id })
        unless defined AGILE_PROCESS_NAMES->{$id};

    return $id;
}

=head2 For managing team members

=head3 members

Returns array ref of L<Bugzilla::User> objects containing all team members.

=cut

sub members {
    my $self = shift;
    return [] unless $self->id;
    if (!defined $self->{members}) {
        $self->{members} = $self->group->members_non_inherited();
    }
    return $self->{members};
}

=head3 add_member

Adds a new member to the team.

    add_memeber($user)

=over

=item C<$user> User object, name or id

=back

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


=head3 remove_member

Removes a member from the team.

    remove_member($user)

=over

=item C<$user> User object, name or id

=back

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


=head3 roles

Returns hash ref where keys are user IDs and values are array refs of
L<Role|extensions::AgileTools::lib::Role> objects for all team members.

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


=head2 For managing team responsibilities

=head3 components

Shorthand of L</responsibilities> for components

=cut

sub components {
    return $_[0]->responsibilities("component");
}


=head keywords

Shorthand of L</responsibilities> for keywords

=cut

sub keywords {
    return $_[0]->responsibilities("keyword");
}

=head3 responsibilities

Returns array ref of requested type responsibility objects that team has been
assigned.

    responsibilities($type)

=over

=item C<$type> Responsibility type, 'component' or 'keyword'

=back

=cut

sub responsibilities {
    my ($self, $type) = @_;
    return [] unless $self->id;
    my $item_class = $self->_RESP_CLASS->{$type};
    ThrowUserError("agile_bad_responsibility_type", {type => $type} )
        unless defined $item_class;
    trick_taint($type);
    my $cache = $type."s";
    my $table = "agile_team_".$type;

    if (!defined $self->{$cache}) {
        my $dbh = Bugzilla->dbh;
        my $item_ids = $dbh->selectcol_arrayref(
            "SELECT ".$type."_id FROM ".$table."
             WHERE team_id = ?", undef, $self->id);

        $self->{$cache} = $item_class->new_from_list($item_ids);
    }
    return $self->{$cache};
}


=head3 add_responsibility

Adds new item into team responsibilities.
Returns boolean true if object was added.
Throws an error if object with given id does not exist.

    add_responsibility($type, $item)

=over

=item C<$type> 'component' or 'keyword'

=item C<$item> Object or id to add.

=back

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
    my $table = "agile_team_".$type;
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


=head3 remove_responsibility

Removes item from the team responsibilities.
Returns boolean true if item was removed.

    remove_responsibility($type, $item)

=over

=item C<$type> 'component' or 'keyword'

=item C<$item> Object or id to remove.

=back

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
    my $table = "agile_team_".$type;
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

=head2 For user permissions

=head3 user_can_edit

Returns boolean true if user is allowed to edit the team.

    user_can_edit($user)

=over

=item C<$user> (optional) L<Bugzilla::User> object.
    Current logged in user is used if not given.

=back

=cut

sub user_can_edit {
    my ($self, $user) = @_;
    $user = get_user($user);
    return 0 unless $user->id;

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


=head2 For items

=head3 unprioritized_items

Returns array ref of L<Bugzilla::Bug> objects which are in teams
responsibilities, but are not in any pool.

    unprioritized_items($include)

=over

=item C<$include> - (optional) Resposibilities to include
        A has ref where key is responsibility type and value is array ref of IDs

=back

=cut

sub unprioritized_items {
    my ($self, $include) = @_;

    # Get search params
    my $params = $self->unprioritized_search_params($include);

    # Return directly if nothing was included
    return [] unless defined $params;

    # Use search to get the bug ids
    my $search = new Bugzilla::Search(fields => ["bug_id"], params => $params);
    my $dbh = Bugzilla->dbh;
    my $bug_ids = $dbh->selectcol_arrayref($search->sql);
    return Bugzilla::Bug->new_from_list($bug_ids);
}

=head3 unprioritized_search_params

Returns hash ref containing the parameters suitable for Bugzilla search

=over

=item C<$include> - (optional) Resposibilities to include
        A hass ref where key is responsibility type and value is array ref of IDs

=back

=cut

sub unprioritized_search_params {
    my ($self, $include) = @_;
    # Open bugs which are not in a pool
    my $params = {
        resolution => "---",
        f1 => "bug_agile_pool.pool_id",
        o1 => "equals",
        v1 => "-1",
        f2 => "OP", j2 => "OR"
    };

    my $fidx = 3;
    # Add filtered responsibilities to params
    foreach my $type (qw(component keyword)) {
        my $field = $type eq "keyword" ? $type."s" : $type;

        next if (defined $include && !defined $include->{$type});
        foreach my $item (@{$self->responsibilities($type)}) {
            next if (defined $include &&
                !grep {$item->id == $_} @{$include->{$type} || []});

            $params->{"f".$fidx} = $field;
            $params->{"o".$fidx} = "equals";
            $params->{"v".$fidx} = $item->name;
            $fidx++;
        }
    }
    return ($fidx == 3) ? undef : $params;
}

=head3 pools

Returns Array ref of L<Pool|extensions::AgileTools::lib::Pool> objects
containing teams backlog and sprint pools.

=cut

sub pools {
    my ($self, $active) = @_;
    unless (defined $self->{pools}) {
        my @pools;
        push(@pools, map {$_->pool} @{$self->backlogs});

        if($self->process_id == AGILE_PROCESS_SCRUM) {
            push(@pools, map {$_->pool} 
                    @{Bugzilla::Extension::AgileTools::Sprint->match(
                        {team_id => $self->id}) });
        }
        $self->{pools} = \@pools;
    }
    if (defined $active) {
        if ($active) {
            return [grep {$_->is_active} @{$self->{pools}}];
        } else {
            return [grep {!$_->is_active} @{$self->{pools}}];
        }
    }
    return $self->{pools};
}

=head3 current_sprint

Returns the curent L<Sprint|extensions::AgileTools::lib::Sprint> of the team
or undef if there is no current sprint

=cut

sub current_sprint {
    my $self = shift;
    return undef if ($self->process_id != AGILE_PROCESS_SCRUM);
    return undef if (! $self->{current_sprint_id});
    $self->{current_sprint} ||=
        Bugzilla::Extension::AgileTools::Sprint->new($self->current_sprint_id);
    return $self->{current_sprint};
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

    my $team = $class->insert_create_data($clean_params);

    # Create current sprint
    my $now = DateTime->now();
    my $sprint = Bugzilla::Extension::AgileTools::Sprint->create({
            team_id => $team->id,
            start_date => $now->ymd,
            end_date => $now->add(days => 7 )->ymd,
        });
    $team->set_current_sprint_id($sprint->id);
    $team->update();

    return $team;
}

sub remove_from_db {
    my $self = shift;

    # Remove sprints
    my $sprints = Bugzilla::Extension::AgileTools::Sprint->match(
        {team_id => $self->id});
    foreach my $sprint (@$sprints) {
        $sprint->remove_from_db();
    }

    # Take group for later deletion
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


=head3 agile_teams

Returns the list of teams the user is member in as array ref of
C<Team|extensions::AgileTools::lib::Team> objects.

=cut

BEGIN {
    *Bugzilla::User::agile_teams = sub {
        my $self = shift;
        return $self->{agile_teams} if defined $self->{agile_teams};

        my @group_ids = map { $_->id } @{$self->direct_group_membership};
        my $team_ids = @group_ids ? Bugzilla->dbh->selectcol_arrayref(
                "SELECT id FROM agile_team ".
                "WHERE group_id IN (". join(",", @group_ids) .")") : [];
        $self->{agile_teams} = Bugzilla::Extension::AgileTools::Team->
                new_from_list($team_ids);
        return $self->{agile_teams};
    };
}

1;

__END__

=head1 NOTES

None of the methods check if user is allowed to modify the teams. This should be
done by higher level controller methods using this as only a interface to the
stored data.

=head1 SEE ALSO

L<Bugzilla::Object>
