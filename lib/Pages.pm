# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2013-2014 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jolla.com>

=head1 NAME

Bugzilla::Extension::AgileTools::Pages

=head1 DESCRIPTION

Generic page handler functions

=cut

use strict;
use warnings;
package Bugzilla::Extension::AgileTools::Pages;

use Bugzilla::Error;

=head1 HANDLERS

=over

=item C<admin> - The AgileTools admin page

=cut

sub admin {
    my ($vars) = @_;
    warn "admin";
    ThrowUserError('auth_failure', {
                group => 'admin',
                action => 'access'
            }) unless Bugzilla->user->in_group('admin');
    my $cgi = Bugzilla->cgi;
    my $dbh = Bugzilla->dbh;
    my %backlogs = map {$_->id => $_} Bugzilla::Extension::AgileTools::Backlog->get_all();
    my $bugcounts = $dbh->selectall_hashref(
        "SELECT pool_id, COUNT(bug_id) AS count FROM bug_agile_pool WHERE " .
            $dbh->sql_in('pool_id', [keys %backlogs]) . "GROUP BY pool_id", 'pool_id');
    for (values %backlogs) {
        $_->{bug_count} = $bugcounts->{$_->id}->{count};
    }

    my $action = scalar $cgi->param('action') || '';
    my $blid = scalar $cgi->param('backlog_id') || 0;
    if ($action eq 'delete_backlog') {
        my $backlog = delete $backlogs{$blid};
        if (defined $backlog) {
            ThrowUserError('agile_backlog_has_bugs') if $backlog->{bug_count};
            $backlog->remove_from_db();
            $vars->{message} = "agile_backlog_removed";
            $vars->{backlog} = $backlog;
        } else {
            ThrowUserError('object_does_not_exist', { id => $blid,
                class => 'Bugzilla::Extension::AgileTools::Backlog' });
        }
    } elsif ($action eq 'save_backlog') {
        my $backlog = $backlogs{$blid};
        $backlog->set_all({name=> scalar $cgi->param('backlog_name')});
        $vars->{changes} = $backlog->update();
        $vars->{message} = "agile_backlog_saved";
        $vars->{backlog} = $backlog;
    }
    $vars->{backlogs} = [sort { $a->name cmp $b->name } values %backlogs];
}

1;
__END__

=back
