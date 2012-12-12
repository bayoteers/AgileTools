#!/usr/bin/perl -w
# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>
#
#
# Migration script to set the team current sprint.
#
# Sets the latest sprint as teams current sprint and sets all sprints before
# that as inactive.
#

use strict;
use warnings;
use lib qw(. lib);

use Bugzilla;
BEGIN { Bugzilla->extensions }

use Bugzilla::Extension::AgileTools::Constants;
use Bugzilla::Extension::AgileTools::Team;
use Bugzilla::Extension::AgileTools::Sprint;


my $dbh = Bugzilla->dbh;

my $teams = Bugzilla::Extension::AgileTools::Team->match(
    {process_id => AGILE_PROCESS_SCRUM});

my $now = Bugzilla->dbh->selectrow_array("SELECT NOW()");

for my $team (@$teams) {
    next if $team->current_sprint_id;
    my $sprint_id = $dbh->selectrow_array('SELECT id FROM agile_sprint '.
        'WHERE team_id = ? AND start_date <= ? '.
        'ORDER BY start_date DESC', undef, $team->id, $now);

    next unless $sprint_id;
    $team->set_current_sprint_id($sprint_id) if ($sprint_id);
    $team->update();
    print "Set ".$team->name." current sprint to ".$sprint_id."\n";
    my $count = $dbh->do('UPDATE agile_pool AS P JOIN agile_sprint S ON P.id = S.id '.
            'SET is_active = 0 WHERE S.team_id = ? AND S.end_date < ?',
            undef, $team->id, $team->current_sprint->end_date);
    print "Deactivated ".$team->name."'s ".$count." older sprints\n";
}
