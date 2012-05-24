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

Bugzilla::Extension::AgileTools::WebService::Pool

=head1 DESCRIPTION

Web service methods available under namespase 'Agile.Pool'.

=cut

use strict;
use warnings;

package Bugzilla::Extension::AgileTools::WebService::Pool;

use base qw(Bugzilla::WebService);

use Bugzilla::Error;
use Bugzilla::WebService::Bug;

use Bugzilla::Extension::AgileTools::Sprint;

use Bugzilla::Extension::AgileTools::Util qw(get_team get_role get_user);

=head1 METHODS

=over

=item C<get>

    Description: Pool info
    Params:      id - Sprint ID
    Returns:     { name => 'pool name', bugs => [ list of bugs... ] }

=cut

sub get {
    my ($self, $params) = @_;
    ThrowCodeError('param_required', {
            function => 'Agile.Pool.get',
            param => 'id'})
        unless defined $params->{id};
    my $pool = Bugzilla::Extension::AgileTools::Pool->check({
            id => $params->{id}});
    my @bugs;
    foreach my $bug (sort { $a->pool_order cmp $b->pool_order } @{$pool->bugs}) {
        my $bug_hash = Bugzilla::WebService::Bug::_bug_to_hash(
            $self, $bug, $params);
        $bug_hash->{pool_order} = $self->type("int", $bug->pool_order);
        $bug_hash->{pool_id} = $self->type("int", $bug->pool_id);
        push(@bugs, $bug_hash);
    }

    return { name => $pool->name, id =>, $pool->id, bugs => \@bugs };
}


=item C<add_bug>

    Description: Add new bug into the pool
    Params:      id - Pool id
                 bug_id - Bug id
                 order - (optional) Order of the bug in pool, last if not given
    Returns:     ???

=cut

sub add_bug {
    my ($self, $params) = @_;

    ThrowCodeError('param_required', {
            function => 'Agile.Pool.add_bug',
            param => 'id'})
        unless defined $params->{id};
    ThrowCodeError('param_required', {
            function => 'Agile.Pool.add_bug',
            param => 'bug_id'})
        unless defined $params->{bug_id};

    my $pool = Bugzilla::Extension::AgileTools::Pool->check({
            id => $params->{id}});

    my $changed = $pool->add_bug($params->{bug_id}, $params->{order});
    return { name => $pool->name, changed => $changed };
}

=item C<remove_bug>

    Description: Remove bug from the pool
    Params:      id - Pool ID
                 bug_id - Bug ID
    Returns:     ???

=cut

sub remove_bug {
    my ($self, $params) = @_;

    ThrowCodeError('param_required', {
            function => 'Agile.Pool.remove_bug',
            param => 'id'})
        unless defined $params->{id};
    ThrowCodeError('param_required', {
            function => 'Agile.Pool.remove_bug',
            param => 'bug_id'})
        unless defined $params->{bug_id};

    my $pool = Bugzilla::Extension::AgileTools::Pool->check({
            id => $params->{id}});

    my $changed = $pool->remove_bug($params->{bug_id});
    return { name => $pool->name, changed => $changed };
}

1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::WebService>

