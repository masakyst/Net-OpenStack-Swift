requires 'Mouse';
requires 'namespace::clean';
requires 'JSON';
requires 'Furl';
requires 'URI::Escape';
requires 'IO::Socket::SSL';
requires 'Data::Validator';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

