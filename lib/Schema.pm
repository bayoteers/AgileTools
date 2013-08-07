# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2013 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Schema - Database schema and update functions

=head1 DESCRIPTION

This module contains the database schema and the functions used to update from
older versions of the extension.

=cut

package Bugzilla::Extension::AgileTools::Schema;
use strict;

use Bugzilla::Extension::AgileTools::Backlog;
use Bugzilla::Extension::AgileTools::Constants;
use Bugzilla::Extension::AgileTools::Role;
use Bugzilla::Extension::AgileTools::Team;


use Bugzilla::Constants;

use base qw(Exporter);
our @EXPORT = qw(
    agiletools_db_init
    agiletools_schema_init
    agiletools_schema_update
);

=head1 FUNCTIONS

=over

=item C<agiletools_db_init()>

    Description: Creates the initial objects and fields required in the DB

=cut

sub agiletools_db_init {
    my $dbh = Bugzilla->dbh;

    # Make the old hardcoded user group deletable
    # isactive && !isbuggroups == system group
    # isactive && isbuggroup == admin has enabled it for bugs
    my $groups = $dbh->selectall_hashref(
            "SELECT name, isactive, isbuggroup FROM groups ".
            "WHERE name IN(?,?)", 'name', undef,
            AGILE_USERS_GROUP, NON_HUMAN_GROUP);

    my $old_user_group = $groups->{+AGILE_USERS_GROUP};
    if (defined $old_user_group && $old_user_group->{isactive} &&
                !$old_user_group->{isbuggroup}) {
        $dbh->do("UPDATE groups SET isactive = 0, isbuggroup = 1 WHERE name = ?",
            undef, AGILE_USERS_GROUP);
    }

    # Make the old hardcoded nonhuman group deletable
    my $old_nonhuman = $groups->{+NON_HUMAN_GROUP};
    if (defined $old_nonhuman && $old_nonhuman->{isactive} &&
                !$old_nonhuman->{isbuggroup}) {
        $dbh->do("UPDATE groups SET isactive = 0, isbuggroup = 1 WHERE name = ?",
            undef, NON_HUMAN_GROUP);
    }

    # Create initial team member roles
    if (!Bugzilla::Extension::AgileTools::Role->any_exist()) {
        Bugzilla::Extension::AgileTools::Role->create(
            {
                name => "Product Owner",
                custom => 0,
                can_edit_team => 1,
            }
        );
        Bugzilla::Extension::AgileTools::Role->create(
            {
                name => "Scrum Master",
                custom => 0,
                can_edit_team => 1,
            }
        );
    }
    # Create pool field definitions
    if (!defined Bugzilla::Field->new({name=>"agile_pool.name"})) {
        Bugzilla::Field->create(
            {
                name => "agile_pool.name",
                description => "Pool",
                buglist => 1,
            }
        );
    }
    if (!defined Bugzilla::Field->new({name=>"bug_agile_pool.pool_order"})) {
        Bugzilla::Field->create(
            {
                name => "bug_agile_pool.pool_order",
                description => "Pool Order",
                is_numeric => 1,
                buglist => 1,
            }
        );
    }
    if (!defined Bugzilla::Field->new({name=>"bug_agile_pool.pool_id"})) {
        Bugzilla::Field->create(
            {
                name => "bug_agile_pool.pool_id",
                description => "Pool ID",
                is_numeric => 1,
                buglist => 1,
            }
        );
    }
}

=item C<agiletools_schema_init($schema)>

    Description: Provides the initial DB schema of AgileTools extension
    Params:      $schema - schema hash from db_schema_abstract_schema hook

=cut

sub agiletools_schema_init {
    my $schema = shift;
    # Team information
    $schema->{agile_team} = {
        FIELDS => [
            id => {
                TYPE => 'MEDIUMSERIAL',
                NOTNULL => 1,
                PRIMARYKEY => 1,
            },
            name => {
                TYPE => 'varchar(64)',
                NOTNULL => 1,
            },
            group_id => {
                TYPE => 'INT3',
                REFERENCES => {
                    TABLE => 'groups',
                    COLUMN => 'id',
                },
            },
            process_id => {
                TYPE => 'INT1',
                NOTNULL => 1,
                DEFAULT => 1,
            },
            current_sprint_id => {
                TYPE => 'INT3',
                NOTNULL => 0,
                REFERENCES => {
                    TABLE => 'agile_sprint',
                    COLUMN => 'id',
                    DELETE => 'SET NULL',
                },
            },
            responsibility_query => {
                TYPE => 'MEDIUMTEXT',
                NOTNULL => 1,
                DEFAULT => "''",
            },
        ],
        INDEXES => [
            agile_team_name_idx => {
                FIELDS => ['name'],
                TYPE => 'UNIQUE',
            },
            agile_team_group_id_idx => ['group_id'],
        ],
    };

    # User role definitions
    $schema->{agile_role} = {
        FIELDS => [
            id => {
                TYPE => 'SMALLSERIAL',
                NOTNULL => 1,
                PRIMARYKEY => 1,
            },
            name => {
                TYPE => 'varchar(64)',
                NOTNULL => 1,
            },
            custom => {
                TYPE => 'BOOLEAN',
                NOTNULL => 1,
                DEFAULT => 'TRUE',
            },
            can_edit_team => {
                TYPE => 'BOOLEAN',
                NOTNULL => 1,
                DEFAULT => 'FALSE',
            }
        ],
        INDEXES => [
            'agile_role_name_idx' => {
                FIELDS => ['name'],
                TYPE => 'UNIQUE',
            }
        ],
    };

    # Team - user - role mapping
    $schema->{agile_user_role} = {
        FIELDS => [
            team_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'agile_team',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
            user_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'profiles',
                    COLUMN => 'userid',
                    DELETE => 'CASCADE',
                },
            },
            role_id => {
                TYPE => 'INT2',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'agile_role',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
        ],
        INDEXES => [
            agile_user_role_unique_idx => {
                FIELDS => [qw(team_id user_id role_id)],
                TYPE   => 'UNIQUE',
            },
            agile_user_role_user_idx => ['user_id'],
        ],
    };

    # Bug pool
    $schema->{agile_pool} = {
        FIELDS => [
            id => {
                TYPE => 'MEDIUMSERIAL',
                NOTNULL => 1,
                PRIMARYKEY => 1,
            },
            name => {
                TYPE => 'varchar(64)',
                NOTNULL => 1,
            },
            is_active => {
                TYPE => 'BOOLEAN',
                NOTNULL => 1,
                DEFAULT => 1,
            },
        ],
    };

    # Bug - Pool mapping with bug ordering
    $schema->{bug_agile_pool} = {
        FIELDS => [
            bug_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                PRIMARYKEY => 1,
                REFERENCES => {
                    TABLE => 'bugs',
                    COLUMN => 'bug_id',
                    DELETE => 'CASCADE',
                },
            },
            pool_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'agile_pool',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
            pool_order => {
                TYPE => 'INT3',
            },

        ],
        INDEXES => [
            agile_bug_pool_pool_idx => ['pool_id'],
        ],
    };

    # Scrum Sprint
    $schema->{agile_sprint} = {
        FIELDS => [
            id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                PRIMARYKEY => 1,
                REFERENCES => {
                    TABLE => 'agile_pool',
                    COLUMN => 'id',
                },
            },
            start_date => {
                TYPE => 'DATETIME',
                NOTNULL => 1,
            },
            end_date => {
                TYPE => 'DATETIME',
                NOTNULL => 1,
            },
            team_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'agile_team',
                    COLUMN => 'id',
                },
            },
            capacity => {
                TYPE => 'decimal(7,2)',
                NOTNULL => 1,
                DEFAULT => 0,
            },
        ],
        INDEXES => [
        ],
    };

    # Backlog
    $schema->{agile_backlog} = {
        FIELDS => [
            pool_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                PRIMARYKEY => 1,
                REFERENCES => {
                    TABLE => 'agile_pool',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
            team_id => {
                TYPE => 'INT3',
                NOTNULL => 0,
                REFERENCES => {
                    TABLE => 'agile_team',
                    COLUMN => 'id',
                    DELETE => 'SET NULL',
                },
            },
        ],
        INDEXES => [
        ],
    };
}

=item C<agiletools_schema_update()>

    Description: Updates the AgileTools DB schema from older versions. Called
                 from install_update_db hook.

=cut

sub agiletools_schema_update {
    my $dbh = Bugzilla->dbh;
    # Add new columns or update changed

    # VERSION 0.02
    $dbh->bz_add_column('agile_team', 'current_sprint_id', {
        TYPE => 'INT3', NOTNULL => 0,
    });
    $dbh->bz_add_column('agile_pool', 'is_active', {
        TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 1,
    });

    # VERSION 0.03
    $dbh->bz_add_column('agile_sprint', 'committed', {
        TYPE => 'BOOLEAN', NOTNULL => 1, DEFAULT => 0,
    });
    $dbh->bz_add_column('agile_sprint', 'items_on_commit', {
        TYPE => 'INT2', NOTNULL => 1, DEFAULT => 0,
    });
    $dbh->bz_add_column('agile_sprint', 'items_on_close', {
        TYPE => 'INT2', NOTNULL => 1, DEFAULT => 0,
    });
    $dbh->bz_add_column('agile_sprint', 'resolved_on_close', {
        TYPE => 'INT2', NOTNULL => 1, DEFAULT => 0,
    });
    $dbh->bz_add_column('agile_sprint', 'estimate_on_commit', {
        TYPE => 'decimal(7,2)', NOTNULL => 1, DEFAULT => 0,
    });
    $dbh->bz_add_column('agile_sprint', 'effort_on_commit', {
        TYPE => 'decimal(7,2)', NOTNULL => 1, DEFAULT => 0,
    });
    $dbh->bz_add_column('agile_sprint', 'estimate_on_close', {
        TYPE => 'decimal(7,2)', NOTNULL => 1, DEFAULT => 0,
    });
    $dbh->bz_add_column('agile_sprint', 'effort_on_close', {
        TYPE => 'decimal(7,2)', NOTNULL => 1, DEFAULT => 0,
    });

    # Multiple backlogs per team update
    if ($dbh->bz_column_info('agile_team', 'backlog_id')) {
        print "Migrating team backlogs...\n";
        my $insert = $dbh->prepare(
                "INSERT INTO agile_backlog (pool_id, team_id) VALUES (?, ?)");
        my $fetch = $dbh->prepare("SELECT id, backlog_id FROM agile_team ".
                "WHERE backlog_id IS NOT NULL");
        $fetch->execute();
        while (my ($team_id, $backlog_id) = $fetch->fetchrow_array()) {
            $insert->execute($backlog_id, $team_id);
        }
        $dbh->bz_drop_fk('agile_team', 'backlog_id');
        $dbh->bz_drop_column('agile_team', 'backlog_id');
    }

    # Responsibilities as freeform search update
    $dbh->bz_add_column('agile_team', 'responsibility_query', {
        TYPE => 'MEDIUMTEXT', NOTNULL => 1, DEFAULT => "''"
    });
    if (defined $dbh->bz_column_info('agile_team_keyword', 'team_id')) {
        migrate_team_responsibilities();
    }

    if ($dbh->bz_column_info('scrums_team', 'id')) {
        my %answer = %{Bugzilla->installation_answers};
        my $mode = $answer{MIGRATE_SCRUMS};
        # Skip this in non interactive mode if answer not given
        $mode ||= Bugzilla->installation_mode == INSTALLATION_MODE_NON_INTERACTIVE ?
            's' : undef;
        if (!$mode) {
            print "You seem to have old BAYOT Scrum teams in the database.\n".
            "Do you wish to:\n".
            "m - Migrate the teams with backlogs and sprints to AgileTools\n".
            "d - Delete the old teams (You should select this if you have used ".
                "migrate_bayot_scrums.pl sript earlier)\n".
            "s - Skip this for now\n >> ";
        }
        while (!$mode) {
            $mode = <STDIN>;
            chomp $mode;
            if ($mode eq 'm') {
                migrate_bayot_scrums();
                delete_bayot_scrums();
            } elsif ($mode eq 'd') {
                delete_bayot_scrums();
            } elsif ($mode ne 's') {
                undef $mode;
            }
        }
    }
}

# Migration team data from old BAYOT Scrums extension to AgileTools.
#
# Copies
#  - all teams from old DB schema
#  - members from old teams and sets product owner and scrum master roles
#  - team resposibility components
#  - bugs in team backlog for those teams which used backlog
#  - team sprints and bugs in the sprints

sub migrate_bayot_scrums {
    print "Migrating Scrums teams to AgileTools...\n";
    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();

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
        # Add components to responsibilities
        my $components = $dbh->selectcol_arrayref("SELECT component_id FROM scrums_componentteam ".
            "WHERE teamid = ?", undef, $old_id);
        print "\tResponsibility components: ";
        my $query = '?';
        foreach my $component_id (@$components) {
            my $component = Bugzilla::Component->new($component_id);
            print $component->product->name.":".$component->name.", ";
            $query .= "product=".$component->product->name."&";
            $query .= "component=".$component->name."&";
        }
        print "\n";
        $team = Bugzilla::Extension::AgileTools::Team->create({
                name => $name,
                process_id => AGILE_PROCESS_SCRUM,
                responsibility_query => $query,
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

        # Copy backlog
        if ($use_bl) {
            my $backlog = Bugzilla::Extension::AgileTools::Backlog->create({
                name => $team->name." backlog",
                team_id => $team->id,
                });
            my ($bl_id) = $dbh->selectrow_array("SELECT id FROM scrums_sprints ".
                "WHERE team_id = ? AND item_type = ?", undef, ($old_id, 2));
            my $bl_bugs = $dbh->selectcol_arrayref(
                "SELECT bm.bug_id FROM scrums_sprint_bug_map AS bm ".
                "LEFT JOIN scrums_bug_order bo ON bo.bug_id = bm.bug_id ".
                "WHERE sprint_id = ? ORDER BY bo.team", undef, $bl_id);
            print "\tAdding bugs to backlog: ";
            foreach my $bug_id (@$bl_bugs) {
                print $bug_id.", ";
                $backlog->pool->add_bug($bug_id);
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
    $dbh->bz_commit_transaction();
}

# Removes the old Scrums tables
sub delete_bayot_scrums {
    print "Removing old Scrums tables...\n";
    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();
    # Remove foreign keys
    $dbh->bz_drop_fk('scrums_team','owner');
    $dbh->bz_drop_fk('scrums_team','scrum_master');
    $dbh->bz_drop_fk('scrums_teammember','teamid');
    $dbh->bz_drop_fk('scrums_teammember','userid');
    $dbh->bz_drop_fk('scrums_componentteam','teamid');
    $dbh->bz_drop_fk('scrums_componentteam','component_id');
    $dbh->bz_drop_fk('scrums_sprints','team_id');
    $dbh->bz_drop_fk('scrums_sprint_estimate','sprintid');
    $dbh->bz_drop_fk('scrums_sprint_estimate','userid');
    $dbh->bz_drop_fk('scrums_sprint_bug_map','bug_id');
    $dbh->bz_drop_fk('scrums_sprint_bug_map','sprint_id');
    # Drop tables
    # Leaving scrums_releases, scrums_flagtype_release_map and scrums_bug_order
    # unmodified as there isn't anything to migrate those into
    $dbh->bz_drop_table('scrums_team');
    $dbh->bz_drop_table('scrums_teammember');
    $dbh->bz_drop_table('scrums_componentteam');
    $dbh->bz_drop_table('scrums_sprints');
    $dbh->bz_drop_table('scrums_sprint_estimate');
    $dbh->bz_drop_table('scrums_sprint_bug_map');

    # Remove the field definition
    $dbh->do(
        "DELETE FROM fielddefs WHERE name = 'scrums_sprint_bug_map.sprint_id'");
    $dbh->bz_commit_transaction();
}

sub migrate_team_responsibilities {
    print "Migrating old team responsibilities...\n";
    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();

    my %queries;

    my $keywords = $dbh->selectall_arrayref("
        SELECT agile_team_keyword.team_id, keyworddefs.name
          FROM agile_team_keyword
     LEFT JOIN keyworddefs ON agile_team_keyword.keyword_id = keyworddefs.id");
    foreach (@$keywords) {
        my ($team_id, $keyword) = @$_;
        $queries{$team_id} ||= '?';
        $queries{$team_id} .= "keywords=$keyword&";
    }
    my $components = $dbh->selectall_arrayref("
        SELECT agile_team_component.team_id, components.name
          FROM agile_team_component
     LEFT JOIN components ON agile_team_component.component_id = components.id");
    foreach (@$components) {
        my ($team_id, $component) = @$_;
        $queries{$team_id} ||= '?';
        $queries{$team_id} .= "component=$component&";
    }

    for my $team (Bugzilla::Extension::AgileTools::Team->get_all) {
        $team->set_all({responsibility_query => $queries{$team->id} || '?'});
        $team->update();
    }
    $dbh->bz_drop_table('agile_team_keyword');
    $dbh->bz_drop_table('agile_team_component');
    $dbh->bz_commit_transaction();
}

1;

__END__

=back
