# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Pool - Bug pool Object class

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools::Pool;

    my $pool = Bugzilla::Extension::AgileTools::Pool->new(1);
    $pool->add_bug(1, 1);
    $pool->remove_bug(2);

=head1 DESCRIPTION

Pool object presents an ordered set of bugs.

=cut

use strict;
package Bugzilla::Extension::AgileTools::Pool;

use Bugzilla::Error;
use Bugzilla::Hook;
use Bugzilla::Util qw(detaint_natural);
use Bugzilla::Bug qw(LogActivityEntry);

use Scalar::Util qw(blessed);

use base qw(Bugzilla::Object);


use constant DB_TABLE => 'agile_pool';

use constant DB_COLUMNS => qw(
    id
    name
    is_active
);

use constant NUMERIC_COLUMNS => qw(
    id
    is_active
);

use constant UPDATE_COLUMNS => qw(
    name
    is_active
);

use constant VALIDATORS => {
};

# Mutators
##########

sub set_name       { $_[0]->set('name', $_[1]); }
sub set_is_active     { $_[0]->set('is_active', $_[1]); }

# Accessors
###########

sub is_active { return $_[0]->{is_active}; }

=head1 METHODS

=over

=item C<bugs()>

    Description: Returns a list of bugs in this pool
    Returns: Array ref of Bug objects

=cut

sub bugs {
    my $self = shift;
    my $dbh = Bugzilla->dbh;

    if (!defined $self->{bugs}) {
        my $pool_bugs = $dbh->selectall_arrayref(
            "SELECT bug_id, pool_order FROM bug_agile_pool
              WHERE pool_id = ?",
              undef, $self->id);
        my %bug_order = map { ("$_->[0]" => $_->[1]) } @$pool_bugs;
        $self->{bugs} = Bugzilla::Bug->new_from_list([keys %bug_order]);

        # Set pool and pool_order in bug objects so that they are not fetched again
        foreach my $bug (@{$self->{bugs}}) {
            $bug->{pool_order} = $bug_order{$bug->id};
            $bug->{pool_id} = $self->id;
        }
    }
    return $self->{bugs};
}

=item C<add_bug($bug, $order)>

    Description: Inserts new bug into the pool
    Params:      $bug - Bug ID or object to be added
                 $order - (optional) Order of the new bug in this pool,
                          goes last if not given
    Returns:     Boolean value telling if pool was changed
    Note:        Bug can be only in one pool at the time and it will be removed
                 from any previous pool.

=cut

sub add_bug {
    my $self = shift;
    my ($bug, $order) = @_;

    my $class = blessed($bug) || "";

    ThrowCodeError("param_invalid", {param => 'bug', function => 'Pool->add_bug'})
        unless ($class eq "Bugzilla::Bug" || detaint_natural($bug));
    ThrowUserError("param_must_be_numeric", { param => 'order', function => 'Pool->add_bug'})
        unless (!defined $order || detaint_natural($order));

    $bug = Bugzilla::Bug->check({id => $bug})
        unless $class eq "Bugzilla::Bug";

    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();

    # Get max order in this pool
    my $max = $dbh->selectcol_arrayref(
        "SELECT COUNT(*)
           FROM bug_agile_pool
          WHERE pool_id = ?",
          undef, $self->id)->[0];

    my ($old_pool, $old_order) = $dbh->selectrow_array(
        "SELECT pool_id, pool_order
           FROM bug_agile_pool
          WHERE bug_id = ?",
          undef, $bug->id);
    $old_pool |= 0;
    $old_order |= 0;

    # If the bug is being moved inside this pool, the maximum order is the
    # number of bugs in the pool, otherwise + 1 (the bug being added)
    $max = ($old_pool == $self->id) ? $max : $max + 1;

    $order = $max unless (defined $order && $order < $max && $order > 0);

    my $changed = ($old_pool != $self->id || $old_order != $order);

    if ($old_pool && $changed) {
        # Update old entry
        $dbh->do("UPDATE bug_agile_pool
                    SET pool_id = ?, pool_order = ?
                    WHERE bug_id = ?",
            undef, ($self->id, $order, $bug->id));
        # Shift other bugs up in old pool
        $dbh->do("UPDATE bug_agile_pool
                    SET pool_order = pool_order - 1
                  WHERE pool_id = ? AND pool_order > ? AND bug_id != ?",
            undef, ($old_pool, $old_order, $bug->id));
    } elsif (!$old_pool) {
        # Insert new entry
        $dbh->do("INSERT INTO bug_agile_pool (bug_id, pool_id, pool_order)
                      VALUES (?, ?, ?)",
            undef, ($bug->id, $self->id, $order));
    }
    # Note: If the bug is moved inside this pool, the other bugs will probably
    # get shifted back and forth, but the performance gain from more detailed
    # queries is probably not worth the introduced complexity...
    if ($changed) {
        # Shift other bugs down in this pool
        $dbh->do("UPDATE bug_agile_pool
                    SET pool_order = pool_order + 1
                  WHERE pool_id = ? AND pool_order >= ? AND bug_id != ?",
            undef, ($self->id, $order, $bug->id));
        delete $self->{bugs};
    }
    if ($old_pool != $self->id) {
        my $delta_ts = $dbh->selectrow_array('SELECT LOCALTIMESTAMP(0)');
        LogActivityEntry($bug->id, 'bug_agile_pool.pool_id', $old_pool, $self->id,
                Bugzilla->user->id, $delta_ts);
        Bugzilla::Hook::process("agile_pool_change", {
            bug => $bug,
            new_pool => $self,
            old_pool => Bugzilla::Extension::AgileTools::Pool->new($old_pool),
        });
    }
    $dbh->bz_commit_transaction();
    return $changed;
}

=item C<remove_bug($bug)>

    Description: Remove bug from pool
    Params:      $bug - Bug ID or object to be removed
    Returns:     Boolean value telling if pool was changed

=cut

sub remove_bug {
    my ($self, $bug) = @_;
    my $class = blessed($bug) || "";

    ThrowCodeError("param_invalid", {param => 'bug', function => 'Pool->add_bug'})
        unless ($class eq "Bugzilla::Bug" || detaint_natural($bug));

    $bug = Bugzilla::Bug->check({id => $bug})
        unless $class eq "Bugzilla::Bug";

    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();

    # order in this pool
    my $order = $dbh->selectrow_array(
        "SELECT pool_order
           FROM bug_agile_pool
          WHERE pool_id = ? AND bug_id = ?",
          undef, ($self->id, $bug->id));

    if (defined $order) {
        # Delete old entry
        $dbh->do("DELETE FROM bug_agile_pool
                    WHERE pool_id = ? AND bug_id = ?",
            undef, ($self->id, $bug->id));
        # Shift bugs in old pool
        $dbh->do("UPDATE bug_agile_pool
                    SET pool_order = pool_order - 1
                  WHERE pool_id = ? AND pool_order > ?",
            undef, ($self->id, $order));
        delete $self->{bugs};
        my $delta_ts = $dbh->selectrow_array('SELECT LOCALTIMESTAMP(0)');
        LogActivityEntry($bug->id, 'bug_agile_pool.pool_id', $self->id, 0,
                Bugzilla->user->id, $delta_ts);
        Bugzilla::Hook::process("agile_pool_change", {
            bug => $bug,
            new_pool => undef,
            old_pool => $self,
        });
    }
    $dbh->bz_commit_transaction();
    return defined $order;
}

=back

=head1 RELATED METHODS

=head2 Bugzilla::Bug object methods

The L<Bugzilla::Bug> object is extended to provide easy access to pool

=over

=item C<Bugzilla::Bug::pool_order>

    Description: Returns the pool order of bug or undef if bug is not in a pool

=cut

BEGIN {
*Bugzilla::Bug::pool_order = sub {
    my $self = shift;
    if (!exists $self->{pool_order}) {
        my ($pool_id, $pool_order) = Bugzilla->dbh->selectrow_array("
            SELECT pool_id, pool_order FROM bug_agile_pool
             WHERE bug_id = ?", undef, $self->id);

        $self->{pool_id} = $pool_id;
        $self->{pool_order} = $pool_order;
    }
    return $self->{pool_order};
};

=item C<Bugzilla::Bug::pool_id>

    Description: Returns the pool id of bug or undef if bug is not in
                 a pool

=cut

*Bugzilla::Bug::pool_id = sub {
    my $self = shift;
    if (!exists $self->{pool_id}) {
        my ($pool_id, $pool_order) = Bugzilla->dbh->selectrow_array("
            SELECT pool_id, pool_order FROM bug_agile_pool
             WHERE bug_id = ?", undef, $self->id);

        $self->{pool_id} = $pool_id;
        $self->{pool_order} = $pool_order;
    }
    return $self->{pool_id};
};

=item C<Bugzilla::Bug::pool>

    Description: Returns the Pool object of the bug or undef if bug is not in
                 a pool

=cut

*Bugzilla::Bug::pool = sub {
    my $self = shift;
    if (!exists $self->{pool}) {
        if ($self->pool_id) {
            $self->{pool} = new Bugzilla::Extension::AgileTools::Pool($self->pool_id);
        } else {
            $self->{pool} = undef;
        }
    }
    return $self->{pool};
};
} # END BEGIN

1;

__END__

=back

=head1 HOOKS

=over

=item C<agile_pool_change>

    Executed on Pool->add_bug() and Pool->remove_bug() when the pool of the bug
    changes.

    Params:
        bug      => Bug object which pool was changed
        old_pool => Bugs old Pool object, or undef if bug wasn't in a pool
                    before
        new_pool => Bugs new Pool object, or undef if bug was removed from pool

=back

=head1 SEE ALSO

L<Bugzilla::Object>


