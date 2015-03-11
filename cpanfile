requires 'Moo';
requires 'JSON';
requires 'Furl';
requires 'URI::Escape';
requires 'IO::Socket::SSL';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

