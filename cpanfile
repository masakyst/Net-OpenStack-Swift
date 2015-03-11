requires 'Moo';
requires 'JSON';
requires 'Furl';
requires 'IO::Socket::SSL';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

