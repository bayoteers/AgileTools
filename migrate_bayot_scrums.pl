#!/usr/bin/perl -w
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
#
#
# Migration script to move team data from old BAYOT Scrums extension.
#
# Copies
#  - all teams from old DB schema
#  - members from old teams and sets product owner and scrum master roles
#  - team resposibility components
#  - bugs in team backlog for those teams which used backlog
#  - team sprints and bugs in the sprints
#

use strict;
use warnings;
use lib qw(. lib);

use Bugzilla;
BEGIN { Bugzilla->extensions }

use Bugzilla::Extension::AgileTools::Constants;
use Bugzilla::Extension::AgileTools::Team;
use Bugzilla::Extension::AgileTools::Role;

use Data::Dumper;

my $dbh = Bugzilla->dbh;

my $old_teams = $dbh->selectall_arrayref(
    "SELECT id, name, owner, scrum_master, is_using_backlog ".
      "FROM scrums_team", undef);

foreach my $row (@$old_teams) {
    my ($old_id, $name, $owner_id, $sm_id, $use_bl) = @$row;
    my $team = Bugzilla::Extension::AgileTools::Team->new({name => $name});
    if (defined $team) {
        print "Team '".$name."' exists, skipping.\n";
        next;
    }
    print "Creating team: ".$name."\n";
    $team = Bugzilla::Extension::AgileTools::Team->create({
            name => $name,
            process_id => AGILE_PROCESS_SCRUM,
        });

    # Add members
    my $role;
    my $user = Bugzilla::User->new($owner_id);
    if (defined $user) {
        print "\tAdding owner: ".$user->name."\n";
        $team->add_member($user);
        $role = Bugzilla::Extension::AgileTools::Role->new({name => "Product Owner"});
        $role->add_user_role($team, $user);
    }
    $user = Bugzilla::User->new($sm_id);
    if (defined $user) {
        print "\tAdding scrum master: ".$user->name."\n";
        $team->add_member($user);
        $role = Bugzilla::Extension::AgileTools::Role->new({name => "Scrum Master"});
        $role->add_user_role($team, $user);
    }
    my $members = $dbh->selectcol_arrayref("SELECT userid FROM scrums_teammember ".
        "WHERE teamid = ?", undef, $old_id);
    print "\tAdding members: ";
    foreach my $member_id (@$members) {
        next if ($member_id == $owner_id || $member_id == $sm_id);
        $user = Bugzilla::User->new($member_id);
        print $user->name.", ";
        $team->add_member($user);
    }
    print "\n";

    # Add components to responsibilities
    my $components = $dbh->selectcol_arrayref("SELECT component_id FROM scrums_componentteam ".
        "WHERE teamid = ?", undef, $old_id);
    print "\tAdding components: ";
    foreach my $component_id (@$components) {
        my $component = Bugzilla::Component->new($component_id);
        print $component->name.", ";
        $team->add_responsibility("component", $component);
    }
    print "\n";

    # Copy backlog
    if ($use_bl) {
        my ($bl_id) = $dbh->selectrow_array("SELECT id FROM scrums_sprints ".
            "WHERE team_id = ? AND item_type = ?", undef, ($old_id, 2));
        my $bl_bugs = $dbh->selectcol_arrayref(
            "SELECT bm.bug_id FROM scrums_sprint_bug_map AS bm ".
            "LEFT JOIN scrums_bug_order bo ON bo.bug_id = bm.bug_id ".
            "WHERE sprint_id = ? ORDER BY bo.team", undef, $bl_id);
        print "\tAdding bugs to backlog: ";
        foreach my $bug_id (@$bl_bugs) {
            print $bug_id.", ";
            $team->backlog->add_bug($bug_id);
        }
        print "\n";
    }

    # Copy sprints
    my $sprints = $dbh->selectall_arrayref(
        "SELECT id, start_date, end_date, estimated_capacity FROM scrums_sprints ".
            "WHERE team_id = ? AND item_type = ? ORDER BY start_date",
            undef, ($old_id, 1));
    foreach my $sprint_info (@$sprints) {
        my ($sprint_id, $start_date, $end_date, $capacity) = @$sprint_info;
        print "\tCreating sprint ".$start_date." - ".$end_date."\n";
        my $sprint = Bugzilla::Extension::AgileTools::Sprint->create({
                team_id => $team->id,
                start_date => $start_date,
                end_date => $end_date,
                capacity => $capacity,
            });
        my $sprint_bugs = $dbh->selectcol_arrayref(
            "SELECT bm.bug_id FROM scrums_sprint_bug_map AS bm ".
            "LEFT JOIN scrums_bug_order bo ON bo.bug_id = bm.bug_id ".
            "WHERE sprint_id = ? ORDER BY bo.team", undef, $sprint_id);
        print "\t\tAdding bugs to sprint: ";
        foreach my $bug_id (@$sprint_bugs) {
            print $bug_id.", ";
            $sprint->pool->add_bug($bug_id);
        }
        print "\n";
    }
}
