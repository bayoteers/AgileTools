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

use strict;
package Bugzilla::Extension::AgileTools::Team;

use base qw(Bugzilla::Object);

use Bugzilla::Group;
use Bugzilla::User;
use Bugzilla::Error;
use Bugzilla::Util qw(trim);

use Scalar::Util qw(blessed);

use constant DB_TABLE => 'agile_teams';

use constant DB_COLUMNS => qw(
    id
    name
    group_id
    process_id
);

use constant NUMERIC_COLUMNS => qw(
    group_id
    process_id
);

use constant UPDATE_COLUMNS => qw(
    name
    group_id
    process_id
);

use constant VALIDATORS => {
    name => \&_check_name,
};

# Accessors
###########

sub group_id   { return $_[0]->{group_id}; }
sub process_id { return $_[0]->{process_id}; }

sub group {
    my $self = shift;
    $self->{group} ||= Bugzilla::Group->new($self->group_id);
    return $self->{group};
}

# Mutators
##########

sub set_name       { $_[0]->set('name', $_[1]); }
sub set_group_id   { $_[0]->set('group_id', $_[1]); }
sub set_process_id { $_[0]->set('process_id', $_[1]); }

sub set_group {
    my ($self, $value) = @_;
    my $group_id;
    if (ref($value)) {
        $group_id = $value->id;
    } elsif ($value =~ /\d+/) {
        $group_id = $value;
    } else {
        $group_id = Bugzilla::Group->check($value)->id;
    }
    $self->set('group_id', $group_id);
}

# Validators
############

sub _check_name {
    my ($invocant, $name) = @_;
    $name = trim($name);
    $name || ThrowUserError("empty_team_name");

    # If we're creating a Team or changing the name...
    if (!ref($invocant) || lc($invocant->name) ne lc($name)) {
        my $exists = new Bugzilla::Extension::AgileTools::Team({name => $name});
        ThrowUserError("agile_team_exists", { name => $name }) if $exists;

        # Check that there is no group with that name...
        $exists = new Bugzilla::Group({name => $name});
        ThrowUserError("group_exists", { name => $name }) if $exists;
    }
    return $name;
}

# Methods
#########

sub members {
    my $self = shift;
    return [] unless $self->id;
    return $self->group->members_non_inherited();
}

sub components {
    my $self = shift;
    return $self->{components} if defined $self->{components};
    return [] unless $self->id;

    my $dbh = Bugzilla->dbh;
    my $component_ids = $dbh->selectcol_arrayref(
        "SELECT component_id
           FROM agile_team_component_map
          WHERE team_id = ?", undef, $self->id);
    $self->{components} = Bugzilla::Component->new_from_list($component_ids);
    return $self->{components};
}

sub add_component {
    my ($self, $component) = @_;

    if (!blessed $component) {
        if ($component =~ /^\d+$/) {
            $component = Bugzilla::Component->check({id => $component});
        } else {
            ThrowCodeError("bad_arg", { argument => $component,
                    function => "Team::add_component" });
        }
    }
    my $dbh = Bugzilla->dbh;
    $dbh->bz_start_transaction();

    # Check that component is not already included
    my $included = $dbh->selectrow_array(
        "SELECT 1 FROM agile_team_component_map
          WHERE team_id = ? AND component_id = ?",
        undef, ($self->id, $component->id));
    my $rows = 0;
    if (!$included) {
        $rows = $dbh->do("INSERT INTO agile_team_component_map
            (team_id, component_id) VALUES (?, ?)",
            undef, ($self->id, $component->id));

        # Push the new component in cache if it has been fetched
        push(@{$self->{components}}, $component)
                if defined $self->{components};
    }
    $dbh->bz_commit_transaction();
    return $rows;
}

sub remove_component {
    my ($self, $component) = @_;
    my $component_id;
    if (blessed $component) {
        $component_id = $component->id;
    } elsif ($component =~ /^\d+$/) {
        $component_id = $component;
    } else {
        ThrowCodeError("bad_arg", { argument => $component,
                function => "Team::remove_component" });
    }
    my $dbh = Bugzilla->dbh;

    my $rows = $dbh->do(
        "DELETE FROM agile_team_component_map
               WHERE team_id = ? AND component_id = ?",
               undef, ($self->id, $component_id));

    if ($rows && defined $self->{components}) {
        my @components;
        foreach my $item (@{$self->{components}}) {
            next if ($item->id == $component_id);
            push(@components, $item);
        }
        $self->{components} = \@components;
    }
    return $rows;
}


sub keywords {
    my $self = shift;
    return $self->{keywords} if defined $self->{keywords};
    return [] unless $self->id;

    my $dbh = Bugzilla->dbh;
    my $keyword_ids = $dbh->selectcol_arrayref(
        'SELECT keyword_id FROM agile_team_keyword_map '.
        'WHERE team_id = ?', undef, $self->id);
    $self->{keywords} = Bugzilla::Keyword->new_from_list($keyword_ids);
    return $self->{keywords};
}

sub update {
    my $self = shift;

    my($changes, $old) = $self->SUPER::update(@_);

    if ($changes->{name}) {
        # Reflect the name change on the group
        my $new_name = $changes->{name}->[1];
        $self->group->set_all({
                name => $new_name,
                description => "'" . $new_name . "' team member group",
            }
        );
        $self->group->update();
    }

    if (wantarray) {
        return ($changes, $old);
    }
    return $changes;
}

sub create {
    my ($class, $params) = @_;

    $class->check_required_create_fields($params);
    my $clean_params = $class->run_create_validators($params);

    # Greate the group and put ID in params
    my $group = Bugzilla::Group->create({
            name => $params->{name},
            description => "'" . $params->{name} . "' team member group",
            # isbuggroup = 0 means system group
            isbuggroup => 0,
        }
    );
    $clean_params->{group_id} = $group->id;

    return $class->insert_create_data($clean_params);
}

sub remove_from_db {
    my $self = shift;
    my $group = $self->group;
    $self->SUPER::remove_from_db(@_);

    # We need to trick group to think that its not a system group
    $group->{isbuggroup} = 1;
    $group->remove_from_db();
}

# Add team methods in Bugzilla::User class
##########################################

BEGIN {
    *Bugzilla::User::agile_teams = sub {
        my $self = shift;
        return Bugzilla::Extension::AgileTools::Team->match(
            { WHERE => {'group_id IN (?)' => $self->groups_as_string} });
    };
}



1;

__END__

=head1 NAME

Bugzilla::Extension::AgileTools::Team

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools::Team

    my $team = new Bugzilla::Extension::AgileTools::Team(1);

    my $team_id = $team->id;
    my $name = $team->name;
    my $group = $team->group;
    my $group_id = $team->group_id;
    my $process_id = $team->process_id;

    my @members = @{$team->memebers};
    my @component_resposibilities = @{$team->components};
    my @keyword_resposibilities = @{$team->keywords};

    my @teams = Bugzilla::Extension::AgileTools::Team->get_all;

    my $user = new Bugzilla::User(1);
    my @teams = @{$user->agile_teams};

=head1 DESCRIPTION

Team.pm presents a AgileTools Team object inherited from L<Bugzilla::Object>
and has all the same methods, plus the ones described below.

=head1 METHODS

=over

=item C<members>

Description: Gets the list of team members.

Returns:     Array ref of L<Bugzilla::User> objects.


=item C<components>

Description: Gets the list of components the team is responsible of

Returns:     Array ref of L<Bugzilla::Component> objects


=item C<add_component($component)>

Description: Adds new component into team responsibilities.

Params:      $component - Component object or id to add.

Returns:     Number of components affected.

Notes:       Throws an error if component with given id does not exist.


=item C<remove_component($component)

Description: Removes component from team responsibilities

Params:      $component - Component object or id to remove.

Returns:     Number of components affected.


=item C<keywords>

Description: Gets the list of keywords the team is responsible of

Returns:     Array ref of L<Bugzilla::Keyword> objects

=back

=head1 RELATED METHODS

The L<Bugzilla::User> object is also extended to provide easy access to teams
where particular user is a member.

=over

=item C<Bugzilla::User::agile_teams>

Description: Returns the list of teams the user is member in.

Returns:     Array ref of C<Bugzilla::Extension::AgileTools::Team> objects.

=back
