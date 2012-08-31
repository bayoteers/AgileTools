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

=item C<start_date> (mutable) - Start date of the sprint

=item C<end_date> (mutable) - End date of the sprint

=item C<pool_id> - ID of the pool related to this backlog

=item C<team_id> - ID of the team owning this backlog

=item C<capacity> (mutable) - Estimated work capacity for the sprint

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
        capacity
    ),
    $dbh->sql_date_format('start_date', '%Y-%m-%d 00:00:00') . ' AS start_date',
    $dbh->sql_date_format('end_date', '%Y-%m-%d 23:59:59') . ' AS end_date',
    );
    return @columns;
}

use constant NUMERIC_COLUMNS => qw(
    team_id
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
    capacity => \&Bugzilla::Object::check_time,
    move_open => \&Bugzilla::Object::check_boolean,
};

use constant VALIDATOR_DEPENDENCIES => {
    # Start date is checked against existing sprint end dates
    start_date => ['team_id'],
    # End date is checked against start date
    end_date => ['start_date'],
};

use constant EXTRA_REQUIRED_FIELDS => qw(
    move_open
);

# Accessors
###########

sub start_date  { return $_[0]->{start_date}; }
sub end_date    { return $_[0]->{end_date}; }
sub team_id     { return $_[0]->{team_id}; }
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
            $self->id);
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
    $clean_params->{id} = $pool->id;

    if(delete $clean_params->{move_open}) {
        my $previous = Bugzilla->dbh->selectrow_array(
            "SELECT id FROM agile_sprint ".
             "WHERE team_id = ? AND end_date <= ? ".
             "ORDER BY start_date DESC", undef,
             ($clean_params->{team_id}, $clean_params->{start_date}));
         if (defined $previous) {
             $previous = Bugzilla::Extension::AgileTools::Pool->new($previous);
             foreach my $bug (@{$previous->bugs}) {
                 next unless $bug->isopened;
                 $pool->add_bug($bug->id);
             }
         }
    }
    return $class->insert_create_data($clean_params);
}

sub update {
    my $self = shift;

    my($changes, $old) = $self->SUPER::update(@_);

    # Update pool name if the weeks have changed
    my $update_name = 0;
    my $start = datetime_from($self->start_date);
    my $end = datetime_from($self->end_date);

    if ($changes->{start_date}) {
        my $old = datetime_from($changes->{start_date}->[0]);
        $update_name = ($old->week_number != $start->week_number
                        || $old->year != $start->year);
    }
    if ($changes->{end_date}) {
        my $old = datetime_from($changes->{end_date}->[0]);
        $update_name = $update_name || (
                        $old->week_number != $end->week_number
                        || $old->year != $end->year);
    }
    if ($update_name) {
        my $name = $self->team->name." sprint ";
        $name .= $start->year."W".$start->week_number;
        if ($start->week_number != $end->week_number) {
            $name .= "-".$end->week_number;
        }
        $self->pool->set_all({name => $name});
        $self->pool->update();
    }

    if (wantarray) {
        return ($changes, $old);
    }
    return $changes;
}
sub TO_JSON {
    my $self = shift;
    # fetch the pool
    $self->pool;
    return { %{$self} };
}

1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::Object>

