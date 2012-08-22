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
#   Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Burn

=head1 SYNOPSIS

    TBD

=head1 DESCRIPTION

AgileTools extension burnup/down data generation functions

=cut

package Bugzilla::Extension::AgileTools::Burn;
use strict;

use Date::Parse;
use List::Util qw(min max);
use Data::Dumper;

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
        start      => start time stamp
        end        => end time stamp

    Return data is formated so that it can be directly encoded to JSON and used
    with the FLOT javascript library.

=cut

sub get_burndata {
    my ($bugs, $from, $to) = @_;
    my $dbh = Bugzilla->dbh;

    my @remaining;
    my @actual;

    $from = defined $from ? 1000 * str2time($from) : 0;
    $to = defined $to ? 1000 * str2time($to) : 1000 * time();
    my $first_ts;
    my $last_ts;

    # Get current remaining time
    my $current = $dbh->selectrow_array(
        'SELECT SUM(remaining_time) FROM bugs WHERE '.
        $dbh->sql_in('bug_id', $bugs));

    # History query
    my $sth = $dbh->prepare(
        'SELECT ac.bug_id, ac.bug_when, ac.removed, ac.added '.
        'FROM bugs_activity AS ac '.
        'LEFT JOIN fielddefs fd ON fd.id = ac.fieldid '.
        'WHERE '.$dbh->sql_in('ac.bug_id', $bugs).' AND fd.name = ? '.
        'ORDER BY ac.bug_when DESC');

    ##############################
    # Get remaining time history #
    ##############################
    my $start_rem;
    my $end_rem;

    $sth->execute('remaining_time');
    while (my @row  = $sth->fetchrow_array) {
        my ($bug_id, $when, $rem, $add) = @row;
        my $change = $rem - $add;
        my $ts = 1000 * str2time($when);
        if ($from <= $ts && $to >= $ts) {
            push @remaining, [$ts, $current];
            $first_ts = defined $first_ts ? min($ts, $first_ts) : $ts;
            $last_ts = defined $last_ts ? max($ts, $last_ts) : $ts;
            $start_rem = $current;
            $end_rem = $current unless defined $end_rem;
        }
        $current += $change;
    }
    push @remaining, [$from, $start_rem];

    ########################
    # Get actual work time #
    ########################
    my @work_time;
    $sth->execute('work_time');
    while (my @row  = $sth->fetchrow_array) {
        my ($bug_id, $when, $rem, $add) = @row;
        my $ts = 1000 * str2time($when);
        if ($from <= $ts && $to >= $ts) {
            push @work_time, [$ts, $add];
            $first_ts = defined $first_ts ? min($ts, $first_ts) : $ts;
            $last_ts = defined $last_ts ? max($ts, $last_ts) : $ts;
        }
    }
    my $sum = 0;
    push @actual, [$from, 0];

    for my $row (reverse @work_time) {
        my ($ts, $add) = @$row;
        $sum += $add;
        push @actual, [$ts, $sum];
    }

    #########################
    # Get open item history #
    #########################
    my @items;
    my $start_items;
    $current = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM bugs '.
        'LEFT JOIN bug_status st ON bugs.bug_status = st.value '.
        'WHERE '.$dbh->sql_in('bug_id', $bugs).
        ' AND st.is_open = 1;');

    my %is_open = map {$_->[0] => $_->[1]} @{$dbh->selectall_arrayref(
        'SELECT value, is_open FROM bug_status')};

    $sth->execute('bug_status');
    my $first_close = 1;
    while (my @row  = $sth->fetchrow_array) {
        my ($bug_id, $when, $rem, $add) = @row;
        my $closed = $is_open{$rem} && !$is_open{$add};
        my $opened = $is_open{$add} && !$is_open{$rem};
        next unless $opened || $closed;
        my $ts = 1000 * str2time($when);

        if ($from <= $ts && $to >= $ts) {
            push @items, [$ts, $current];
            $first_ts = defined $first_ts ? min($ts, $first_ts) : $ts;
            $last_ts = defined $last_ts ? max($ts, $last_ts) : $ts;
            $start_items = $current;
            $first_close = $closed;
        }
        if ($opened) {
            $current -= 1;
        } elsif ($closed) {
            $current += 1;
        }
    }
    $start_items += $first_close ? 1 : -1;
    push @items, [$from, $start_items];

    return {
        start => $from || $first_ts,
        end => $to,
        remaining => \@remaining,
        actual => \@actual,
        open_items => \@items,
    };
}

1;

__END__

=back
