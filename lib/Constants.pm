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
);

=head1 CONSTANTS

=over

=item AGILE_USERS_GROUP - Name of the user group allowed to use AgileTools

=cut

use constant AGILE_USERS_GROUP => "AgileTools users";

1;

__END__

=back
