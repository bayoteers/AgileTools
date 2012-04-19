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

use strict;
package Bugzilla::Extension::AgileTools::Role;

use base qw(Bugzilla::Object);

use constant DB_TABLE => 'agile_roles';

use constant DB_COLUMNS => qw(
    id
    name
    custom
    can_edit_team
);

use constant NUMERIC_COLUMNS => qw(
    custom
    can_edit_team
);

use constant UPDATE_COLUMNS => qw(
    name
    can_edit_team
);

use constant VALIDATORS => {};

# Accessors
###########

sub custom        { return $_[0]->{custom}; }
sub can_edit_team { return $_[0]->{can_edit_team}; }

# Mutators
##########

sub set_name          { $_[0]->set('name', $_[1]); }
sub set_custom        { $_[0]->set('custom', $_[1]); }
sub set_can_edit_team { $_[0]->set('can_edit_team', $_[1]); }

1;

__END__

=head1 NAME

Bugzilla::Extension::AgileTools::Role

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools::Role;

    my $role = new Bugzilla::Extension::AgileTools::Role(1);

    my $role_id = $role->id;
    my $name = $role->name;
    my $is_custom = $role->custom;
    my $can_edit_team = $role->can_edit_team;

=head1 DESCRIPTION

Role object represents a user role in a team and defines some permissions that
the user has regarding the team. Role is inherited from L<Bugzilla::Object>.
