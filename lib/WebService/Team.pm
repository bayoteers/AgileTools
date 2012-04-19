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

use strict;
use warnings;

package Bugzilla::Extension::AgileTools::WebService::Team;

use base qw(Bugzilla::WebService);

use Bugzilla::Error;
use Bugzilla::Extension::AgileTools::Team;

# Webservice methods in 'Agile.Team' namespace

sub _get_team {
    my ($self, $id, $edit) = @_;
    my $team = Bugzilla::Extension::AgileTools::Team->new($id);
    ThrowUserError('object_does_not_exist', {
            id => $id, class => 'AgileTools::Team' })
        unless defined $team;
    ThrowUserError('agile_team_edit_not_allowed', {name => $team->name})
        if ($edit && !$team->user_can_edit);
    return $team;
}

sub update {
    my ($self, $params) = @_;

    ThrowCodeError('param_required', {
            function => 'Agile.Team.update',
            param => 'id'})
        unless defined $params->{id};

    my $team = $self->_get_team(delete $params->{id}, 1);
    $team->set_all($params);
    return $team->update();
}

sub add_member {
    my ($self, $params) = @_;
    ThrowCodeError('param_required', {function => 'Agile.Team.add_member',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.add_member',
            param => 'user'}) unless defined $params->{user};

    my $team = $self->_get_team($params->{id}, 1);
    $team->add_member($params->{user});
    return $team->members;
}

sub remove_member {
    my ($self, $params) = @_;
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_member',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_member',
            param => 'user'}) unless defined $params->{user};

    my $team = $self->_get_team($params->{id}, 1);
    $team->remove_member($params->{user});
    return $team->members;
}

sub add_responsibility {
    my ($self, $params) = @_;
    ThrowCodeError('param_required', {function => 'Agile.Team.add_responsibility',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.add_responsibility',
            param => 'type'}) unless defined $params->{type};
    ThrowCodeError('param_required', {function => 'Agile.Team.add_responsibility',
            param => 'item_id'}) unless defined $params->{item_id};

    my $team = $self->_get_team($params->{id}, 1);
    $team->add_responsibility($params->{type}, $params->{item_id});
    return $team->responsibilities($params->{type});
}

sub remove_responsibility {
    my ($self, $params) = @_;
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_responsibility',
            param => 'id'}) unless defined $params->{id};
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_responsibility',
            param => 'type'}) unless defined $params->{type};
    ThrowCodeError('param_required', {function => 'Agile.Team.remove_responsibility',
            param => 'item_id'}) unless defined $params->{item_id};

    my $team = $self->_get_team($params->{id}, 1);
    $team->remove_responsibility($params->{type}, $params->{item_id});
    return $team->responsibilities($params->{type});
}


1;

__END__

=head1 NAME

Bugzilla::Extension::AgileTools::WebService::Team

=head1 SYNOPSIS

Web service methods available under namespase 'Agile.Team'.

=head1 METHODS

=over

=item C<update>

Description: Updates team details

Params:      id - Team id
             name - (optional) Change team name

Returns:     Changes hash like from L<Bugzilla::Object::update> 


=item C<add_member>

Description: Add a new team member

Params:      id - Team ID
             user - User login name or id

Returns:     The new list of team members


=item C<remove_member>

Description: Remove a team member

Params:      id - Team ID
             user - User login name or id

Returns:     The new list of team members


=item C<add_responsibility>

Description: Add a new team responsibility

Params:      id => Team ID
             type => Responsibility type, 'component' or 'keyword'
             item_id => Responsibility ID

Returns:     The new list of team responsibilities for that type


=item C<remove_responsibility>

Description: Remove a team responsibility

Params:      id - Team ID
             type - Responsibility type, 'component' or 'keyword'
             item_id - Responsibility ID

Returns:     The new list of team responsibilities for that type


=back

