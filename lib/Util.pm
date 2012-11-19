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
    user_can_manage_teams
);

use Bugzilla::Error;

use Scalar::Util qw(blessed);

=head1 FUNCTIONS

=over

=item C<get_user($user)>

    Description: Gets user object or throws error if user is not found
    Params:      $user -> User ID or login name
    Returns:     L<Bugzilla::User> object

=cut

sub get_user {
    my $user = shift;
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

=item C<user_can_manage_teams($user)>

    Description: Check if user is allowed to create/remove teams
    Params:      $user - (optional) User object, login name or ID
    Returns:     1 if user can manage teams, 0 otherwise

B<Note:> Currently just checks if user is in group admin, but we might provide
additional groups to identify user allowed to create and remove teams in the
future.

=cut

sub user_can_manage_teams {
    my $user = shift || Bugzilla->user;
    $user = get_user($user);
    return $user->in_group("admin");
}

1;

__END__

=back
