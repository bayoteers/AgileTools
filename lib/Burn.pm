# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Burn - Burndown chart generation

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools:Burn

    my $data = get_burndata([1,2,3,4], '2012-10-01', '2012-10-31');

=head1 DESCRIPTION

AgileTools extension burnup/down data generation functions.

=cut

package Bugzilla::Extension::AgileTools::Burn;
use strict;

use Bugzilla::Status qw(is_open_state);

use Date::Parse;
use List::Util qw(min max);

use base qw(Exporter);
our @EXPORT = qw(
    get_burndata
);

=head1 FUNCTIONS

=over

=item C<get_burndata($bugs, $from, $to)>

    Description: Get burndown related data
    Params:      $bugs - List of bug IDs
                 $from - start date 'YYYY-MM-DD'
                 $to - end date 'YYYY-MM-DD'
    Returns:    Hash containing:
        remaining  => Array of remaining time history
        actual     => Array of actual work time history
        open_items => Array of open item history
        start      => Start time stamp
        end        => End time stamp
        max_items  => Maximum number of open items
        max_work   => Maximum of remaining/actual work
        now        => Current timestamp

    Return data is formated so that it can be directly encoded to JSON and used
    with the FLOT javascript library.

=cut

sub get_burndata {
    my ($bugs, $from, $to, $is_timetracker) = @_;

    my $dbh = Bugzilla->dbh;

    # TODO: Proper timezone handling.
    #   jQuery Flot expects UTC timestamps, but BZ uses localtime
    #   Currently we just pretend that these are all UTC
    my $now = DateTime->now(time_zone => Bugzilla->local_timezone);
    $now = $now->add(seconds => $now->offset)->epoch * 1000;

    $from = $from ? 1000 * str2time($from."T00:00:00", "UTC") : 0;
    $to = $to ? 1000 * str2time($to."T23:59:59", "UTC") : $now;
    my $first_ts;

    # Get current remaining time
    my $current = 0;
    $current = $dbh->selectrow_array(
        'SELECT SUM(remaining_time) FROM bugs WHERE '.
        $dbh->sql_in('bug_id', $bugs)) if (@$bugs);

    # History query
    my $sth;
    $sth = $dbh->prepare(
        'SELECT ac.bug_id, ac.bug_when, ac.removed, ac.added '.
        'FROM bugs_activity AS ac '.
        'LEFT JOIN fielddefs fd ON fd.id = ac.fieldid '.
        'WHERE '.$dbh->sql_in('ac.bug_id', $bugs).' AND fd.name = ? '.
        'ORDER BY ac.bug_when DESC') if(@$bugs);

    ############################
    # Get remaining time history
    # This is done by trversing the remaining_time changes in reverse
    # chronological order and adding the change to current remaining.

    my @tmp;
    if ($is_timetracker and defined $sth){
        $sth->execute('remaining_time');
        while (my @row  = $sth->fetchrow_array) {
            my ($bug_id, $when, $rem, $add) = @row;
            my $change = $rem - $add;
            my $ts = 1000 * str2time($when, "UTC");
            $first_ts = defined $first_ts ? min($ts, $first_ts) : $ts;
            push @tmp, [$ts, $current];
            $current += $change;
        }
    }
    my $start_rem = 0;
    my @remaining = grep {
        $start_rem = $_->[1] if ($_->[0] < $from);
        $from <= $_->[0] && $to >= $_->[0];
    } reverse @tmp;

    # Add dummy point to this moment if there isn't recent changes
    if (scalar @remaining && $remaining[-1]->[0] < $now - 60*60*1000) {
        push(@remaining, [$now, $remaining[-1]->[1]])
    }

    ######################
    # Get actual work time
    # work_time changes present the time added, so this can be simply summed
    # up. But as we use the same query, which is in descending chronological
    # order, We need to first get the data and reverse it.

    my @work_time;
    if ($is_timetracker and defined $sth) {
        $sth->execute('work_time');
        while (my @row  = $sth->fetchrow_array) {
            my ($bug_id, $when, $rem, $add) = @row;
            my $ts = 1000 * str2time($when, "UTC");
            if ($ts >= $from && $ts <= $to) {
                push @work_time, [$ts, $add];
                $first_ts = defined $first_ts ? min($ts, $first_ts) : $ts;
            }
        }
    }
    my $sum = 0;
    my @actual = ([$from, $sum]);
    for my $row (reverse @work_time) {
        my ($ts, $add) = @$row;
        $sum += $add;
        push @actual, [$ts, $sum];
    }

    # Add dummy point to this moment if there isn't recent changes
    if (scalar @actual && $actual[-1]->[0] < $now - 60*60*1000) {
        push(@actual, [$now, $actual[-1]->[1]])
    }

    #######################
    # Get open item history
    # Fetch changes in bug_status and filter them to just changes from open
    # to closed statuses or vice versa.

    # Get count of currently open bugs
    my $open_count = 0;
    $open_count = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM bugs '.
        'LEFT JOIN bug_status st ON bugs.bug_status = st.value '.
        'WHERE '.$dbh->sql_in('bug_id', $bugs).
        ' AND st.is_open = 1;') if (@$bugs);

    my $start_items = $open_count;

    @tmp = ();
    if (defined $sth) {
        $sth->execute('bug_status');
        while (my @row  = $sth->fetchrow_array) {
            my ($bug_id, $when, $rem, $add) = @row;

            # Check if status changes from open to closed or from closed to open
            my $closed = is_open_state($rem) && !is_open_state($add);
            my $opened = $closed ? 0 :
                is_open_state($add) && !is_open_state($rem);
            next unless $opened || $closed;
            my $ts = 1000 * str2time($when, "UTC");
            $first_ts = defined $first_ts ? min($ts, $first_ts) : $ts;
            push @tmp, [$ts, $open_count];
            if ($opened) {
                $open_count -= 1;
            } elsif ($closed) {
                $open_count += 1;
            }
            $start_items = $open_count;
        }
    }
    my @items = grep {
        $start_items = $_->[1] if ($_->[0] < $from);
        $from <= $_->[0] && $to >= $_->[0];
    } reverse @tmp;

    # Add dummy point to this moment if there isn't recent changes
    if (scalar @items && $items[-1]->[0] < $now - 60*60*1000) {
        push(@items, [$now, $items[-1]->[1]])
    }

    # If start date is not given, use first history entry on month before today
    $from ||= $first_ts || $now - 30*24*60*60*1000;

    # Set some reasonable start values for the data sets
    unshift @remaining, [$from, $start_rem || $remaining[0][1] || 0];
    unshift @items, [$from, $start_items || $items[0][1] || 0];

    my $max_work = 0;
    if( $is_timetracker) {
        foreach (@remaining, @actual) {
            $max_work = $_->[1] if $max_work < $_->[1];
        }
    }

    return {
        start => $from,
        end => $to,
        max_work => $max_work,
        max_items => $start_items,

        remaining => \@remaining,
        actual => \@actual,
        open_items => \@items,
        now => $now,
    };
}

1;

__END__

=back
