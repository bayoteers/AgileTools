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

# This code for this is in ./extensions/AgileTools/lib/Util.pm
use Bugzilla::Extension::AgileTools::Util;
use Bugzilla::Extension::AgileTools::Constants;
use Bugzilla::Extension::AgileTools::Team;
use Bugzilla::Extension::AgileTools::Role;

use JSON;

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

_add_page_handler("agiletools/index.html", sub {
    my ($vars) = @_;
    $vars->{agile_teams} = Bugzilla::Extension::AgileTools::Team->match();
});

_add_page_handler("agiletools/team.html", sub {
    my ($vars) = @_;

    my $cgi = Bugzilla->cgi;
    my $id = $cgi->param("team_id");
    my $team = new Bugzilla::Extension::AgileTools::Team($id);
    ThrowUserError('object_does_not_exist', {
            id => $id, class => 'AgileTools::Team' })
        unless defined $team;
    $vars->{team} = $team;

    $team->roles;
    $team->components;
    $team->keywords;
    $vars->{team_json} = JSON->new->utf8->convert_blessed->encode($team);
});


#########
# Hooks #
#########

sub page_before_template {
    my ($self, $params) = @_;
    my $page_id = $params->{page_id};
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
    $args->{links}->{AgileTools} = [
        {
            text => "AgileTools",
            href => "page.cgi?id=agiletools/index.html",
            priority => 10
        }
    ];
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
}

sub db_schema_abstract_schema {
    my ($self, $args) = @_;
    my $schema = $args->{schema};

    # Team information
    $schema->{agile_teams} = {
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
            agile_teams_name_idx => {
                FIELDS => ['name'],
                TYPE => 'UNIQUE',
            },
            agile_teams_group_id_idx => ['group_id'],
        ],
    };

    # Team component responsibilities
    $schema->{agile_team_component_map} = {
        FIELDS => [
            team_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'agile_teams',
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
    $schema->{agile_team_keyword_map} = {
        FIELDS => [
            team_id => {
                TYPE => 'INT3',
                NOTNULL => 1,
                REFERENCES => {
                    TABLE => 'agile_teams',
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
    $schema->{agile_roles} = {
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
            'agile_roles_name_idx' => {
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
                    TABLE => 'agile_teams',
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
                    TABLE => 'agile_roles',
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
}

sub webservice {
    my ($self, $args) = @_;
    $args->{dispatch}->{'Agile'} =
        "Bugzilla::Extension::AgileTools::WebService";
    $args->{dispatch}->{'Agile.Team'} =
        "Bugzilla::Extension::AgileTools::WebService::Team";
}

__PACKAGE__->NAME;
