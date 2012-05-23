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

=item C<pool_id> - ID of the pool related to this backlog

=item C<team_id> - ID of the team owning this backlog

=item C<capacity> - Estimated work capacity for the sprint

=back

=cut

use strict;
package Bugzilla::Extension::AgileTools::Sprint;

use base qw(Bugzilla::Object);

use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util qw(datetime_from detaint_natural trim);


use constant DB_TABLE => 'agile_sprint';

use constant LIST_ORDER => 'start_date';

sub DB_COLUMNS {
    my $dbh = Bugzilla->dbh;
    my @columns = (qw(
        id
        team_id
        pool_id
        capacity
    ),
    $dbh->sql_date_format('start_date', '%Y-%m-%d 00:00:00') . ' AS start_date',
    $dbh->sql_date_format('end_date', '%Y-%m-%d 23:59:59') . ' AS end_date',
    );
    return @columns;
}

use constant NUMERIC_COLUMNS => qw(
    team_id
    pool_id
    capacity
);

use constant DATE_COLUMNS => qw(
    start_date
    end_date
);

use constant UPDATE_COLUMNS => qw(
    start_date
    end_date
    capacity
);

use constant VALIDATORS => {
    start_date => \&_check_start_date,
    end_date => \&_check_end_date,
    team_id => \&_check_number,
    capacity => \&_check_number,
};

use constant VALIDATOR_DEPENDENCIES => {
    # Start date is checked against existing sprint end dates
    start_date => ['team_id'],
    # End date is checked against start date
    end_date => ['start_date'],
};

# Accessors
###########

sub start_date  { return $_[0]->{start_date}; }
sub end_date    { return $_[0]->{end_date}; }
sub team_id     { return $_[0]->{team_id}; }
sub pool_id     { return $_[0]->{pool_id}; }
sub capacity    { return $_[0]->{capacity}; }

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

# Mutators
##########

sub set_start_date  { $_[0]->set('start_date', $_[1]); }
sub set_end_date    { $_[0]->set('end_date', $_[1]); }
sub set_capacity    { $_[0]->set('capacity', $_[1]); }

# Validators
############

sub _check_start_date {
    my ($invocant, $date, undef, $params) = @_;
    $date = trim($date);
    $date || ThrowUserError("agile_missing_field", {field=>'start_date'});

    my $start_date = datetime_from($date);
    $start_date || ThrowUserError("agile_invalid_field", {
            field => "start_date", value => $date});
    $start_date->set({hour=>0, minute=>0, second=>0});
    $start_date = $start_date->datetime;

    my $team_id;
    if (ref $invocant) {
        $team_id = $invocant->team_id;
    } else {
        $team_id = $params->{team_id};
    }

    my $dbh = Bugzilla->dbh;

    my $overlaping = $dbh->selectrow_array(
        "SELECT id 
           FROM agile_sprint
          WHERE team_id = ?
                AND end_date > ?
                AND start_date < ?",
        undef, ($team_id, $start_date, $start_date ));
    ThrowUserError("agile_overlaping_sprint") if ($overlaping);
    return $start_date;
}

sub _check_end_date {
    my ($invocant, $date, undef, $params) = @_;
    $date = trim($date);
    $date || ThrowUserError("agile_missing_field", {field=>'end_date'});

    my $end_date = datetime_from($date);
    $end_date || ThrowUserError("agile_invalid_field", {
            field => "end_date", value => $date});
    $end_date->set({hour=>23, minute=>59, second=>59});

    my $start_date;
    if (ref $invocant) {
        $start_date = datetime_from($invocant->start_date);
    } else {
        $start_date = datetime_from($params->{start_date});
    }
    ThrowUserError("agile_sprint_end_before_start") if ($end_date < $start_date);
    return $end_date->datetime;
}

# TODO Move overlaping check to separate validator and check both start and
#      end at the same time.

sub _check_number {
    my ($invocant, $value, $field) = @_;
    ThrowUserError("invalid_parameter", {name=>$field, err=>'Not a number'})
        unless detaint_natural($value);
    return $value;
}


sub create {
    my ($class, $params) = @_;

    $class->check_required_create_fields($params);
    my $clean_params = $class->run_create_validators($params);

    # Create pool for this sprint
    my $start = datetime_from($clean_params->{start_date});
    my $end = datetime_from($clean_params->{end_date});
    my $name = Bugzilla->dbh->selectrow_array("
        SELECT name FROM agile_team
            WHERE id = ?", undef, $clean_params->{team_id});
    $name || ThrowUserError('object_does_not_exist', {
            id => $clean_params->{team_id}, class => 'AgileTools::Team' });

    $name .= " sprint ".$start->year."W".$start->week_number;
    if ($start->week_number != $end->week_number) {
        $name .= "-".$end->week_number;
    }
    my $pool = Bugzilla::Extension::AgileTools::Pool->create({name => $name});
    $clean_params->{pool_id} = $pool->id;

    return $class->insert_create_data($clean_params);
}

=head1 ADDITIONAL CONSTRUCTORS

=over

=item C<current_sprint($team_id)>

    Description: Get the current sprint of given team.
    Params:      $team_id - Team ID.
    Returns:     Sprint object or undef if team does not have current sprint.

=cut

sub current_sprint {
    my ($class, $team_id) = @_;
    ThrowCodeError("param_must_be_numeric", {
            param => "team_id", function => "current_sprint"})
        unless detaint_natural($team_id);
    my $now = Bugzilla->dbh->selectrow_array("SELECT NOW()");
    my $sprints = $class->match({
            WHERE => {
                "start_date <= ?" => $now,
                "end_date > ?" => $now,
                "team_id = ?" => $team_id,
            }
        });
    # There should be only one, if there is more, we don't care
    return $sprints->[0];
}

=item C<previous_sprint($team_id)>

    Description: Get the previous sprint of given team.
    Params:      $team_id - Team ID.
    Returns:     Sprint object or undef if team does not have previous sprint.

=cut

sub previous_sprint {
    my ($class, $team_id) = @_;
    ThrowCodeError("param_must_be_numeric", {
            param => "team_id", function => "previous_sprint"})
        unless detaint_natural($team_id);
    my $sprint_id = Bugzilla->dbh->selectrow_array(
        "SELECT id FROM agile_sprint ".
         "WHERE end_date < NOW() AND team_id = ? ".
         "ORDER BY start_date DESC", undef, $team_id);
    my $sprint = $sprint_id ? $class->new($sprint_id) : undef;
    return $sprint;
}

1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::Object>

