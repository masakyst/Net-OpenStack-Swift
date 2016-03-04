requires 'Mouse';
requires 'namespace::clean';
requires 'JSON';
requires 'Furl';
requires 'URI::Escape';
requires 'IO::Socket::SSL';
requires 'Data::Validator';
requires 'Log::Minimal';
requires 'App::Rad';
requires 'Text::ASCIITable';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::MockObject';
    requires 'Test::MockObject::Extends';
    requires 'Data::Section::Simple';
};

