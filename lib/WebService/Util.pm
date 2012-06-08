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

Bugzilla::Extension::AgileTools::WebService::Util

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
