# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2013 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Pages::Scrum

=head1 DESCRIPTION

Scrum realted page handler functions

=head1 HANDLERS

=over

=cut

use strict;
use warnings;
package Bugzilla::Extension::AgileTools::Pages::Scrum;

use Bugzilla::Extension::AgileTools::Role;
use Bugzilla::Extension::AgileTools::Sprint;
use Bugzilla::Extension::AgileTools::Util;

use Bugzilla::Error;

use JSON;

=item C<planning> - The Scrum plnning view page

=cut

sub planning {
    my ($vars) = @_;
    my $cgi = Bugzilla->cgi;
    my $id = $cgi->param("team_id");
    ThrowUserError("invalid_parameter",
        {name=>"team_id", err => "Not specified"})
            unless defined $id;
    my $team = get_team($id);
    $vars->{team} = $team;
    my @roles = map {$_->name}
            @{Bugzilla::Extension::AgileTools::Role->get_user_roles(
                    $team)};
    $vars->{user_roles} = \@roles;
    my @pools;
    push(@pools, [-1, "Unprioritized items"]);
    for my $pool (@{$team->pools(1)}) {
        push(@pools, [$pool->id, $pool->name]);
    }
    $vars->{pools_json} = JSON->new->utf8->encode(\@pools);
    $vars->{left_id} = $cgi->param("left") || $team->current_sprint_id;
    $vars->{right_id} = $cgi->param("right") || $team->backlogs->[0] &&
            $team->backlogs->[0]->id;
}

=item C<sprints> - The team sprints listing page

=cut

sub sprints {
    my ($vars) = @_;
    my $id = Bugzilla->cgi->param("team_id");
    ThrowUserError("invalid_parameter",
        {name=>"team_id", err => "Not specified"})
            unless defined $id;
    my $team = get_team($id);
    my @sprints = reverse @{Bugzilla::Extension::AgileTools::Sprint->match(
            {team_id => $team->id})};
    $vars->{team} = $team;
    $vars->{sprints} = \@sprints;
}

=back

=cut

1;
__END__
