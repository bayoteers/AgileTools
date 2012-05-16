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

package Bugzilla::Extension::AgileTools;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla::Error;
use Bugzilla::Constants;
use Bugzilla::Field;


use Bugzilla::Extension::AgileTools::Constants;
use Bugzilla::Extension::AgileTools::Pool;
use Bugzilla::Extension::AgileTools::Role;
use Bugzilla::Extension::AgileTools::Team;
use Bugzilla::Extension::AgileTools::Util;

use JSON;

use Data::Dumper;

our $VERSION = '0.01';

my %template_handlers;
my %page_handlers;

# Add a handler for the given template.
sub _add_template_handler {
    my ($name, $sub) = @_;
    push @{$template_handlers{$name} ||= []}, $sub;
}

sub _add_page_handler {
    my ($name, $sub) = @_;
    push @{$page_handlers{$name} ||= []}, $sub;
}

#################
# Page handlers #
#################

_add_page_handler("agiletools/teams.html", sub {
    my ($vars) = @_;
    my $cgi = Bugzilla->cgi;
    if ($cgi->param("action") eq "remove") {
        ThrowUserError("agile_team_manage_denied")
            unless user_can_manage_teams;
        my $team = Bugzilla::Extension::AgileTools::Team->check({
                id => $cgi->param("team_id")});
        $vars->{team} = {name=>$team->name};
        $team->remove_from_db();
        $vars->{message} = "agile_team_removed";
    }
    $vars->{agile_teams} = Bugzilla::Extension::AgileTools::Team->match();
    $vars->{can_manage_teams} = user_can_manage_teams();
});

_add_page_handler("agiletools/team.html", sub {
    my ($vars) = @_;

    my $cgi = Bugzilla->cgi;
    my $team;
    if ($cgi->param("action") eq "create") {
        ThrowUserError("agile_team_manage_denied")
            unless user_can_manage_teams;
        $team = Bugzilla::Extension::AgileTools::Team->create({
                name => $cgi->param("name"),
                process_id => $cgi->param("process_id"),
            });
        $vars->{message} = "agile_team_created";
    } else {
        my $id = $cgi->param("team_id");
        $team = Bugzilla::Extension::AgileTools::Team->check({id => $id});
    }

    $vars->{processes} = AGILE_PROCESS_NAMES;
    $vars->{team} = $team;
    $vars->{roles} = Bugzilla::Extension::AgileTools::Role->match();

    # TODO these values are probably cached already
    $vars->{keywords} = Bugzilla::Keyword->match();
    my @components;
    foreach my $product (Bugzilla::Product->get_all()) {
        next unless Bugzilla->user->can_see_product($product->name);
        foreach my $component (@{$product->components}) {
            push(@components, {
                    id => $component->id,
                    name => $product->name . " : " . $component->name,
                });
        }
    }
    $vars->{components} = \@components;
    $team->roles;
    $team->components;
    $team->keywords;
    $vars->{team_json} = JSON->new->utf8->convert_blessed->encode($team);
});

_add_page_handler("agiletools/create_team.html", sub {
    my ($vars) = @_;
    $vars->{processes} = AGILE_PROCESS_NAMES;
});

#########
# Hooks #
#########

sub page_before_template {
    my ($self, $params) = @_;
    my $page_id = $params->{page_id};
    if ($page_id =~ /^agiletools\//) {
        ThrowUserError("agile_access_denied")
            unless Bugzilla->user->in_group(AGILE_USERS_GROUP);
    }
    my $vars = $params->{vars};

    my $subs = $page_handlers{$page_id};
    for my $sub (@{$subs || []}) {
        $sub->($vars);
    }
}

sub template_before_process {
    my ($self, $params) = @_;

    my $subs = $template_handlers{$params->{file}};
    for my $sub (@{$subs || []}) {
        $sub->($params);
    }
}

sub bb_common_links {
    my ($self, $args) = @_;
    return unless Bugzilla->user->in_group(AGILE_USERS_GROUP);
    $args->{links}->{teams} = [
        {
            text => "Teams",
            href => "page.cgi?id=agiletools/teams.html",
            priority => 10
        }
    ];
}

sub buglist_columns {
    my ($self, $args) = @_;
    my $columns = $args->{columns};
    $columns->{"agile_pool.name"} = {
        name => "COALESCE(agile_pool.name,'')",
        title => "Pool" };
    $columns->{"bug_agile_pool.pool_order"} = {
        name => "COALESCE(bug_agile_pool.pool_order, -1)",
        title => "Pool order" };
    $columns->{"bug_agile_pool.pool_id"} = {
        name => "COALESCE(bug_agile_pool.pool_id, -1)",
        title => "Pool ID" };
}

sub buglist_column_joins {
    my ($self, $args) = @_;
    my $joins = $args->{column_joins};
    $joins->{"agile_pool.name"} = {
        table => "bug_agile_pool",
        as => "bug_agile_pool",
        then_to => {
            as => "agile_pool",
            table => "agile_pool",
            from => "bug_agile_pool.pool_id",
            to => "id",
        },
    };
    $joins->{"bug_agile_pool.pool_order"} = {
        table => "bug_agile_pool",
        as => "bug_agile_pool",
    };
    $joins->{"bug_agile_pool.pool_id"} = {
        table => "bug_agile_pool",
        as => "bug_agile_pool",
    };
}



sub install_update_db {
    my ($self, $args) = @_;
    # Make sure agiletools user group exists
    if (!defined Bugzilla::Group->new({name => AGILE_USERS_GROUP})) {
        Bugzilla::Group->create(
            {
                name => AGILE_USERS_GROUP,
                description => "Users allowed to use AgileTools",
                userregexp => ".*",
            }
        );
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
    # Create pool filed definitions
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

sub search_operator_field_override {
    my ($self, $args) = @_;
    my $operators = $args->{'operators'};
    my $search = $args->{'search'};

    $operators->{'agile_pool.name'}->{_default} = sub {
        _add_agile_pool_join($search, @_)
    };
    $operators->{'bug_agile_pool.pool_order'}->{_default} = sub {
        _add_bug_agile_pool_join($search, @_)
    };
    $operators->{'bug_agile_pool.pool_id'}->{_default} = sub {
        _add_bug_agile_pool_join($search, @_)
    };
}

sub _add_agile_pool_join {
    my $search = shift;
    my ($invocant, $args) = @_;
    my ($joins) = @$args{qw(joins)};
    if(! grep $_->{table} eq 'bug_agile_pool', @$joins) {
        my $join = {
            table => "bug_agile_pool",
            as => "bug_agile_pool",
            then_to => {
                table => "agile_pool",
                as => "agile_pool",
                from => "bug_agile_pool.pool_id",
                to => "id",
            },
        };
        push(@$joins, $join);
    }
    $args->{full_field} = "COALESCE($args->{full_field}, '')";
    $search->_do_operator_function($args);
}

sub _add_bug_agile_pool_join {
    my $search = shift;
    my ($invocant, $args) = @_;
    my ($joins) = @$args{qw(joins)};
    if(! grep $_->{table} eq 'bug_agile_pool', @$joins) {
        my $join = {
            table => "bug_agile_pool",
            as => "bug_agile_pool",
        };
        push(@$joins, $join);
    }
    $args->{full_field} = "COALESCE($args->{full_field}, -1)";
    $search->_do_operator_function($args);
}

sub db_schema_abstract_schema {
    my ($self, $args) = @_;
    my $schema = $args->{schema};

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
                DEFAULT => 0,
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
        ],
    };

    # Bug - Pool mapping with bug ordering
    $schema->{bug_agile_pool} = {
        FIELDS => [
            bug_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
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
            agile_bug_pool_uniq_idx => {
                FIELDS => ['pool_id', 'bug_id'],
                TYPE => 'UNIQUE',
            },
        ],
    };

    # Scrum Sprint
    $schema->{agile_sprint} = {
        FIELDS => [
            id => {
                TYPE => 'MEDIUMSERIAL',
                NOTNULL => 1,
                PRIMARYKEY => 1,
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
            pool_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'agile_pool',
                    COLUMN => 'id',
                },
            },
            capacity => {
                TYPE => 'INT2',
                NOTNULL => 1,
                DEFAULT => 0,
            },
        ],
        INDEXES => [
        ],
    };

    # Scrum Backlog
    $schema->{agile_backlog} = {
        FIELDS => [
            id => {
                TYPE => 'MEDIUMSERIAL',
                NOTNULL => 1,
                PRIMARYKEY => 1,
            },
            team_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'agile_team',
                    COLUMN => 'id',
                    DELETE => 'CASCADE',
                },
            },
            pool_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'agile_pool',
                    COLUMN => 'id',
                },
            },
        ],
        INDEXES => [
        ],
    };
}

sub webservice {
    my ($self, $args) = @_;
    $args->{dispatch}->{'Agile'} =
        "Bugzilla::Extension::AgileTools::WebService";
    $args->{dispatch}->{'Agile.Team'} =
        "Bugzilla::Extension::AgileTools::WebService::Team";
    $args->{dispatch}->{'Agile.Sprint'} =
        "Bugzilla::Extension::AgileTools::WebService::Sprint";
    $args->{dispatch}->{'Agile.Pool'} =
        "Bugzilla::Extension::AgileTools::WebService::Pool";
}

__PACKAGE__->NAME;
