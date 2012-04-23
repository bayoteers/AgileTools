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

package Bugzilla::Extension::AgileTools::Util;
use strict;
use base qw(Exporter);
our @EXPORT = qw(
    get_user
);

sub get_user {
    my $user = shift;
    if (!blessed $user) {
        if ($user =~ /^\d+$/) {
            $user = Bugzilla::User->check({id => $user});
        } else {
            $user = Bugzilla::User->check($user);
        }
    }
    return $user;
}

# This file can be loaded by your extension via 
# "use Bugzilla::Extension::AgileTools::Util". You can put functions
# used by your extension in here. (Make sure you also list them in
# @EXPORT.)

1;

__END__

=head1 NAME

Bugzilla::Extension::AgileTools::Util

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools::Util;

    my $user = get_user(1);
    my $user = get_user('john.doe@example.com');

=head1 DESCRIPTION

AgileTools extension utility functions

=head1 FUNCTIONS

=over

=item C<get_user($user)>

Description: Gets user object or throws error if user is not found

Params:      $user -> User ID or login name

Returns:     L<Bugzilla::User> object

=back
