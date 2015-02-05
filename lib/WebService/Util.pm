# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jollamobile.com>

=head1 NAME

Bugzilla::Extension::AgileTools::WebService::Util - AgileTools WS utility functions

=head1 SYNOPSIS

    use Bugzilla::Extension::AgileTools::WebService::Util;

    my $object = Bugzilla::SomeObject->new($id);

    my $ws_typed_hash = object_to_hash($webservice, $object,
        {
            id => "int",
            name => "string",
            date => "dateTime",
        });

    my $changes = $object->update();

    my $ws_typed_hash = changes_to_hash($webservice, $changes,
        {
            id => "int",
            name => "string",
            date => "dateTime",
        });

=head1 DESCRIPTION

Utility functions for webservices

=cut

package Bugzilla::Extension::AgileTools::WebService::Util;
use strict;
use warnings;

use constant PUBLIC_METHODS => qw(
    object_to_hash
    changes_to_hash
);

use base qw(Exporter);
our @EXPORT = qw(
    object_to_hash
    changes_to_hash
);

=head1 FUNCTIONS

=over

=item C<object_to_hash($webservice, $object, $field_types)>

    Description: Converts object field values in corresponding Webservice typed
                 value 
    Params:      $webservice - WebService object
                 $object - Object, which has accessor methods for corresponding
                           fields defined in $field_types
                 $field_types - Hash ref which maps field name => field type
    Returns:     Hash ref, where
                    $field_name => WebService->type(
                            $field_type, $object->$field_name)

=cut

sub object_to_hash {
    my ($ws, $object, $field_types) = @_;
    my %hash;
    for my $field (keys %$field_types) {
        $hash{$field} = $ws->type($field_types->{$field}, $object->$field);
    }
    return \%hash;
}


=over

=item C<changes_to_hash($webservice, $changes, $field_types)>

    Description: Similar as object_to_hash, except takes changes hash returned
                 by Bugzilla::Object->update() and returns hash with same
                 structure and values converted to webservice type

=cut

sub changes_to_hash {
    my ($ws, $changes, $field_types) = @_;
    my %hash;
    for my $field (keys %$changes) {
        my @tmp;
        # Pass unknown fields as string
        my $type = $field_types->{$field} || "string";
        for my $value (@{$changes->{$field}}) {
            push(@tmp, $ws->type($type, $value));
        }
        $hash{$field} = \@tmp;
    }
    return \%hash;
}

1;

__END__

=back
