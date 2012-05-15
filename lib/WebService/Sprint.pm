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

Bugzilla::Extension::AgileTools::WebService::Sprint

=head1 DESCRIPTION

Web service methods available under namespase 'Agile.Sprint'.

=cut

use strict;
use warnings;

package Bugzilla::Extension::AgileTools::WebService::Sprint;

use base qw(Bugzilla::WebService);

use Bugzilla::Error;
use Bugzilla::Extension::AgileTools::Sprint;

use Bugzilla::Extension::AgileTools::Util qw(get_team get_role get_user);

=head1 METHODS

=over

=item C<get>

    Description: Fetch sprint info
    Params:      id - Sprint ID
    Returns:     The sprint object

=cut

sub get {
    my ($self, $params) = @_;
    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.update',
            param => 'id'})
        unless defined $params->{id};
    return Bugzilla::Extension::AgileTools::Sprint->check({
            id => $params->{id}});
}


=item C<create>

    Description: Create new sprint
    Params:      team_id - Team id
                 start_date - Start date of the sprint
                 end_date - End date of the sprint
    Returns:     Created sprint object

=cut

sub create {
    my ($self, $params) = @_;

    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.create',
            param => 'team_id'})
        unless defined $params->{team_id};
    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.create',
            param => 'start_date'})
        unless defined $params->{start_date};
    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.create',
            param => 'end_date'})
        unless defined $params->{end_date};

    return Bugzilla::Extension::AgileTools::Sprint->create($params);
}

=item C<update>

    Description: Updates sprint details
    Params:      id - Sprint ID
                 start_date - (optional) Change start_date
                 end_date - (optional) Change end_date
    Returns:     Hash with 'id' and 'changes' like from L<Bugzilla::Object::update> 

=cut

sub update {
    my ($self, $params) = @_;

    ThrowCodeError('param_required', {
            function => 'Agile.Sprint.update',
            param => 'id'})
        unless defined $params->{id};

    my $sprint = Bugzilla::Extension::AgileTools::Sprint->check({
            id =>delete $params->{id} });
    $sprint->set_all($params);
    my $changes = $sprint->update();
    return { id => $sprint->id, changes => $changes };
}

1;

__END__

=back

=head1 SEE ALSO

L<Bugzilla::WebService>
