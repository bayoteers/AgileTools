# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::WebService::Team - Team manipulation WS methods

=head1 DESCRIPTION

Web service methods available under namespace 'Agile.Team'.

=cut

use strict;
use warnings;

package Bugzilla::Extension::AgileTools::WebService::Team;

use base qw(Bugzilla::WebService);

use Bugzilla::Constants;
use Bugzilla::Error;

use Bugzilla::Extension::AgileTools::Team;

use Bugzilla::Extension::AgileTools::Util;
use Bugzilla::Extension::AgileTools::WebService::Util;


# Use the _bug_to_hash method from Bugzilla::WebService::Bug
use Bugzilla::WebService::Bug;
BEGIN {
  *_bug_to_hash = \&Bugzilla::WebService::Bug::_bug_to_hash;
  if (Bugzilla::WebService::Bug->can('_flag_to_hash')) {
    *_flag_to_hash = \&Bugzilla::WebService::Bug::_flag_to_hash;
  }
}

# Webservice field type mapping
use constant FIELD_TYPES => {
    id => "int",
    name => "string",
    group_id => "int",
    process_id => "int",
};

use constant PUBLIC_METHODS => qw(
    update
    add_member
    remove_member
    add_member_role
    remove_member_role
    unprioritized_items
);

=head1 METHODS

=over

=item C<update>

    Description: Updates team details
    Params:      id - Team id
                 name - (optional) Change team name
    Returns:     Changes hash like from L<Bugzilla::Object::update>

=cut

sub update {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {
            function => 'Agile.Team.update',
            param => 'id'})
        unless defined $params->{id};

    my $team = get_team(delete $params->{id}, 1);
    $team->set_all($params);
    my $changes = $team->update();
    return changes_to_hash($self, $changes, FIELD_TYPES);
}

=item C<add_member>

    Description: Add a new team member
    Params:      id - Team ID
                 user - User login name or id
    Returns:     The new list of team members

=cut

sub add_member {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {function => 'Agile.Team.add_member',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.add_member',
            param => 'user'}) unless defined $params->{user};

    my $team = get_team($params->{id}, 1);
    $team->add_member($params->{user});
    # TODO: WebService type the result
    return $team->members;
}

=item C<remove_member>

    Description: Remove a team member
    Params:      id - Team ID
                 user - User login name or id
    Returns:     The new list of team members

=cut

sub remove_member {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_member',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_member',
            param => 'user'}) unless defined $params->{user};

    my $team = get_team($params->{id}, 1);
    $team->remove_member($params->{user});
    # TODO: WebService type the result
    return $team->members;
}

=item C<add_member_role>

    Description: Add new role to a team member
    Params:      id - Team id
                 user - Team member user id or login name
                 role -> New role id or name
    Returns:     The new role or empty object if user already had that role

=cut

sub add_member_role {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {function => 'Agile.Team.add_member_role',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.add_member_role',
            param => 'user'}) unless defined $params->{user};
    ThrowCodeError('param_required', {function => 'Agile.Team.add_member_role',
            param => 'role'}) unless defined $params->{role};
    my $team = get_team($params->{id}, 1);
    my $role = get_role($params->{role});
    my $user = get_user($params->{user});
    # TODO: WebService type the result
    if ($role->add_user_role($team, $user)) {
        return {userid => $user->id, role => $role};
    }
    return {};
}

=item C<remove_member_role>

    Description: Remove role from a team member
    Params:      id - Team id
                 user - Team member user id or login name
                 role -> New role id or name
    Returns:     The role that was removed or empty object if user did not have
                 that role

=cut

sub remove_member_role {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_member_role',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_member_role',
            param => 'user'}) unless defined $params->{user};
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_member_role',
            param => 'role'}) unless defined $params->{role};
    my $team = get_team($params->{id}, 1);
    my $role = get_role($params->{role});
    my $user = get_user($params->{user});
    # TODO: WebService type the result
    if ($role->remove_user_role($team, $user)) {
        return {userid => $user->id, role => $role};
    }
    return {};
}

=item c<unprioritized_items>

    description: Get unprioritized bugs in teams responsibilites
    params:      id - team id
                 include - Resposibilities to include
                           { type: [ IDs ], }
    returns:     { bugs: [list of bugs,... ] }

=cut

sub unprioritized_items {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {function => 'Agile.Team.unprioritized_items',
            param => 'id'}) unless defined $params->{id};

    my $team = get_team($params->{id});
    my @bugs;
    foreach my $bug (@{$team->unprioritized_items($params->{include})}) {
        my $bug_hash = $self->_bug_to_hash($bug, $params);
        push(@bugs, $bug_hash);
    }

    return {bugs => \@bugs};
}

1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::WebService>

