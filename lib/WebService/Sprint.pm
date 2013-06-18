# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::WebService::Sprint - Sprint manipulation WS methods

=head1 DESCRIPTION

Web service methods available under namespace 'Agile.Sprint'.

=cut

use strict;
use warnings;

package Bugzilla::Extension::AgileTools::WebService::Sprint;

use base qw(Bugzilla::WebService);

use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Extension::AgileTools::Sprint;

use Bugzilla::Extension::AgileTools::Util;
use Bugzilla::Extension::AgileTools::WebService::Util;

# Webservice field type mapping
use constant FIELD_TYPES => {
    "id" => "int",
    "name" => "string",
    "start_date" => "dateTime",
    "end_date" => "dateTime",
    "capacity" => "double",
    "is_current" => "boolean",
    "is_active" => "boolean",
    "committed" => "boolean",
};

=head1 METHODS

=over

=item C<get>

    Description: Fetch sprint info
    Params:      id - Sprint ID
    Returns:     The sprint object

=cut

sub get {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.get',
            param => 'id'})
        unless defined $params->{id};
    my $sprint = Bugzilla::Extension::AgileTools::Sprint->check({
            id => $params->{id}});
    return object_to_hash($self, $sprint, FIELD_TYPES);
}


=item C<create>

    Description: Create new sprint
    Params:      team_id - Team id
                 start_date - Start date of the sprint
                 end_date - End date of the sprint
    Returns:     Created sprint object

=cut

sub create {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.create',
            param => 'team_id'})
        unless defined $params->{team_id};
    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.create',
            param => 'start_date'})
        unless defined $params->{start_date};
    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.create',
            param => 'end_date'})
        unless defined $params->{end_date};

    my $team = Bugzilla::Extension::AgileTools::Sprint->check({
            id => $params->{team_id} });
    ThrowUserError("agile_permission_denied", {permission=>'create sprint'})
        unless $team->user_can_edit;

    my $sprint = Bugzilla::Extension::AgileTools::Sprint->create($params);
    return object_to_hash($self, $sprint, FIELD_TYPES);
}

=item C<update>

    Description: Updates sprint details
    Params:      id - Sprint ID
                 start_date - (optional) Change start_date
                 end_date - (optional) Change end_date
    Returns:     Hash with 'id' and 'changes' like from L<Bugzilla::Object::update>

=cut

sub update {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.update',
            param => 'id'})
        unless defined $params->{id};

    my $sprint = Bugzilla::Extension::AgileTools::Sprint->check({
            id =>delete $params->{id} });

    ThrowUserError("agile_permission_denied", {permission=>'edit sprint'})
        unless $sprint->team->user_can_edit;

    $sprint->set_all($params);
    my $changes = $sprint->update();
    return {
        sprint => $self->type("int", $sprint->id),
        changes => changes_to_hash($self, $changes, FIELD_TYPES),
    };
}

=item C<close>

    Description: Closes the current sprint
    Params:      id - Sprint ID
                 next_id - ID of the sprint to use as base for new current sprint
                 start_date - Start date of the new current sprint
                 end_date - End date of the new current sprint
    Returns:     Archived sprint info

Resolved items from current sprint are moved to new archive sprint, which will
have start and end date of current sprint.

If C<next_id> is given, items from that sprint are moved to current sprint and
start and end dates are copied from that sprint.

If C<start_date> and C<end_date> are given, current sprint dates are updated to
those.

=cut

sub close {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.close',
            param => 'id'})
        unless defined $params->{id};

    my $sprint = Bugzilla::Extension::AgileTools::Sprint->check({
            id => delete $params->{id} });

    ThrowUserError("agile_permission_denied", {permission=>'close sprint'})
        unless $sprint->team->user_can_edit;

    my $archived = $sprint->close($params);
    return object_to_hash($self, $archived, FIELD_TYPES);
}

=item C<commit>

    Description: Marks the sprint as committed
    Params:      id - Sprint ID

=cut

sub commit {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.commit',
            param => 'id'})
        unless defined $params->{id};

    my $sprint = Bugzilla::Extension::AgileTools::Sprint->check({
            id => delete $params->{id} });

    ThrowUserError("agile_permission_denied", {permission=>'commit sprint'})
        unless $sprint->team->user_can_edit;

    return $sprint->commit();
}

=item C<uncommit>

    Description: Marks the sprint as not committed
    Params:      id - Sprint ID

=cut

sub uncommit {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.uncommit',
            param => 'id'})
        unless defined $params->{id};

    my $sprint = Bugzilla::Extension::AgileTools::Sprint->check({
            id => delete $params->{id} });

    ThrowUserError("agile_permission_denied", {permission=>'uncommit sprint'})
        unless $sprint->team->user_can_edit;

    return $sprint->uncommit();
}

=item C<delete>

    Description: Delete a sprint
    Params:      id - Sprint ID

=cut

sub delete {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.delete',
            param => 'id'})
        unless defined $params->{id};

    my $sprint = Bugzilla::Extension::AgileTools::Sprint->check({
            id => delete $params->{id} });

    ThrowUserError("agile_permission_denied", {permission=>'delete sprint'})
        unless $sprint->team->user_can_edit;

    $sprint->remove_from_db;
    return 1;
}

1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::WebService>
