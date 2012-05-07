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

    my $bug_ids = dbh->selectcol_arrayref(
        "SELECT bug_id FROM bug_agile_pool
          WHERE pool_id = ? ORDER BY pool_order",
          undef, $self->id);
    return Bugzilla::Bug->new_from_list($bug_ids);
}

=item C<add_bug($bug_id, $order)>

    Description: Adds new bug into the pool
    Params:      $bug_id - Bug ID
                 $order - (optional) Order of the new bug in this pool

=cut

sub add_bug {
    my $self = shift;
    my ($bug_id, $order) = @_;

    ThrowUserError("invalid_parameter", {name=>'bug_id', err=>'Not a number'})
        unless detaint_natural(bug_id);
    ThrowUserError("invalid_parameter", {name=>'order', err=>'Not a number'})
        unless detaint_natural(order);

    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();
    my $max = $dbh->selectcol_arrayref(
        "SELECT COALESCE(MAX(pool_order), 0)
           FROM bug_agile_pool
          WHERE bug_id = ? AND pool_id = ?",
          undef, ($bug_id, $self->id))->[0];
    if (! defined $order || $order > $max) {
        $order = $max + 1;
    }
    my $existing = $dbh->selectcol_arrayref(
        "SELECT pool_order
           FROM bug_agile_pool
          WHERE bug_id = ? AND pool_id = ?",
          undef, ($bug_id, $self->id))->[0];

    if (defined $existing) {
        
    } else {

    }
    dbh->do(
        "UPDATE bug_agile_pool
            SET order
          WHERE pool_id = ? ORDER BY pool_order",
          undef, $self->id);

}

=back

=head1 SEE ALSO

L<Bugzilla::Object>


