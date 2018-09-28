# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

package Bugzilla::Extension::AgileTools;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla::Bug qw(LogActivityEntry);
use Bugzilla::Config qw(SetParam write_params);
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Field;
use Bugzilla::Util qw(detaint_natural);

use Bugzilla::Extension::AgileTools::Burn;
use Bugzilla::Extension::AgileTools::Constants;
use Bugzilla::Extension::AgileTools::Pages;
use Bugzilla::Extension::AgileTools::Pages::Team;
use Bugzilla::Extension::AgileTools::Pages::Scrum;
use Bugzilla::Extension::AgileTools::Pool;
use Bugzilla::Extension::AgileTools::Role;
use Bugzilla::Extension::AgileTools::Schema;
use Bugzilla::Extension::AgileTools::Team;
use Bugzilla::Extension::AgileTools::Util;

use JSON;

our $VERSION = '0.03';

my %template_handlers;

use constant PAGE_HANDLERS => (
    [qr/^agiletools\/([^\/]+)\./, 'Pages'],
    [qr/^agiletools\/scrum\/([^\/.]+)\./, 'Pages::Scrum'],
    [qr/^agiletools\/team\/([^\/.]+)\./, 'Pages::Team'],
);

###################
# Template handlers
###################

# Helper to add a handler for the given template.
sub _add_template_handler {
    my ($name, $sub) = @_;
    push @{$template_handlers{$name} ||= []}, $sub;
}

_add_template_handler('list/list-burn.html.tmpl', sub {
    my ($vars) = @_;
    my $cgi = Bugzilla->cgi;
    my $user = Bugzilla->user;
    my @bug_ids = map {$_->{bug_id}} @{$vars->{bugs}};

    my $start = $cgi->param("burn_start") || undef;
    ThrowUserError("invalid_parameter",
        {name=>"burn_start", err => "Date format should be YYYY-MM-DD"})
        if (defined $start && ! ($start =~ /^\d\d\d\d-\d\d-\d\d$/));

    my $end = $cgi->param("burn_end") || undef;
    ThrowUserError("invalid_parameter",
        {name=>"burn_end", err => "Date format should be YYYY-MM-DD"})
        if (defined $end && ! ($end =~ /^\d\d\d\d-\d\d-\d\d$/));
    my $data = get_burndata(\@bug_ids, $start, $end, $user->is_timetracker);
    $vars->{burn_type} = $user->is_timetracker && $cgi->param("burn_type") || 'items';
    $vars->{burn_start} = $start;
    $vars->{burn_end} = $end;
    $vars->{burn_json} = encode_json($data);
    $vars->{burn_is_timetracker} = $user->is_timetracker;
});

sub active_pools_to_vars {
    my $vars = shift;
    Bugzilla->login(LOGIN_OPTIONAL);
    if (user_in_agiletools_group()) {
        $vars->{active_pools} = Bugzilla::Extension::AgileTools::Pool->match(
            {is_active => 1});
    }
}

_add_template_handler("bug/edit.html.tmpl", \&active_pools_to_vars);
_add_template_handler("list/edit-multiple.html.tmpl", \&active_pools_to_vars);
_add_template_handler("bug/create/create.html.tmpl", \&active_pools_to_vars);

_add_template_handler("bug/field-help.none.tmpl", sub {
    return unless Bugzilla->params->{agile_use_points};
    # This is done here instead of hook/global/field-descs-end.none.tmpl, so
    # that field names are reflected also in the help strings
    my $vars = shift;
    $vars->{vars}->{field_descs}->{actual_time} = "Actual Points";
    $vars->{vars}->{field_descs}->{work_time} = "Points Worked";
    $vars->{vars}->{field_descs}->{remaining_time} = "Points Left";
});


#######################################
# Page and template processing handlers
#######################################

sub page_before_template {
    my ($self, $params) = @_;
    my $page_id = $params->{page_id};
    return unless ($page_id =~ /^agiletools\//);

    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);

    foreach (PAGE_HANDLERS()) {
        my($rex, $mod) = @$_;
        if($page_id =~ /$rex/) {
            my $handler = $1;
            $mod = "Bugzilla::Extension::AgileTools::$mod";
            my $sub = $mod->can($handler);
            if ($sub) {
                $sub->($params->{vars});
                last;
            }
        }
    }
}

sub template_before_process {
    my ($self, $params) = @_;
    my $subs = $template_handlers{$params->{file}};
    for my $sub (@{$subs || []}) {
        $sub->($params->{vars});
    }
}

#############################
# BayotBase page header links
#############################

sub bb_common_links {
    my ($self, $args) = @_;
    return unless user_in_agiletools_group();
    $args->{links}->{agile_teams} = [
        {
            text => "All teams",
            href => "page.cgi?id=agiletools/team/list.html",
            priority => 11
        }
    ];
    $args->{links}->{agile_summary} = [
        {
            text => "My teams",
            href => "page.cgi?id=agiletools/team/list.html&user_teams=1",
            priority => 10
        }
    ];
}

sub bb_group_params {
    my ($self, $args) = @_;
    push(@{$args->{group_params}}, 'agile_user_group', 'agile_nonhuman_group');
}

############################
# Additional buglist columns
############################

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

#################################################
# Table joins required for the additional columns
#################################################

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

##########################################
# Additional operations when creating bugs
##########################################

sub object_end_of_create{
    my ($self, $args) = @_;
    my $class  = $args->{'class'};
    my $object = $args->{'object'};

    my $cgi = Bugzilla->cgi;
    my $pool_id = $cgi->param('pool_id');
    if ($object->isa("Bugzilla::Bug")) {
        if ($pool_id) {
            my $pool = Bugzilla::Extension::AgileTools::Pool->check(
                {id => $pool_id}
            );
            $pool->add_bug($object);
        }
    }
}

##########################################
# Additional operations when updating bugs
##########################################

# Helper to determine which bugs are being updated by user
# TODO Move this to BayotBase
sub _bugs_being_updated {
    my $cache = Bugzilla->request_cache;
    if (!defined $cache->{bugs_being_updated}) {
        my $params = Bugzilla->input_params;
        my @ids;
        # Change several
        @ids = map {$_ =~ /^id_([0-9]*)/} grep(/^id_/, keys %$params);
        unless (@ids) {
            if (defined $params->{ids}) {
                # Webservice
                @ids = @{$params->{ids}} if defined ;
            } elsif (defined $params->{id}) {
                # Single bug
                @ids = ($params->{id});
            }
        }
        $cache->{bugs_being_updated} = \@ids;
    }
    return @{$cache->{bugs_being_updated}};
}

sub bug_end_of_update {
    my ($self, $args) = @_;

    my ($bug, $old_bug, $changes, $timestamp) = @$args{
        qw(bug old_bug changes timestamp)};
    my $user = Bugzilla->user;
    my $cgi = Bugzilla->cgi;

    if (my $status_change = $changes->{'bug_status'}) {
        my $old_status = new Bugzilla::Status({ name => $status_change->[0] });
        my $new_status = new Bugzilla::Status({ name => $status_change->[1] });
        if (!$new_status->is_open && $old_status->is_open) {
            # Bug is being closed
            my $non_human = Bugzilla->params->{agile_nonhuman_group};
            if ((!Bugzilla->params->{agile_check_time_only_sprint}
                  || ($bug->pool && $bug->pool->is_sprint))
                && (!$non_human || !$user->in_group($non_human)))
            {
                # Check that actual time is set if it is required for the
                # severity and resolution
                my $check_severity = grep {$bug->bug_severity eq $_}
                        @{Bugzilla->params->{"agile_check_time_severity"}};
                my $check_resolution = grep {$bug->resolution eq $_}
                        @{Bugzilla->params->{"agile_check_time_resolution"}};
                if ($check_severity && $check_resolution) {
                    ThrowUserError("agile_actual_time_required")
                        if ($bug->actual_time == 0);
                }
            }

            # Remove closed bug from any backlog
            if ($bug->pool && $bug->pool->is_backlog) {
                $bug->pool->remove_bug($bug);
                $changes->{'bug_agile_pool.pool_id'} = [
                        $old_bug->pool_id, $bug->pool_id ];
                # Activity log has been writen at this point so we need to
                # add this entry
                LogActivityEntry($bug->id, 'bug_agile_pool.pool_id',
                        $old_bug->pool_id, $bug->pool_id,
                        $user->id, $timestamp);
            }
        }
    }
}

sub bug_check_can_change_field {
    my ($self, $params) = @_;
    my ($bug, $field, $new_value, $priv_results) = @$params{
        qw(bug field new_value priv_results)};
    if ($field eq 'estimated_time') {
        # Check if user is allowed to edit the original estimates of items in
        # sprint
        if(!user_can_change_estimated_time($bug)) {
            push(@$priv_results, PRIVILEGES_REQUIRED_EMPOWERED);
        }
    }
    if ($field eq 'pool_id') {
        # User needs to be logged in and in agile_user_group to change bug pool
        my $user = Bugzilla->login(LOGIN_OPTIONAL);
        if (!user_in_agiletools_group()) {
            push(@$priv_results, PRIVILEGES_REQUIRED_EMPOWERED);
        }
    }
}

sub object_before_set {
    my ($self, $args) = @_;
    my ($obj, $field, $value) = @$args{qw(object field value)};
    if ($field eq 'estimated_time' && $obj->isa('Bugzilla::Bug')) {
        if ($obj->estimated_time != $value
            && !user_can_change_estimated_time($obj))
        {
            ThrowUserError('agile_estimated_time_locked');
        }
    }
}


sub object_end_of_set_all {
    my ($self, $args) = @_;
    my $bug = $args->{object};
    return unless Bugzilla->usage_mode == USAGE_MODE_BROWSER;
    return unless $bug->isa("Bugzilla::Bug");
    # If we are editing bug via browser, we need to manually set pool_id,
    # because it is not included in set_all in process_bug.cgi
    my $cgi = Bugzilla->cgi;
    my $dontchange = $cgi->param('dontchange') || '';
    my $pool_id = $cgi->param('pool_id');
    return if (!defined $pool_id || $pool_id eq $dontchange);
    $bug->set_pool_id($pool_id);
}

sub object_end_of_update {
    my ($self, $args) = @_;
    my ($obj, $old_obj, $changes) = @$args{qw(object old_object changes)};

    if ($obj->isa("Bugzilla::Bug")) {
        # Update remaining time if estimated time is changed
        if (defined $changes->{estimated_time} &&
            ! defined $changes->{remaining_time})
        {
            my ($old, $new) = @{$changes->{estimated_time}};
            if ($obj->{remaining_time} != $new)
            {
                Bugzilla->dbh->do("UPDATE bugs ".
                                     "SET remaining_time = ? ".
                                   "WHERE bug_id = ?",
                        undef, $new, $obj->id);
                $changes->{remaining_time} = [$old_obj->{remaining_time}, $new];
            }
        }

        # Update pool_id and pool_order if they have been changed
        if ($obj->pool_id != $old_obj->pool_id) {
            if ($obj->pool_id) {
                $obj->pool->add_bug($obj,
                        $obj->{pool_order_set} ? $obj->pool_order : undef);
            } elsif ($old_obj->pool_id) {
                $old_obj->pool->remove_bug($obj);
            }
            $changes->{'bug_agile_pool.pool_id'} = [ $old_obj->pool_id,
                    $obj->pool_id ];
        } elsif ($obj->pool_order != $old_obj->pool_order) {
            $obj->pool->add_bug($obj, $obj->pool_order);
        }
    }

    # Update params if group names change
    if ($obj->isa("Bugzilla::Group") && defined $changes->{name}) {
        if (Bugzilla->params->{agile_user_group} &&
                Bugzilla->params->{agile_user_group} eq $old_obj->name) {
            SetParam('agile_user_group', $obj->name);
            write_params();
        }
        if (Bugzilla->params->{agile_nonhuman_group} &&
                Bugzilla->params->{agile_nonhuman_group} eq $old_obj->name) {
            SetParam('agile_nonhuman_group', $obj->name);
            write_params();
        }
    }
}

################################################
# Search operators for the additional bug fields
################################################

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

# Table join required for Pool name
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

# Table join required for Pool id and order
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

#################
# Database schema
#################

sub db_schema_abstract_schema {
    my ($self, $args) = @_;
    agiletools_schema_init($args->{schema});
}

##########################################
# Database updates performed in checksetup
##########################################

sub install_update_db {
    my ($self, $args) = @_;
    agiletools_schema_update();
    agiletools_db_init();
}

###############
# Sanity checks
###############
sub _get_bad_pools {
    my $dbh = Bugzilla->dbh;

    my $pool_ids = $dbh->selectcol_arrayref(
        'SELECT id FROM agile_pool');

    my $sth = $dbh->prepare(
        'SELECT pool_order FROM bug_agile_pool WHERE pool_id = ? '.
        'ORDER BY pool_order ASC');

    my %bad_pools ;
    for my $pool_id (@$pool_ids) {
        $sth->execute($pool_id);
        my $expected = 1;
        my @gaps;
        while (my ($real) = $sth->fetchrow_array) {
            if ($real != $expected) {
                push(@gaps, {start=> $expected, end=> $real});
                $expected = $real + 1;
            } else {
                $expected += 1;
            }
        }
        if (@gaps) {
            $bad_pools{$pool_id} = \@gaps;
        }
    }
    return \%bad_pools;
}

sub sanitycheck_repair {
    my ($self, $args) = @_;

    my $cgi = Bugzilla->cgi;
    my $dbh = Bugzilla->dbh;
    my $status = $args->{'status'};
    if ($cgi->param('agiletools_repair_pool_order')) {
        $status->('agiletools_repair_pool_order_start');

        my $fix_gap = $dbh->prepare(
            'UPDATE bug_agile_pool '.
            'SET pool_order = pool_order - ? '.
            'WHERE pool_id = ? AND pool_order > ?');
        my $get_dupes = $dbh->prepare(
            'SELECT bug_id FROM bug_agile_pool '.
            'WHERE pool_id = ? AND pool_order = ?');
        my $make_room = $dbh->prepare(
            'UPDATE bug_agile_pool '.
            'SET pool_order = pool_order + ? '.
            'WHERE pool_id = ? AND pool_order > ?');
        my $fix_dupe = $dbh->prepare(
            'UPDATE bug_agile_pool '.
            'SET pool_order = pool_order + ? '.
            'WHERE pool_id = ? AND bug_id = ?');

        my $bad_pools = _get_bad_pools();
        for my $pool_id (keys %$bad_pools){
            for my $gap (reverse @{$bad_pools->{$pool_id}}) {
                my $change = $gap->{end} - $gap->{start};
                if ($change > 0) {
                    $fix_gap->execute($change, $pool_id, $gap->{start});
                } elsif ($change == -1) {
                    # Duplicate values
                    $get_dupes->execute($pool_id, $gap->{end});
                    my @dupes = map {$_->[0]} @{$get_dupes->fetchall_arrayref};
                    shift @dupes;
                    $make_room->execute(scalar @dupes, $pool_id, $gap->{end});
                    $change = 1;
                    for my $bug_id (@dupes) {
                        $fix_dupe->execute($change, $pool_id, $bug_id);
                    }
                } else {
                    $status->('agiletools_repair_pool_order_weird_alert',
                        {pool => $pool_id, gap=> $gap}, 'alert');
                }
            }
        }
        $status->('agiletools_repair_pool_order_end');
    }
}

sub sanitycheck_check {
    my ($self, $args) = @_;
    my $status = $args->{'status'};

    $status->('agiletools_check_pool_order');
    my $bad_pools = _get_bad_pools();
    if (%$bad_pools) {
        $status->('agiletools_check_pool_order_alert',
            {pools => $bad_pools}, 'alert');
        $status->('agiletools_chek_pool_order_prompt');
    }
}

#####################
# Webservice bindings
#####################

sub webservice {
    my ($self, $args) = @_;
    $args->{dispatch}->{'Agile.Team'} =
        "Bugzilla::Extension::AgileTools::WebService::Team";
    $args->{dispatch}->{'Agile.Sprint'} =
        "Bugzilla::Extension::AgileTools::WebService::Sprint";
    $args->{dispatch}->{'Agile.Pool'} =
        "Bugzilla::Extension::AgileTools::WebService::Pool";
    $args->{dispatch}->{'Agile.Backlog'} =
        "Bugzilla::Extension::AgileTools::WebService::Backlog";
}

########################
# Admin interface panels
########################

sub config_add_panels {
    my ($self, $args) = @_;
    my $modules = $args->{panel_modules};
    $modules->{AgileTools} = "Bugzilla::Extension::AgileTools::Params";
}

__PACKAGE__->NAME;
