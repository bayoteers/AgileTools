# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2013 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::WebService::Backlog

=head1 DESCRIPTION

Web service methods for managing backlogs.
Namespace: Agile.Backlog

=cut

use strict;
use warnings;

package Bugzilla::Extension::AgileTools::WebService::Backlog;

use base qw(Bugzilla::WebService);

use Bugzilla::Constants;
use Bugzilla::Error;

use Bugzilla::Extension::AgileTools::Backlog;
use Bugzilla::Extension::AgileTools::Team;

use Bugzilla::Extension::AgileTools::Util;
use Bugzilla::Extension::AgileTools::WebService::Util;

# Webservice field type mapping
use constant FIELD_TYPES => {
    name => "string",
    team_id => "int",
};

=head1 METHODS

=over

=item C<update>

    Description: Updates Backlog
    Params:      id - Backlog id
                 team_id - New Team ID
    Returns:     { backlog => backlog object
                   changes => Changes hash from Bugzilla::Object::update }

=cut

sub update {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);
    my $backlog_id = delete $params->{id};
    ThrowCodeError('param_required', {
            function => 'Agile.Backlog.update',
            param => 'id'})
        unless defined $backlog_id;

    my $backlog = Bugzilla::Extension::AgileTools::Backlog->check(
            {id=>$backlog_id});
    if (exists $params->{team_id}) {
        # Check that user is allowed to edit both teams
        if ($params->{team_id} != $backlog->team_id) {
            get_team($params->{team_id}, 1) if defined $params->{team_id};
            get_team($backlog->team_id, 1) if defined $backlog->team_id;
        }
    }

    $backlog->set_all($params);
    my $changes = $backlog->update();
    return {
        backlog => $backlog,
        changes =>changes_to_hash($self, $changes, FIELD_TYPES)
    };
}

=item C<create>

    Description: Create new Backlog
    Params:      name - Backlog name
                 team_id - (optional) Team ID for the backlog
    Returns:     The new Backlog object

=cut

sub create {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);

    my $team = get_team($params->{team_id}, 1) if (defined $params->{team_id});

    my $backlog = Bugzilla::Extension::AgileTools::Backlog->create($params);
    return $backlog;
}

1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::WebService>

