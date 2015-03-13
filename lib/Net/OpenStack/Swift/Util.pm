package Net::OpenStack::Swift::Util;

use strict;
use warnings;
use Encode;
use URI::Escape qw//;
use Exporter 'import';
our @EXPORT_OK = qw(uri_escape uri_unescape);


sub uri_escape {
    my $value = shift;
    if (utf8::is_utf8($value)) {
        return URI::Escape::uri_escape_utf8($value);
    }
    else {
        return URI::Escape::uri_escape($value);
    }
}

sub uri_unescape {
    my $value = shift;
    return URI::Escape::uri_unescape($value);
}

1;
