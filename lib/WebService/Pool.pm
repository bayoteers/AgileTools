# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::WebService::Pool - Pool manipultaion WS methods

=head1 DESCRIPTION

Web service methods available under namespace 'Agile.Pool'.

=cut

use strict;
use warnings;

package Bugzilla::Extension::AgileTools::WebService::Pool;

use base qw(Bugzilla::WebService);

use Bugzilla::Constants;
use Bugzilla::Error;

use Bugzilla::Extension::AgileTools::Sprint;

use Bugzilla::Extension::AgileTools::Util;
use Bugzilla::Extension::AgileTools::WebService::Util;

# Use the _bug_to_hash method from Bugzilla::WebService::Bug
use Bugzilla::WebService::Bug;
BEGIN {
  *_bug_to_hash = \&Bugzilla::WebService::Bug::_bug_to_hash;
  if (Bugzilla::WebService::Bug->can('_flag_to_hash')) {
    *_flag_to_hash = \&Bugzilla::WebService::Bug::_flag_to_hash;
  }
}


# Webservice field type mapping
use constant FIELD_TYPES => {
    "id" => "int",
    "name" => "string",
};

use constant PUBLIC_METHODS => qw(
    get
    add_bug
    remove_bug
);

=head1 METHODS

=over

=item C<get>

    Description: Pool info
    Params:      id - Sprint ID
    Returns:     { name => 'pool name', bugs => [ list of bugs... ] }

=cut

sub get {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);

    ThrowCodeError('param_required', {
            function => 'Agile.Pool.get',
            param => 'id'})
        unless defined $params->{id};
    my $pool = Bugzilla::Extension::AgileTools::Pool->check({
            id => $params->{id}});
    my @bugs;
    foreach my $bug (sort { $a->pool_order cmp $b->pool_order } @{$pool->bugs}) {
        my $bug_hash = $self->_bug_to_hash($bug, $params);
        $bug_hash->{pool_order} = $self->type("int", $bug->pool_order);
        $bug_hash->{pool_id} = $self->type("int", $bug->pool_id);
        push(@bugs, $bug_hash);
    }
    my $hash = object_to_hash($self, $pool, FIELD_TYPES);
    $hash->{bugs} = \@bugs;

    return $hash;
}


=item C<add_bug>

    Description: Add new bug into the pool
    Params:      id - Pool id
                 bug_id - Bug id
                 order - (optional) Order of the bug in pool, last if not given

=cut

sub add_bug {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);

    ThrowCodeError('param_required', {
            function => 'Agile.Pool.add_bug',
            param => 'id'})
        unless defined $params->{id};
    ThrowCodeError('param_required', {
            function => 'Agile.Pool.add_bug',
            param => 'bug_id'})
        unless defined $params->{bug_id};

    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction;
    my $pool = Bugzilla::Extension::AgileTools::Pool->check({
            id => $params->{id}});
    my $bug = Bugzilla::Bug->check({id => $params->{bug_id}});

    my $delta_ts = $bug->delta_ts;
    $bug->set_all({pool_id => $pool->id, pool_order => $params->{order}});
    $bug->update();
    unless ($delta_ts gt ($bug->lastdiffed || '')) {
        $dbh->do("UPDATE bugs SET lastdiffed = NOW() WHERE bug_id = ?",
            undef, $bug->id);
    }
    $dbh->bz_commit_transaction;
}

=item C<remove_bug>

    Description: Remove bug from the pool
    Params:      id - Pool ID
                 bug_id - Bug ID

=cut

sub remove_bug {
    my ($self, $params) = @_;
    Bugzilla->login(LOGIN_REQUIRED);
    user_in_agiletools_group(1);

    ThrowCodeError('param_required', {
            function => 'Agile.Pool.remove_bug',
            param => 'id'})
        unless defined $params->{id};
    ThrowCodeError('param_required', {
            function => 'Agile.Pool.remove_bug',
            param => 'bug_id'})
        unless defined $params->{bug_id};

    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction;
    my $bug = Bugzilla::Bug->check({id => $params->{bug_id}});
    ThrowCodeError('bug_not_in_pool') unless $bug->pool_id == $params->{id};
    my $delta_ts = $bug->delta_ts;
    $bug->set_pool_id(undef);
    $bug->update();
    unless ($delta_ts gt ($bug->lastdiffed || '')) {
        $dbh->do("UPDATE bugs SET lastdiffed = NOW() WHERE bug_id = ?",
            undef, $bug->id);
    }
    $dbh->bz_commit_transaction;
}

1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::WebService>

