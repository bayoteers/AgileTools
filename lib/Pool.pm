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
use Bugzilla::Util qw(detaint_natural trim);
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
    name => \&_check_name,
};

# Mutators
##########

sub set_name       { $_[0]->set('name', $_[1]); }
sub set_is_active     { $_[0]->set('is_active', $_[1]); }

# Accessors
###########

sub is_active { return $_[0]->{is_active}; }

# Validatord
####
sub _check_name {
    my ($invocant, $value) = @_;
    my $class = blessed($invocant) || $invocant;
    my $name = trim($value);
    ThrowUserError('invalid_parameter', {
            name => 'name',
            err => 'Name must not be empty'})
        unless $name;

    if (!blessed($invocant) || lc($invocant->name) ne lc($name)) {
        ThrowUserError('invalid_parameter', {
            name => 'name',
            err => "Pool with name '$name' already exists"})
            if defined Bugzilla::Extension::AgileTools::Pool->new(
                {name => $name});
    }
    return $name;
}


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
            $bug->{pool} = $self;
        }
    }
    return $self->{bugs};
}

=item C<add_bug($bug, $order)>

    Description: Inserts new bug into the pool
    Params:      $bug - Bug object or ID to be added to this pool
                 $order - (optional) Order of the new bug in this pool,
                          goes last if not given
    Returns:     New order value of the bug in the new pool
    Note:        Bug can be only in one pool at the time and it will be removed
                 from any previous pool.

=cut

sub add_bug {
    my $self = shift;
    my ($bug, $order) = @_;
    if (!defined $bug) {
        ThrowCodeError("param_required", {
            param=>'bug', function=>'Pool->remove_bug'});
    }
    $bug = Bugzilla::Bug->new($bug) unless ref $bug;
    if (!defined $bug) {
        ThrowCodeError("param_invalid", {
            param => blessed($bug),
            function => 'Pool->remove_bug',
            });
    }
    ThrowCodeError("param_must_be_numeric", { param => 'order', function => 'Pool->add_bug'})
        unless (!defined $order || detaint_natural($order));

    my ($old_pool, $old_order);
    ($order, $old_pool, $old_order) = _adjust_order($bug->id, $self->id, $order);
    if ($old_pool == $self->id && $old_order == $order) {
        return 0;
    }

    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();
    if ($old_pool) {
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
    } else {
        # Insert new entry
        $dbh->do("INSERT INTO bug_agile_pool (bug_id, pool_id, pool_order)
                      VALUES (?, ?, ?)",
            undef, ($bug->id, $self->id, $order));
    }
    # Note: If the bug is moved inside this pool, the other bugs will probably
    # get shifted back and forth, but the performance gain from more detailed
    # queries is probably not worth the introduced complexity...

    # Shift other bugs down in this pool
    $dbh->do("UPDATE bug_agile_pool
                SET pool_order = pool_order + 1
              WHERE pool_id = ? AND pool_order >= ? AND bug_id != ?",
        undef, ($self->id, $order, $bug->id));
    $dbh->bz_commit_transaction();

    # Update references in the objects
    if (defined $self->{bugs} && $self->id != $old_pool) {
        push(@{$self->{bugs}}, $bug);
    }
    $bug->{pool} = $self;
    $bug->{pool_id} = $self->id;
    $bug->{pool_order} = $order;

    return 1;
}

# Helper to figure out suitable postion for the bug being added to the pool
sub _adjust_order {
    my ($bug_id, $pool_id, $order) = @_;
    my $dbh = Bugzilla->dbh;

    my ($old_pool, $old_order) = $dbh->selectrow_array(
        "SELECT pool_id, pool_order
           FROM bug_agile_pool
          WHERE bug_id = ?",
          undef, $bug_id);
    $old_pool //= 0;
    $old_order //= 0;
    my $max = $dbh->selectrow_array(
            "SELECT COUNT(*)
               FROM bug_agile_pool
              WHERE pool_id = ?",
              undef, $pool_id);
    $max += 1 if ($pool_id != $old_pool);

    if (!defined $order) {
        # See if we can set the order based on a parent...
        my $parent_at = $dbh->selectrow_array(
            'SELECT bug_agile_pool.pool_order
            FROM bug_agile_pool
                LEFT JOIN dependencies
                    ON bug_agile_pool.bug_id = dependencies.blocked
                        AND dependencies.dependson = ?
            WHERE bug_agile_pool.pool_id = ? AND dependson IS NOT NULL ' .
                $dbh->sql_group_by('bug_agile_pool.bug_id') .
                ' ORDER BY bug_agile_pool.pool_order LIMIT 1',
            undef, $bug_id, $pool_id);
        if (defined $parent_at) {
            # If bug is moved inside this pool, (in which case the order is
            # usually given, but just in case) we need to note that the parent
            # might move up. so either its parent order or parent order + 1
            $order = ($old_pool == $pool_id && $old_order &&
                      $old_order < $parent_at ) ? $parent_at : $parent_at + 1;
        } else {
            # ...or just add it to the end
            $order = $max;
        }
    }

    # And make sure it's in acceptaple limits
    $order = $max if ($order > $max);
    $order = 1 if ($order <= 0);
    return ($order, $old_pool, $old_order);
}

=item C<remove_bug($bug)>

    Description: Remove bug from pool
    Params:      $bug - Bug object or ID to be removed from this pool

=cut

sub remove_bug {
    my ($self, $bug) = @_;
    if (!defined $bug) {
        ThrowCodeError("param_required", {
            param=>'bug', function=>'Pool->remove_bug'});
    }
    $bug = Bugzilla::Bug->new($bug) unless ref $bug;
    if (!defined $bug) {
        ThrowCodeError("param_invalid", {
            param => blessed($bug),
            function => 'Pool->remove_bug',
            });
    }

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
        delete $bug->{pool};
        delete $bug->{pool_id};
        delete $bug->{pool_order};
    }
    $dbh->bz_commit_transaction();
}

=item C<is_sprint()>

    Description: Check if pool is a sprint

=cut

sub is_sprint {
    my $id = shift;
    # If called as Pool method or with a pool object
    $id = $id->id if ref($id);
    detaint_natural($id);
    my $cache = Bugzilla->request_cache->{sprint_pools} ||= {};
    if(!defined $cache->{$id}) {
        $cache->{$id} = Bugzilla->dbh->selectrow_array(
            "SELECT COUNT(id) FROM agile_sprint WHERE id = ?", undef, $id);
    }
    return $cache->{$id};
}

=item C<is_backlog()>

    Description: Check if pool is a backlog

=cut

sub is_backlog {
    my $id = shift;
    # If called as Pool method or with a pool object
    $id = $id->id if ref($id);
    detaint_natural($id);
    my $cache = Bugzilla->request_cache->{backlog_pools} ||= {};
    if(!defined $cache->{$id}) {
        $cache->{$id} = Bugzilla->dbh->selectrow_array(
            "SELECT COUNT(pool_id) FROM agile_backlog WHERE pool_id = ?", undef, $id);
    }
    return $cache->{$id};
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

        $self->{pool_id} = $pool_id || 0;
        $self->{pool_order} = $pool_order || 0;
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

        $self->{pool_id} = $pool_id || 0;
        $self->{pool_order} = $pool_order || 0;
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
        $self->{pool} = $self->pool_id ?
            new Bugzilla::Extension::AgileTools::Pool($self->pool_id) : undef;
    }
    return $self->{pool};
};

*Bugzilla::Bug::set_pool_id = sub {
    my ($self, $pool_id) = @_;
    delete $self->{pool};
    $self->{pool_id} = $pool_id;
};

*Bugzilla::Bug::set_pool_order = sub {
    my ($self, $order) = @_;
    $self->{pool_order} = $order;
    $self->{pool_order_set} = 1;
};

} # END BEGIN

1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::Object>


