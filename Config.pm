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

use constant NAME => 'AgileTools';

use constant REQUIRED_MODULES => [
    {
        package => 'JSON-RPC',
        module  => 'JSON::RPC',
        version => 0,
    },
    {
        package => 'Test-Taint',
        module  => 'Test::Taint',
        version => 0,
    },
];

use constant OPTIONAL_MODULES => [
];

__PACKAGE__->NAME;
