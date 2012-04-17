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

package Bugzilla::Extension::AgileTools::Team;
use strict;

use Bugzilla::Group;

use base qw(Bugzilla::Object);

use constant DB_TABLE => 'agile_teams';

use constant DB_COLUMS => qw(
    id
    name
    group_id
    process_id
);

use constant NUMERIC_COLUMNS => qw(
    group_id
    process_id
);

use constant UPDATE_COLUMNS => qw(
    name
    group_id
    process_id
);


# Accessors
###########

sub group_id   { return $_[0]->{group_id}; }
sub process_id { return $_[0]->{process_id}; }

sub group {
    my $self = shift;
    $self->{group} ||= Bugzilla::Group->new($self->group_id);
    return $self->{group};
}

# Mutators
##########

sub set_name       { $_[0]->set('name', $_[1]); }
sub set_group_id   { $_[0]->set('group_id', $_[1]); }
sub set_process_id { $_[0]->set('process_id', $_[1]); }

sub set_group {
    my ($self, $value) = @_;
    my $group_id;
    if (ref($value)) {
        $group_id = $value->id;
    } elsif ($value =~ /\d+/) {
        $group_id = $value;
    } else {
        $group_id = Bugzilla::Group->check($value)->id;
    }
    $self->set('group_id', $group_id);
}

1;
