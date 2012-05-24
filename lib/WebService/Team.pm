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

Bugzilla::Extension::AgileTools::WebService::Team

=head1 DESCRIPTION

Web service methods available under namespase 'Agile.Team'.

=cut

use strict;
use warnings;

package Bugzilla::Extension::AgileTools::WebService::Team;

use base qw(Bugzilla::WebService);

use Bugzilla::Error;
use Bugzilla::WebService::Bug;

use Bugzilla::Extension::AgileTools::Team;

use Bugzilla::Extension::AgileTools::Util qw(get_team get_role get_user);

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

    ThrowCodeError('param_required', {
            function => 'Agile.Team.update',
            param => 'id'})
        unless defined $params->{id};

    my $team = get_team(delete $params->{id}, 1);
    $team->set_all($params);
    return $team->update();
}

=item C<add_member>

    Description: Add a new team member
    Params:      id - Team ID
                 user - User login name or id
    Returns:     The new list of team members

=cut

sub add_member {
    my ($self, $params) = @_;
    ThrowCodeError('param_required', {function => 'Agile.Team.add_member',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.add_member',
            param => 'user'}) unless defined $params->{user};

    my $team = get_team($params->{id}, 1);
    $team->add_member($params->{user});
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
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_member',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_member',
            param => 'user'}) unless defined $params->{user};

    my $team = get_team($params->{id}, 1);
    $team->remove_member($params->{user});
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
    ThrowCodeError('param_required', {function => 'Agile.Team.add_member_role',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.add_member_role',
            param => 'user'}) unless defined $params->{user};
    ThrowCodeError('param_required', {function => 'Agile.Team.add_member_role',
            param => 'role'}) unless defined $params->{role};
    my $team = get_team($params->{id}, 1);
    my $role = get_role($params->{role});
    my $user = get_user($params->{user});
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
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_member_role',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_member_role',
            param => 'user'}) unless defined $params->{user};
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_member_role',
            param => 'role'}) unless defined $params->{role};
    my $team = get_team($params->{id}, 1);
    my $role = get_role($params->{role});
    my $user = get_user($params->{user});
    if ($role->remove_user_role($team, $user)) {
        return {userid => $user->id, role => $role};
    }
    return {};
}

=item C<add_responsibility>

    Description: Add a new team responsibility
    Params:      id => Team ID
                 type => Responsibility type, 'component' or 'keyword'
                 item_id - Object ID of the component or keyword
    Returns:     The new list of team responsibilities for that type

=cut

sub add_responsibility {
    my ($self, $params) = @_;
    ThrowCodeError('param_required', {function => 'Agile.Team.add_responsibility',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.add_responsibility',
            param => 'type'}) unless defined $params->{type};
    ThrowCodeError('param_required', {function => 'Agile.Team.add_responsibility',
            param => 'item_id'}) unless defined $params->{item_id};

    my $team = get_team($params->{id}, 1);
    $team->add_responsibility($params->{type}, $params->{item_id});
    return {type => $params->{type},
        items => $team->responsibilities($params->{type})};
}

=item c<remove_responsibility>

    description: remove a team responsibility
    params:      id - team id
                 type - responsibility type, 'component' or 'keyword'
                 item_id - object id of the component or keyword
    returns:     the new list of team responsibilities for that type

=cut

sub remove_responsibility {
    my ($self, $params) = @_;
    ThrowCodeError('param_required', {function => 'agile.team.remove_responsibility',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'agile.team.remove_responsibility',
            param => 'type'}) unless defined $params->{type};
    ThrowCodeError('param_required', {function => 'agile.team.remove_responsibility',
            param => 'item_id'}) unless defined $params->{item_id};

    my $team = get_team($params->{id}, 1);
    $team->remove_responsibility($params->{type}, $params->{item_id});
    return {type => $params->{type},
        items => $team->responsibilities($params->{type})};
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
    ThrowCodeError('param_required', {function => 'Agile.Team.unprioritized_items',
            param => 'id'}) unless defined $params->{id};

    my $team = get_team($params->{id});
    my @bugs;
    foreach my $bug (@{$team->unprioritized_items($params->{include})}) {
        my $bug_hash = Bugzilla::WebService::Bug::_bug_to_hash(
            $self, $bug, $params);
        push(@bugs, $bug_hash);
    }

    return {bugs => \@bugs};
}

1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::WebService>

