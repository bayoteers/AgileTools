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

package Bugzilla::Extension::AgileTools::Params;

use strict;
use warnings;

use Bugzilla::Config::Common;
use Bugzilla::Field;

sub get_param_list {
    my ($class) = @_;

    my @param_list = (
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

    );
    return @param_list;
}

1;
