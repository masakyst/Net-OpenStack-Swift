package Net::OpenStack::Swift::Util;

use strict;
use warnings;
use Encode;
use URI::Escape;
use Data::Dumper;

sub import {
    no strict 'refs';
    my $pkg = caller(0);
    *{"$pkg\::uri_escape"} = \&_uri_escape;
}

sub _uri_escape {
    my $value = shift;
    if (utf8::is_utf8($value)) {
        return uri_escape_utf8($value);
    }
    else {
        return uri_escape($value);
    }
}

1;
