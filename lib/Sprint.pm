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

Bugzilla::Extension::AgileTools::Sprint

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools::Sprint;

=head1 DESCRIPTION

Sprint object contains the bug pool additional data related to sprints like
team and start and end dates.

=head1 FIELDS

=over

=item C<start_date> - Start date of the sprint

=item C<end_date> - End date of the sprint

=back

=cut

use strict;
package Bugzilla::Extension::AgileTools::Sprint;

use base qw(Bugzilla::Object);

use Bugzilla::Extension::AgileTools::Util qw(get_user);

use Bugzilla::Constants;
use Bugzilla::Util qw(trim);


use constant DB_TABLE => 'agile_sprint';

use constant DB_COLUMNS => qw(
    id
    start_date
    end_date
    team_id
    pool_id
);

use constant NUMERIC_COLUMNS => qw(
    team_id
    pool_id
);

use constant DATE_COLUMNS => qw(
    start_date
    end_date
);

use constant UPDATE_COLUMNS => qw(
    start_date
    end_date
);

use constant VALIDATORS => {
};

# Accessors
###########

sub start_date  { return $_[0]->{start_date}; }
sub end_date    { return $_[0]->{end_date}; }
sub team_id    { return $_[0]->{team_id}; }
sub pool_id    { return $_[0]->{pool_id}; }

sub team {
    my $self = shift;
    if (!defined $self->{team}) {
        $self->{team} = Bugzilla::Extension::AgileTools::Team->new(
            $self->team_id);
    }
    return $self->{team};
}

sub pool {
    my $self = shift;
    if (!defined $self->{pool}) {
        $self->{pool} = Bugzilla::Extension::AgileTools::Pool->new(
            $self->pool_id);
    }
    return $self->{pool};
}

# Mutators
##########

sub set_start_date  { $_[0]->set('start_date', $_[1]); }
sub set_end_date    { $_[0]->set('end_date', $_[1]); }
sub set_team_id     { $_[0]->set('team_id', $_[1]); }
sub set_pool_id     { $_[0]->set('pool_id', $_[1]); }

# Validators
############

sub _check_dates {
    # TODO
}

=head1 METHODS

=over

=item C<()>

=back

=head1 SEE ALSO

L<Bugzilla::Object>

