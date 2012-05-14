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

Bugzilla::Extension::AgileTools::Pool

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools::Pool;

=head1 DESCRIPTION

Pool object presents a ordered set of bugs

=head1 FIELDS

=over

=item C<start_date> - Start date of the sprint

=item C<end_date> - End date of the sprint

=back

=cut

use strict;
package Bugzilla::Extension::AgileTools::Pool;

use Bugzilla::Error;
use Bugzilla::Util qw(detaint_natural);

use base qw(Bugzilla::Object);


use constant DB_TABLE => 'agile_pool';

use constant DB_COLUMNS => qw(
    id
    name
);

use constant NUMERIC_COLUMNS => qw(
    id
);

use constant UPDATE_COLUMNS => qw(
    name
);

use constant VALIDATORS => {
};

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
        my $bug_ids = $dbh->selectcol_arrayref(
            "SELECT bug_id FROM bug_agile_pool
              WHERE pool_id = ? ORDER BY pool_order",
              undef, $self->id);
        $self->{bugs} = Bugzilla::Bug->new_from_list($bug_ids);
    }
    return $self->{bugs};
}

=item C<insert_bug($bug_id, $order)>

    Description: Inserts new bug into the pool
    Params:      $bug_id - Bug ID
                 $order - (optional) Order of the new bug in this pool,
                          goes last if not given
    Note:        Bug can be only in one pool at the time and it will be removed
                 from any previous pool.

=cut

sub insert_bug {
    my $self = shift;
    my ($bug_id, $order) = @_;

    ThrowUserError("invalid_parameter", {name=>'bug_id', err=>'Not a number'})
        unless detaint_natural($bug_id);
    ThrowUserError("invalid_parameter", {name=>'order', err=>'Not a number'})
        unless detaint_natural($order);

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
          undef, $bug_id);

    # If the bug is being moved inside this pool, the maximum order is the
    # number of bugs in the pool, otherwise + 1 (the bug being added)
    $max = ($old_pool == $self->id) ? $max : $max + 1;

    $order = $max unless (defined $order && $order < $max);

    my $changed = ($old_pool != $self->id || $old_order != $order);

    if (defined $old_pool && $changed) {
        # Delete old entry
        $dbh->do("DELETE FROM bug_agile_pool
                    WHERE pool_id = ? AND bug_id = ?",
            undef, ($old_pool, $bug_id));
        # Shift bugs in old pool
        $dbh->do("UPDATE bug_agile_pool
                    SET pool_order = pool_order - 1
                  WHERE pool_id = ? AND pool_order > ?",
            undef, ($old_pool, $old_order));
    }
    # Note: If the bug is moved inside this pool, the other bugs will probably
    # get shifted back and forth, but the performance gain from more detailed
    # queries is probably not worth the introduced complexity...
    if ($changed) {
        # Shift bugs in this pool
        $dbh->do("UPDATE bug_agile_pool
                    SET pool_order = pool_order + 1
                  WHERE pool_id = ? AND pool_order >= ?",
            undef, ($self->id, $order));
        # Insert new entry
        $dbh->do("INSERT INTO bug_agile_pool (bug_id, pool_id, pool_order)
                      VALUES (?, ?, ?)",
            undef, ($bug_id, $self->id, $order));
        delete $self->{bugs};
    }
    $dbh->bz_commit_transaction();
    return $self->bugs;
}

#TODO: Add pool and pool_order methods to Bug class


1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::Object>


