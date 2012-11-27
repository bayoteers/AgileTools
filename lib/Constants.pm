# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Constants

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools::Constans

=head1 DESCRIPTION

Constants used by AgileTools extension.

=cut

package Bugzilla::Extension::AgileTools::Constants;
use strict;
use warnings;

use base qw(Exporter);

@Bugzilla::Extension::AgileTools::Constants::EXPORT = qw(
    AGILE_USERS_GROUP
    NON_HUMAN_GROUP

    AGILE_PROCESS_SCRUM
    AGILE_PROCESS_NAMES
);

=head1 CONSTANTS

=head2 General

=over

=item AGILE_USERS_GROUP - Name of the user group allowed to use AgileTools

=cut

use constant AGILE_USERS_GROUP => "AgileTools users";

=item NON_HUMAN_GROUP - Name of the non human user group

=cut

use constant NON_HUMAN_GROUP => "non_human";

=back

=head2 Process types

=over

=item AGILE_PROCESS_SCRUM - Process type for Scrum

=cut

use constant AGILE_PROCESS_SCRUM => 1;

=item AGILE_PROCESS_NAMES - Process type - name mapping

=cut

use constant AGILE_PROCESS_NAMES => {
    AGILE_PROCESS_SCRUM, "Scrum",
};

1;

__END__

=back
