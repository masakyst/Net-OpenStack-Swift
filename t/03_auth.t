use strict;
use Test::More;
use Net::OpenStack::Swift;

my $sw = Net::OpenStack::Swift->new(
    auth_url     => 'https://objectstore-test.swift/v2.0',
    user         => '1234567',
    password     => 'abcdefg',
    tenant_name  => '1234567',
    #auth_version => '2.0',
);

is $sw->auth_version, '2.0';
is $sw->auth_url, 'https://objectstore-test.swift/v2.0';
is $sw->user, '1234567';
is $sw->password, 'abcdefg';
is $sw->tenant_name, '1234567';
is $sw->token, undef;
is $sw->storage_url, undef;

done_testing;
