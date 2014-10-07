# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2013 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Pages::Team

=head1 DESCRIPTION

Team realted page handler functions

=head1 HANDLERS

=over

=cut

use strict;
use warnings;
package Bugzilla::Extension::AgileTools::Pages::Team;

use Bugzilla::Extension::AgileTools::Constants;
use Bugzilla::Extension::AgileTools::Role;
use Bugzilla::Extension::AgileTools::Team;
use Bugzilla::Extension::AgileTools::Util;

use Bugzilla::Constants;
use Bugzilla::Error;

use JSON;

=item C<list> - The "All Teams" page

=cut

sub list {
    my ($vars) = @_;
    my $cgi = Bugzilla->cgi;
    my $action = $cgi->param("action") || "";
    $vars->{can_manage_teams} = user_can_manage_teams();
    if ($action eq "remove") {
        ThrowUserError("agile_team_manage_denied")
            unless $vars->{can_manage_teams};
        my $team = Bugzilla::Extension::AgileTools::Team->check({
                id => scalar $cgi->param("team_id")});
        $vars->{team} = {name=>$team->name};
        $team->remove_from_db();
        $vars->{message} = "agile_team_removed";
    }
    $vars->{user_teams} = scalar $cgi->param('user_teams') ? 1 : 0;
    my @teams = $vars->{user_teams} ? 
        @{Bugzilla->user->agile_teams} :
        Bugzilla::Extension::AgileTools::Team->get_all();
    $vars->{active_teams} = [grep($_->is_active, @teams)];
    $vars->{inactive_teams} = [grep(!$_->is_active, @teams)];
}

=item C<show> - Single team view page

=cut

sub show {
    my ($vars) = @_;
    my $user = Bugzilla->user;
    my $cgi = Bugzilla->cgi;
    my $team;
    my $action = $cgi->param("action") || "";
    if ($action eq "create") {
        ThrowUserError("agile_team_manage_denied")
            unless user_can_manage_teams;
        $team = Bugzilla::Extension::AgileTools::Team->create({
                name => scalar $cgi->param("name"),
                process_id => scalar $cgi->param("process_id"),
            });
        if ($cgi->param("create_backlog")) {
            Bugzilla::Extension::AgileTools::Backlog->create({
                name => $team->name." backlog",
                team_id => $team->id,
            });
        }
        $vars->{message} = "agile_team_created";
    } elsif ($action eq 'save') {
        my $id = $cgi->param("team_id");
        $team = Bugzilla::Extension::AgileTools::Team->check({id => $id});
        $team->set_all({
            name => scalar $cgi->param('name'),
            is_active => scalar $cgi->param('is_active') ? 1 : 0,
        });
        $vars->{changes} = scalar $team->update();
        $vars->{message} = 'agile_team_saved';
        $vars->{team} = $team;

    } else {
        my $id = $cgi->param("team_id");
        $team = Bugzilla::Extension::AgileTools::Team->check({id => $id});
    }

    $vars->{processes} = AGILE_PROCESS_NAMES;
    $vars->{team} = $team;
    $vars->{roles} = Bugzilla::Extension::AgileTools::Role->match();

    $vars->{available_backlogs} =
        Bugzilla::Extension::AgileTools::Backlog->match({team_id => IS_NULL});
    $team->roles;
    $vars->{team_json} = JSON->new->convert_blessed->encode($team);
}

=item C<create> - The create team page

=cut

sub create {
    my ($vars) = @_;
    ThrowUserError("agile_team_manage_denied")
        unless user_can_manage_teams;
    $vars->{processes} = AGILE_PROCESS_NAMES;
}

=back

=cut

1;
__END__
