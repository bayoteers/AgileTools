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

use Bugzilla::Extension::AgileTools::Constants;

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
            backlog_id => {
                TYPE => 'INT3',
                NOTNULL => 0,
                REFERENCES => {
                    TABLE => 'agile_pool',
                    COLUMN => 'id',
                    DELETE => 'SET NULL',
                },
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
        ],
        INDEXES => [
            agile_team_name_idx => {
                FIELDS => ['name'],
                TYPE => 'UNIQUE',
            },
            agile_team_group_id_idx => ['group_id'],
        ],
    };

    # Team component responsibilities
    $schema->{agile_team_component} = {
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
            component_id => {
                TYPE => 'INT2',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'components',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
        ],
        INDEXES => [
            agile_team_component_unique_idx => {
                FIELDS => ['team_id', 'component_id'],
                TYPE => 'UNIQUE',
            },
            agile_team_component_team_id_idx => ['team_id'],
        ],
    };

    # Team keyword responsibilities
    $schema->{agile_team_keyword} = {
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
            keyword_id => {
                TYPE => 'INT2',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'keyworddefs',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
        ],
        INDEXES => [
            agile_team_keyword_unique_idx => {
                FIELDS => ['team_id', 'keyword_id'],
                TYPE => 'UNIQUE',
            },
            agile_team_keyword_team_id_idx => ['team_id'],
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
}

1;

__END__

=back
