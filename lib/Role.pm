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

Bugzilla::Extension::AgileTools::Role

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools::Role;

    my $role = new Bugzilla::Extension::AgileTools::Role(1);

    my $role_id = $role->id;
    my $name = $role->name;
    my $is_custom = $role->custom;
    my $can_edit_team = $role->can_edit_team;

    my $roles = Bugzilla->user-agile_team_roles($team);

=head1 DESCRIPTION

Role object represents a user role in a team and defines some permissions that
the user has regarding the team. Role is inherited from L<Bugzilla::Object>.

=head1 FIELDS

=over

=item C<name> - Role name

=item C<is_custom> - Is this a custom role or built-in

=item C<can_edit_team> - IS the member with this role allowed to edit the team

=back

=cut

use strict;
package Bugzilla::Extension::AgileTools::Role;

use base qw(Bugzilla::Object);

use Bugzilla::Extension::AgileTools::Util qw(get_user);

use Bugzilla::Constants;
use Bugzilla::Util qw(trim);


use constant DB_TABLE => 'agile_role';

use constant DB_COLUMNS => qw(
    id
    name
    custom
    can_edit_team
);

use constant NUMERIC_COLUMNS => qw(
    custom
    can_edit_team
);

use constant UPDATE_COLUMNS => qw(
    name
    can_edit_team
);

use constant VALIDATORS => {
    name => \&_check_name,
};

# Accessors
###########

sub custom        { return $_[0]->{custom}; }
sub can_edit_team { return $_[0]->{can_edit_team}; }

# Mutators
##########

sub set_name          { $_[0]->set('name', $_[1]); }
sub set_custom        { $_[0]->set('custom', $_[1]); }
sub set_can_edit_team { $_[0]->set('can_edit_team', $_[1]); }

# Validators
############

sub _check_name {
    my ($invocant, $name) = @_;
    $name = trim($name);
    $name || ThrowUserError("agile_empty_name");
    return $name;
}

=head1 METHODS

=over

=item C<add_user_role($team, $user)>

    Description: Add role for user in specific team
    Params:      $team - Team object where user role is added
                 $user - User object, id or login name for which the role is added

=cut

sub add_user_role {
    my ($self, $team, $user) = @_;
    $user = get_user($user);

    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();
    my $has_role = $dbh->selectrow_array(
        "SELECT 1 FROM agile_user_role
          WHERE role_id = ? AND
                team_id = ? AND
                user_id = ?",
        undef, ($self->id, $team->id, $user->id));
    if (!$has_role) {
        $dbh->do("INSERT INTO agile_user_role
                              (role_id, team_id, user_id)
                       VALUES (?, ?, ?)",
            undef, ($self->id, $team->id, $user->id));
    }
    $dbh->bz_commit_transaction();
    return $has_role ? 0 : 1;
}

=item C<remove_user_role($team, $user)>

    Description: Remove user role in specific team.
    Params:      $team - Team object where user role is removed
                 $user - User object, id or login name from which the role is
                         removed

=cut

sub remove_user_role {
    my ($self, $team, $user) = @_;
    $user = get_user($user);

    my $dbh = Bugzilla->dbh;

    $dbh->bz_start_transaction();
    my $has_role = $dbh->selectrow_array(
        "SELECT 1 FROM agile_user_role
          WHERE role_id = ? AND
                team_id = ? AND
                user_id = ?",
        undef, ($self->id, $team->id, $user->id));
    if ($has_role) {
        $dbh->do("DELETE FROM agile_user_role
                        WHERE role_id = ? AND
                              team_id = ? AND
                              user_id = ?",
            undef, ($self->id, $team->id, $user->id));
    }
    $dbh->bz_commit_transaction();
    return $has_role ? 1 : 0;
}

=back

=head1 CLASS FUNCTIONS

=over

=item C<get_user_roles($team, $user)>

    Description: Get users roles in specific team.
    Params:      $team - Team object for which to get the roles
                 $user - User object, id or login name for which to get the
                         roles
    Returns:     Array ref of Role objects

=cut

sub get_user_roles {
    my ($class, $team, $user) = @_;
    $user = get_user($user);
    my $dbh = Bugzilla->dbh;

    my $role_ids = $dbh->selectcol_arrayref(
        "SELECT role_id FROM agile_user_role
          WHERE team_id = ? AND
                user_id = ?",
        undef, ($team->id, $user->id));
    return $class->new_from_list($role_ids);
}


# Overridden Bugzilla::Object methods
#####################################

sub create {
    my $class = shift;
    my ($params) = @_;

    # Display the initial roles added on checksetup run
    if (Bugzilla->usage_mode == USAGE_MODE_CMDLINE) {
        print "Creating AgileTools team member role '". $params->{name} ."'\n";
    }

    return $class->SUPER::create(@_);
}

=back

=head1 RELATED METHODS

=head2 Bugzilla::User object methods

The L<Bugzilla::User> object is also extended to provide easy access to team
member roles.

    my $roles = Bugzilla->user->agile_team_roles($team);

=over

=item C<agile_team_roles($team)>

    Description: Returns the list of roles the user has in specific team
    Params:      $team - Team object
    Returns:     Array ref of C<Bugzilla::Extension::AgileTools::Role> objects.

=cut

BEGIN {
    *Bugzilla::User::agile_team_roles = sub {
        my ($self, $team) = @_;
        $self->{agile_team_roles} ||= {};
        if (!defined $self->{agile_team_roles}->{$team->id}) {
            $self->{agile_team_roles}->{$team->id} =
                Bugzilla::Extension::AgileTools::Role->get_user_roles($team, $self);
        }
        return $self->{agile_team_roles}->{$team->id}
    };
}
1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::Object>
