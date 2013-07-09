# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2013 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Backlog

=head1 DESCRIPTION

Backlog object connects Team to backlog pool

=head1 FIELDS

=over

=item C<pool_id> - ID of the pool related to this backlog

=item C<team_id> - ID of the team owning this backlog, undef if not assigned to
                   any team

=back

=cut

use strict;
package Bugzilla::Extension::AgileTools::Backlog;

use base qw(Bugzilla::Object);

use Scalar::Util qw(blessed);

use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Hook;
use Bugzilla::Util qw(detaint_natural trim);


sub DB_TABLE {
    # We can only join the pool table for the name field when fetching items,
    # not when creating or updating.
    #
    # This is prone to break on bugzilla changes, but couldn't find a more
    # robust way to do it without overriding most of the Bugzilla::Object
    # methods.
    my (undef, undef, undef, $sub) = caller(1);
    if ($sub eq "Bugzilla::Object::_do_list_select" ||
        $sub eq "Bugzilla::Object::_init") {
        return "agile_backlog LEFT JOIN agile_pool ON ".
               "agile_backlog.pool_id = agile_pool.id";
    } else {
        return 'agile_backlog';
    }
}

use constant DB_COLUMNS => (
    'pool_id',
    'team_id',
    'agile_pool.name AS name',
);

use constant LIST_ORDER => 'agile_pool.name';

use constant ID_FIELD => 'pool_id';

use constant NUMERIC_COLUMNS => qw(
    pool_id
    team_id
);

use constant UPDATE_COLUMNS => qw(
    team_id
);

use constant VALIDATORS => {
    team_id => \&_check_team_id,
    name => \&_check_name,
};

use constant VALIDATOR_DEPENDENCIES => {
};

use constant EXTRA_REQUIRED_FIELDS => qw(
    name
);

# Accessors
###########

sub team_id     { return $_[0]->{team_id}; }

sub team {
    my $self = shift;
    if (!exists $self->{team}) {
        $self->{team} = defined $self->team_id ?
            Bugzilla::Extension::AgileTools::Team->new($self->team_id) :
            undef;
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

sub set_team_id  { $_[0]->set('team_id', $_[1]); delete $_[0]->{team}; }
sub set_name     { $_[0]->set('name', $_[1]); }

# Validators
############

sub _check_team_id {
    my ($invocant, $value) = @_;
    if (defined $value && detaint_natural($value)) {
        return Bugzilla::Extension::AgileTools::Team->check({id => $value})->id;
    }
    return undef;
}

sub _check_name {
    my ($invocant, $name) = @_;
    $name = trim($name);
    ThrowUserError('invalid_parameter', {
            name => 'name',
            err => 'Name must not be empty'})
        unless $name;
    return $name;
}

sub create {
    my ($class, $params) = @_;

    $class->check_required_create_fields($params);
    # Create pool for this backlog
    my $pool = Bugzilla::Extension::AgileTools::Pool->create(
        {name => delete $params->{name}});

    my $clean_params = $class->run_create_validators($params);
    $clean_params->{$class->ID_FIELD} = $pool->id;

    my $backlog = $class->insert_create_data($clean_params);
    return $backlog;
}

# Object->insert_create_data does not work with non serial id on postgresql
sub insert_create_data {
    my ($class, $field_values) = @_;
    my $dbh = Bugzilla->dbh;

    my (@field_names, @values);
    while (my ($field, $value) = each %$field_values) {
        $class->_check_field($field, 'create');
        push(@field_names, $field);
        push(@values, $value);
    }

    my $qmarks = '?,' x @field_names;
    chop($qmarks);
    my $table = $class->DB_TABLE;
    $dbh->do("INSERT INTO $table (" . join(', ', @field_names)
             . ") VALUES ($qmarks)", undef, @values);

    my $object = $class->new($field_values->{$class->ID_FIELD});

    Bugzilla::Hook::process('object_end_of_create', { class => $class,
                                                      object => $object });
    return $object;
}

sub update {
    my $self = shift;
    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();
    my($changes, $old) = $self->SUPER::update(@_);
    if($self->name ne $old->name) {
        $self->pool->set_all({name => $self->name});
        my $poolchanges = $self->pool->update();
        $changes->{name} = $poolchanges->{name};
    }
    $dbh->bz_commit_transaction();
    if (wantarray) {
        return ($changes, $old);
    }
    return $changes;
}

sub remove_from_db {
    my $self = shift;
    ThrowUserError("agile_permission_denied",
            {permission=>'delete active sprint'})
        if $self->is_active;
    # Take pool for later deletion
    my $pool = $self->pool;
    $self->SUPER::remove_from_db(@_);
    $pool->remove_from_db();
}

sub TO_JSON {
    my $self = shift;
    # fetch the pool
    $self->name;
    return { %{$self} };
}

1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::Object>

