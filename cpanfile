requires 'perl', '5.008001';
requires 'JSON';
requires 'Furl';
requires 'IO::Socket::SSL';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

