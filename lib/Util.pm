# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Util - AgileTools utility functions

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools::Util;

    my $user = get_user(1);
    my $user = get_user('john.doe@example.com');

    my $team = get_team($team_id);

    my $role = get_role($role_id);
    my $role = get_role("Scrum Master");

=head1 DESCRIPTION

AgileTools extension utility functions

=cut

package Bugzilla::Extension::AgileTools::Util;
use strict;

use base qw(Exporter);
our @EXPORT = qw(
    get_user
    get_team
    get_role
    user_can_change_estimated_time
    user_can_manage_teams
    user_in_agiletools_group
);

use Bugzilla::Error;

use Scalar::Util qw(blessed);

=head1 FUNCTIONS

=over

=item C<get_user($user)>

    Description: Gets user object or throws error if user is not found. Without
                 parameters returns the logged in user
    Params:      $user -> User ID or login name
    Returns:     L<Bugzilla::User> object

=cut

sub get_user {
    my $user = shift || Bugzilla->user;
    if (!blessed $user) {
        if ($user =~ /^\d+$/) {
            $user = Bugzilla::User->check({id => $user});
        } else {
            $user = Bugzilla::User->check($user);
        }
    }
    return $user;
}

=item C<get_team($team_id, $edit)>

    Description: Gets team object or throws error if team is not found
    Params:      $team_id -> Team ID
                 $edit - If true, checks that user is allowed to edit the team
    Returns:     L<Bugzilla::Extension::AgileTools::Team> object

=cut

sub get_team {
    my ($id, $edit) = @_;
    my $team = Bugzilla::Extension::AgileTools::Team->new($id);
    ThrowUserError('object_does_not_exist', {
            id => $id, class => 'AgileTools::Team' })
        unless defined $team;
    ThrowUserError('agile_team_edit_not_allowed', {name => $team->name})
        if ($edit && !$team->user_can_edit);
    return $team;
}

=item C<get_role($role)>

    Description: Gets role object or throws error if role is not found
    Params:      $role -> Role ID or name
    Returns:     L<Bugzilla::Extension::AgileTools::Role> object

=cut

sub get_role {
    my $role = shift;
    if (!blessed $role) {
        if ($role =~ /^\d+$/) {
            $role = Bugzilla::Extension::AgileTools::Role->check({id => $role});
        } else {
            $role = Bugzilla::Extension::AgileTools::Role->check($role);
        }
    }
    return $role;
}

=item C<user_can_change_estimated_time($bug, $user)>

    Description: Check if user is allowed to change the estimated time of a bug
    Params:      $bug - Bug object to check against
                 $user - (optional) User object, login name or ID
    Returns:     1 if user can do the change

=cut

sub user_can_change_estimated_time {
    my $bug = shift;
    my $user = get_user(shift);
    return 1 unless Bugzilla->params->{'agile_lock_origest_in_sprint'};
    return 1 unless ($bug->pool && $bug->pool->is_sprint);
    my $sprint = Bugzilla::Extension::AgileTools::Sprint->new($bug->pool_id);
    return 1 unless $sprint->committed;
    # TODO make this more sensible when the team roles are customizable
    return (grep {$_->name eq 'Scrum Master'}
                @{$user->agile_team_roles($sprint->team)}) ? 1 : 0;
}

=item C<user_can_manage_teams($user)>

    Description: Check if user is allowed to create/remove teams
    Params:      $user - (optional) User object, login name or ID
    Returns:     1 if user can manage teams, 0 otherwise

B<Note:> Currently just checks if user is in group admin, but we might provide
additional groups to identify user allowed to create and remove teams in the
future.

=cut

sub user_can_manage_teams {
    my $user = shift;
    $user = get_user($user);
    return $user->in_group("admin");
}

=item C<user_in_agiletools_group($user, $throwerror)>

    Description: Check if user is in AgileTools user group
    Params:      $throwerror - (Optional) If true, throw access denied erro if
                 there is no logged in user or the user is not in the group.

    Returns:     true if user in AgileTools user group or if the group is not
                 defined

=cut

sub user_in_agiletools_group {
    my $throwerror = shift;
    my $user = Bugzilla->user;
    my $ingroup = 0;
    if ($user->id) {
        my $group = Bugzilla->params->{agile_user_group};
        if ($group) {
            $ingroup = $user->in_group($group) ? 1 : 0;
        } else {
            $ingroup = 1;
        }
    }
    ThrowUserError("agile_access_denied") if ($throwerror && !$ingroup);
    return $ingroup;
}

1;

__END__

=back
