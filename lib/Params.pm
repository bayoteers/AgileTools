# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

package Bugzilla::Extension::AgileTools::Params;

use strict;
use warnings;

use Bugzilla::Config::Common;
use Bugzilla::Field;

sub get_param_list {
    my ($class) = @_;

    my @param_list = (
        {
            name    => 'agile_use_points',
            desc    => 'Display estimated, remaining and actual time as points '.
                        'instead of hours',
            type    => 'b',
            default => 1
        },
        {
            name => 'agile_check_time_severity',
            desc => 'Bug severities for which time worked is checked when resolving',
            type    => 'm',
            choices => get_legal_field_values('bug_severity'),
            default => [],
        },
        {
            name => 'agile_check_time_resolution',
            desc => 'Bug resolutions for which time worked is checked when resolving',
            type    => 'm',
            choices => get_legal_field_values('resolution'),
            default => [],
        },
        {
            name => 'agile_scrum_buglist_columns',
            desc => 'List of columns to show in scrum buglist queries',
            type    => 't',
            default => "bug_agile_pool.pool_order bug_status assigned_to ".
                    "short_short_desc estimated_time actual_time remaining_time",
            # TODO: add checker to make sure entered columns are valid
        },
        {
            name => 'agile_start_working_button',
            desc => 'Show "Start Working"-button on bug view',
            type    => 'b',
            default => 1,
        },
        {
            name => 'agile_working_on_status',
            desc => 'Status that means user is working on an item',
            type    => 's',
            choices => get_legal_field_values('bug_status'),
            default => 'IN_PROGRESS',
        },
        {
            name => 'agile_start_working_comment',
            desc => 'Default comment to add when "start working"-button is used. '.
                    'If empty, then no comment is added.',
            type    => 't',
            default => "Started working on this",
        },

    );
    return @param_list;
}

1;
