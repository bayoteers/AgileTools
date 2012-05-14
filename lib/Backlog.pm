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

Bugzilla::Extension::AgileTools::Backlog

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools::Backlog;

=head1 DESCRIPTION

Backlog object maps a bug pool to team, to present a scrum product backlog.

=head1 FIELDS

=over

=item C<pool_id> - ID of the pool related to this backlog

=item C<team_id> - ID of the team owning this backlog

=back

=cut

use strict;
package Bugzilla::Extension::AgileTools::Backlog;

use base qw(Bugzilla::Object);

use Bugzilla::Extension::AgileTools::Pool;

use Bugzilla::Constants;
use Bugzilla::Util qw(datetime_from);


use constant DB_TABLE => 'agile_backlog';

use constant DB_COLUMNS  => qw(
        id
        team_id
        pool_id
);

use constant NUMERIC_COLUMNS => qw(
    team_id
    pool_id
);

use constant VALIDATORS => {};

# Accessors
###########

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

sub name {
    my $self = shift;
    if (!defined $self->{name}) {
        $self->{name} = $self->pool->name;
    }
    return $self->{name};
}

sub create {
    my ($class, $params) = @_;

    $class->check_required_create_fields($params);
    my $clean_params = $class->run_create_validators($params);

    # Create pool for this sprint
    my $name = Bugzilla->dbh->selectrow_array("
        SELECT name FROM agile_team
            WHERE id = ?", undef, $params->{team_id});
    $name = $name." backlog";
    my $pool = Bugzilla::Extension::AgileTools::Pool->create({name => $name});
    $clean_params->{pool_id} = $pool->id;

    return $class->insert_create_data($clean_params);
}

=head1 METHODS

=over

=item C<()>

=back

=cut

1;

__END__

=head1 SEE ALSO

L<Bugzilla::Object>


