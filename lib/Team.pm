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
use URI::QueryParam;

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
    responsibility_query
    is_active
);

use constant NUMERIC_COLUMNS => qw(
    group_id
    process_id
    current_sprint_id
    is_active
);

use constant UPDATE_COLUMNS => qw(
    name
    process_id
    current_sprint_id
    responsibility_query
    is_active
);

# responsibility_query needs the default value generated by the validator
use constant EXTRA_REQUIRED_FIELDS => qw(
    responsibility_query
);

use constant VALIDATORS => {
    name => \&_check_name,
    process_id => \&_check_process_id,
    responsibility_query => \&_check_responsibility_query,
    is_active => \&Bugzilla::Object::check_boolean,
};

=head1 METHODS

=head2 Accessors

For all L</FIELDS> there is $object->fieldname method

Additionally there are accessors for

=cut

sub group_id   { return $_[0]->{group_id}; }
sub process_id { return $_[0]->{process_id}; }
sub current_sprint_id { return $_[0]->{current_sprint_id}; }
sub responsibility_query { return $_[0]->{responsibility_query}; }
sub is_active   { return $_[0]->{is_active}; }

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
sub set_responsibility_query { $_[0]->set('responsibility_query', $_[1]); }
sub set_is_active { $_[0]->set('is_active', $_[1]); }

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

sub _check_responsibility_query {
    my ($invocant, $query) = @_;
    $query ||= '';
    $query = '?'.$query unless ($query =~ /\?/);
    my $uri = new URI($query);
    $uri->query_param(f1 => 'bug_agile_pool.pool_id');
    $uri->query_param(v1 => -1);
    $uri->query_param(o1 => 'equals');
    $uri->query_param('resolution' => '---');
    $uri->query_param_delete('list_id');

    $query = $uri->query();
    return "?".$query;
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

=cut

sub unprioritized_items {
    my $self = shift;

    # Get search params
    my $uri = new URI($self->responsibility_query);
    # Use search to get the bug ids
    my $search = new Bugzilla::Search(fields => ["bug_id"],
            params => $uri->query_form_hash);
    my $dbh = Bugzilla->switch_to_shadow_db();
    my $bug_ids;
    if ($search->can('data')) {
        $bug_ids = [map {$_->[0] } @{$search->data}];
    } else {
        $bug_ids = $dbh->selectcol_arrayref($search->sql);
    }
    return Bugzilla::Bug->new_from_list($bug_ids);
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
        my ($old_name, $new_name) = @{$changes->{name}};
        $self->group->set_all({
                name => "team $new_name",
                description => "'$new_name' team member group",
            }
        );
        $self->group->update();
        # Reflect the name change on pools
        for my $pool (@{$self->pools})
        {
            my $pool_name = $pool->name;
            $pool_name =~ s/\Q$old_name\E/$new_name/;
            $pool->set_name($pool_name);
            $pool->update();
        }
        delete $self->{backlogs};
        delete $self->{current_sprint}
    }
    if ($changes->{is_active}) {
        # Change the active status of relevant pools
        if ($self->process_id == AGILE_PROCESS_SCRUM) {
            $self->current_sprint->pool->set_is_active($self->is_active);
            $self->current_sprint->pool->update();
        }
        for my $backlog (@{$self->backlogs}) {
            $backlog->pool->set_is_active($self->is_active);
            $backlog->pool->update();
        }
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
        if ($sprint->is_active) {
            # Active sprint can't be removed, so we need to fool it to think
            # it's inactive
            $sprint->pool->set_is_active(0);
        }
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

        my $tids = Bugzilla->dbh->selectcol_arrayref(
            "SELECT id FROM agile_team
             LEFT JOIN user_group_map AS ugm
                  ON ugm.group_id = agile_team.group_id
              WHERE ugm.user_id = ?", undef, $self->id);

        $self->{agile_teams} =
            Bugzilla::Extension::AgileTools::Team->new_from_list($tids);

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
