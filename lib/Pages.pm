# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2013 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Pages

=head1 DESCRIPTION

Generic page handler functions

=head1 HANDLERS

=over

=cut



=item C<group_id> - ID of the group associated with the team

=item C<process_id> (mutable) - ID of the development process the team uses.
        See: L<extensions::AgileTools::lib::Constants/Process types>

=item C<current_sprint_id> - ID of the sprint/pool containing the teams current
        sprint.


=cut

use strict;
use warnings;
package Bugzilla::Extension::AgileTools::Pages;

use Bugzilla::Extension::AgileTools::Constants;

=item C<user_summary> - The "My Teams" page

=cut

sub user_summary {
    my $vars = shift;
    $vars->{processes} = AGILE_PROCESS_NAMES;
    $vars->{agile_teams} = Bugzilla->user->agile_teams;
}

=back

=cut

1;
__END__
