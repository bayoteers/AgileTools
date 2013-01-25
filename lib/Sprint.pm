# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Sprint - Sprint Object class

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
};

use constant VALIDATOR_DEPENDENCIES => {
    # Start date is checked against existing sprint end dates
    start_date => ['team_id'],
    # End date is checked against start date
    end_date => ['start_date'],
};

use constant EXTRA_REQUIRED_FIELDS => qw(
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

    my $start_date = ref $invocant ?
            datetime_from($invocant->start_date) :
            datetime_from($params->{start_date});

    ThrowUserError("agile_sprint_end_before_start") if ($end_date < $start_date);

    my $id = ref $invocant ? $invocant->id : 0;
    my $team_id = ref $invocant ? $invocant->team_id : $params->{team_id};
    $start_date = $start_date->datetime;
    $end_date = $end_date->datetime;

    my $dbh = Bugzilla->dbh;
    my $overlaping = $dbh->selectrow_array(
        'SELECT id '.
          'FROM agile_sprint '.
         'WHERE team_id = ? AND id != ? AND ('.
               '(start_date > ? AND start_date < ?) OR '.
               '(end_date > ? AND end_date < ?))',
        undef, ($team_id, $id, $start_date, $end_date, $start_date, $end_date ));
    ThrowUserError("agile_overlaping_sprint",
            {sprint => Bugzilla::Extension::AgileTools::Sprint->new($overlaping)})
        if ($overlaping);
    return $end_date;
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
    my $team = Bugzilla::Extension::AgileTools::Team->check(
        {id => $clean_params->{team_id}});

    my $name = $team->name . " sprint ".$start->year."W".$start->week_number;
    if ($start->week_number != $end->week_number) {
        $name .= "-".$end->week_number;
    }
    my $pool = Bugzilla::Extension::AgileTools::Pool->create({name => $name});
    $clean_params->{id} = $pool->id;

    my $sprint = $class->insert_create_data($clean_params);
    # Set this as teams current sprint, if it doesn't have one yet
    if (! defined $team->current_sprint_id) {
        $team->set_current_sprint_id($sprint->id);
        $team->update();
    }
    return $sprint;
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
        my $pool_changes = $self->pool->update();
        $changes->{name} = $pool_changes->{name};
    }

    if (wantarray) {
        return ($changes, $old);
    }
    return $changes;
}

sub remove_from_db {
    my $self = shift;
    # Take pool for later deletion
    my $pool = $self->pool;
    $self->SUPER::remove_from_db(@_);
    $pool->remove_from_db();
}

sub TO_JSON {
    my $self = shift;
    # fetch the pool
    $self->pool;
    # Determine current status
    $self->is_current;
    return { %{$self} };
}

=head1 METHODS

=over

=item C<is_current>

    Description: Returns true if sprint is teams current sprint

=cut

sub is_current {
    my $self = shift;
    $self->{is_current} ||= $self->id == $self->team->current_sprint_id;
    return $self->{is_current};
}

=item C<is_active>

    Description: Returns true if sprint is active

=cut

sub is_active {
    my $self = shift;
    return $self->pool->is_active;
}

=item C<close($params)>

    Description: Closes the sprint if it is teams current one

=cut

sub close {
    my ($self, $params) = @_;

    ThrowCodeError('param_required', {
            function => 'AgileTools::Sprint->close',
            params => ['next_id', 'start_date and end_date']})
        unless ($params->{next_id} ||
            ($params->{start_date} && $params->{end_date}));

    ThrowUserError('agile_cant_close_not_current', {
            sprint => $self})
        unless $self->is_current;

    my $start_date = $params->{start_date};
    my $end_date = $params->{end_date};
    my $archive_start = $self->start_date;
    my $archive_end = $self->end_date;
    my @archive_bugs;
    for my $bug (sort {$a->pool_order - $b->pool_order} @{$self->pool->bugs}) {
        next if $bug->isopened;
        push(@archive_bugs, $bug);
    }

    # If existing sprint is given, take bugs and date rage from that and
    # delete it.
    if ($params->{next_id}) {
        my $next_sprint = Bugzilla::Extension::AgileTools::Sprint->check(
            $params->{next_id});
        ThrowCodeError('agile_cant_change_to_inactive_sprint')
            unless $next_sprint->pool->active;
        for my $bug (sort {$a->pool_order - $b->pool_order} @{$next_sprint->pool->bugs}) {
            $self->pool->add_bug($bug);
        }
        $start_date = $next_sprint->start_date;
        $end_date = $next_sprint->end_date;
        $next_sprint->remove_from_db;
    }
    $self->set_all({
            start_date => $start_date,
            end_date => $end_date,
            capacity => $params->{capacity} || 0,
        });
    $self->update();

    my $archive_sprint = Bugzilla::Extension::AgileTools::Sprint->create({
            team_id => $self->team_id,
            start_date => $archive_start,
            end_date => $archive_end,
        });
    for my $bug (@archive_bugs) {
        $archive_sprint->pool->add_bug($bug);
    }
    $archive_sprint->pool->set_is_active(0);
    $archive_sprint->pool->update;
    return $archive_sprint;
}

1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::Object>

