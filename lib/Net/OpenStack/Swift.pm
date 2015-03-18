package Net::OpenStack::Swift;

=pod

python swift clientの説明
http://blog.bit-isle.jp/bird/2013/03/42

V3
http://docs.openstack.org/developer/keystone/api_curl_examples.html

ConoHa
https://www.conoha.jp/guide/guide.php?g=52

=cut

use strict;
use warnings;
use Carp;
use Mouse;
use JSON;
use Data::Validator;
use Net::OpenStack::Swift::Util qw/uri_escape uri_unescape debugf/;
use Net::OpenStack::Swift::InnerKeystone;
use namespace::clean -except => 'meta';

our $VERSION = "0.01";


has auth_version => (is => 'rw', required => 1, default => sub {"2.0"}); 
has auth_url     => (is => 'rw', required => 1); 
has user         => (is => 'rw', required => 1); 
has password     => (is => 'rw', required => 1); 
has tenant_name  => (is => 'rw');
has storage_url  => (is => 'rw');
has token        => (is => 'rw');
#has verify_ssl   => (is => 'ro', default => sub {! $ENV{OSCOMPUTE_INSECURE}});
has agent => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $agent = Furl->new(
            #agent    => "Mozilla/5.0",
        );  
        return $agent;
    },  
);

sub _request {
    my $self = shift;
    # todo: contentがでかい場合referenceのがいい
    my %args = @_;
    my $res = $self->agent->request(
        method          => $args{method},
        url             => $args{url},
        #special_headers => \%special_headers,
        headers         => $args{header},
        #write_code      => $args->{write_code}
        content         => $args{content},
    );
    return $res;
}

sub get_auth {
    my $self = shift;
    (my $load_version = $self->auth_version) =~ s/\./_/;
    my $ksclient = "Net::OpenStack::Swift::InnerKeystone::V${load_version}"->new(
        auth_url => $self->auth_url,
        user     => $self->user,
        password => $self->password,
        tenant_name => $self->tenant_name,
    );
    my $auth_token = $ksclient->auth();
    my $endpoint = $ksclient->service_catalog_url_for(service_type=>'object-store', endpoint_type=>'publicURL');
    $self->token($auth_token);
    $self->storage_url($endpoint);
    return ($endpoint, $auth_token);
}

sub get_account {
    my $self = shift;
    my $rule = Data::Validator->new(
        url            => { isa => 'Str', default => $self->storage_url},
        token          => { isa => 'Str', default => $self->token },
        marker         => { isa => 'Str', default => undef },
        limit          => { isa => 'Int', default => undef },
        prefix         => { isa => 'Str', default => undef },
        end_marker     => { isa => 'Str', default => undef },
    );
    my $args = $rule->validate(@_);

    # make query strings
    my @qs = ('format=json');
    if ($args->{marker}) {
        push @qs, sprintf "marker=%s", uri_escape($args->{marker});
    }
    if ($args->{limit}) {
        push @qs, sprintf("limit=%d", $args->{limit});
    }
    if ($args->{prefix}) {
        push @qs, sprintf("prefix=%s", uri_escape($args->{prefix}));
    }
    if ($args->{end_marker}) {
        push @qs, sprintf("end_marker=%s", uri_escape($args->{end_marker}));
    }

    my $request_header = ['X-Auth-Token' => $args->{token}];
    my $request_url    = sprintf "%s?%s", $args->{url}, join('&', @qs);
    debugf("get_account() request header %s", $request_header);
    debugf("get_account() request url: %s",   $request_url);
    my $res = $self->_request(method=>'GET', url=>$request_url, header=>$request_header);

    croak "Account GET failed: ".$res->status_line unless $res->is_success;
    my @headers = $res->headers->flatten();
    debugf("get_account() response headers %s", \@headers);
    debugf("get_account() response body %s",    $res->content);
    my %headers = @headers;
    return (\%headers, from_json($res->content));
}

sub head_account {
    my $self = shift;
    my $rule = Data::Validator->new(
        url            => { isa => 'Str', default => $self->storage_url},
        token          => { isa => 'Str', default => $self->token },
    );
    my $args = $rule->validate(@_);

    my $request_header = ['X-Auth-Token' => $args->{token}];
    debugf("head_account() request header %s", $request_header);
    debugf("head_account() request url: %s",   $args->{url});
    my $res = $self->_request(method=>'HEAD', url=>$args->{url}, header=>$request_header);

    croak "Account HEAD failed: ".$res->status_line unless $res->is_success;
    my @headers = $res->headers->flatten();
    debugf("head_account() response headers %s", \@headers);
    debugf("head_account() response body %s",    $res->content);
    my %headers = @headers;
    return \%headers;
}

sub post_account {
    die;
}

sub get_container {
    die;
}

sub head_container {
    die;
}

sub put_container {
    my $self = shift;
    my $rule = Data::Validator->new(
        url            => { isa => 'Str', default => $self->storage_url},
        token          => { isa => 'Str', default => $self->token },
        container_name => { isa => 'Str'},
    );
    my $args = $rule->validate(@_);

    my $request_header = ['X-Auth-Token' => $args->{token}];
    my $request_url    = sprintf "%s/%s", $args->{url}, uri_escape($args->{container_name});
    debugf("put_account() request header %s", $request_header);
    debugf("put_account() request url: %s",   $request_url);
    my $res = $self->_request(method=>'PUT', url=>$request_url, header=>$request_header);

    croak "Container PUT failed: ".$res->status_line unless $res->is_success;
    my @headers = $res->headers->flatten();
    debugf("put_container() response headers %s", \@headers);
    debugf("put_container() response body %s",    $res->content);
    my %headers = @headers;
    return \%headers;
}

sub post_container {
    die;
}

sub delete_container {
    die;
}

sub get_object {
    my $self = shift;
    my $rule = Data::Validator->new(
        url            => { isa => 'Str', default => $self->storage_url},
        token          => { isa => 'Str', default => $self->token },
        container_name => { isa => 'Str'},
        object_name    => { isa => 'Str'},
        write_code     => { isa => 'CodeRef'},
    );
    my $args = $rule->validate(@_);

    my $request_header = ['X-Auth-Token' => $args->{token}];
    my $request_url    = sprintf "%s/%s/%s", $args->{url}, 
        uri_escape($args->{container_name}), 
        uri_escape($args->{object_name}); 
    my %special_headers = ('Content-Length' => undef);
    debugf("get_object() request header %s", $request_header);
    debugf("get_object() request special headers: %s", $request_url);
    debugf("get_object() request url: %s", $request_url);
    my $res = $self->_request(method=>'GET', url=>$request_url, header=>$request_header, 
        special_headers => \%special_headers,
        write_code      => $args->{write_code}
    );

    croak "Object GET failed: ".$res->status_line unless $res->is_success;
    my @headers = $res->headers->flatten();
    debugf("get_object() response headers %s", \@headers);
    debugf("get_object() response body length %s byte", length $res->content);
    my %headers = @headers;
    my $etag = $headers{etag};
    $etag =~ s/^\s*(.*?)\s*$/$1/; # delete spaces
    return $etag;
}

sub head_object {
    my $self = shift;
    my $rule = Data::Validator->new(
        url            => { isa => 'Str', default => $self->storage_url},
        token          => { isa => 'Str', default => $self->token },
        container_name => { isa => 'Str'},
        object_name    => { isa => 'Str'},
    );
    my $args = $rule->validate(@_);
 
    my $request_header = ['X-Auth-Token' => $args->{token}];
    my $request_url    = sprintf "%s/%s/%s", $args->{url}, 
        uri_escape($args->{container_name}), 
        uri_escape($args->{object_name}); 
    debugf("head_object() request header %s", $request_header);
    debugf("head_object() request url: %s", $request_url);
    my $res = $self->_request(method=>'HEAD', url=>$request_url, header=>$request_header, 
        content => []);

    croak "Object HEAD failed: ".$res->status_line unless $res->is_success;
    my @headers = $res->headers->flatten();
    debugf("head_object() response headers %s", \@headers);
    debugf("head_object() response body %s",    $res->content);
    my %headers = @headers;
    return \%headers;
}

sub put_object {
    my $self = shift;
    my $rule = Data::Validator->new(
        url            => { isa => 'Str', default => $self->storage_url},
        token          => { isa => 'Str', default => $self->token },
        container_name => { isa => 'Str'},
        object_name    => { isa => 'Str'},
        content        => { isa => 'Str'},
        content_length => { isa => 'Int'},
        content_type   => { isa => 'Str', default => 'application/octet-stream'},
    );
    my $args = $rule->validate(@_);

    my $request_header = [
        'X-Auth-Token'   => $args->{token},
        'Content-Length' => $args->{content_length}, 
        'Content-Type'   => $args->{content_type}, 
    ];
    my $request_url = sprintf "%s/%s/%s", $args->{url}, 
        uri_escape($args->{container_name}), 
        uri_escape($args->{object_name}); 
    # todo: この辺追加オプションヘッダーも考慮する事
    # todo: chunk sizeでアップロードする仕組み http://qiita.com/ymko/items/4195cc0e76091566ccef
    debugf("put_object() request header %s", $request_header);
    debugf("put_object() request url: %s", $request_url);
 
    my $res = $self->_request(method => 'PUT', url => $request_url, header => $request_header, 
        content => $args->{content});

    croak "Object PUT failed: ".$res->status_line unless $res->is_success;
    my @headers = $res->headers->flatten();
    debugf("put_object() response headers %s", \@headers);
    debugf("put_object() response body %s",    $res->content);
    my %headers = @headers;
    my $etag = $headers{etag};
    $etag =~ s/^\s*(.*?)\s*$/$1/; # delete spaces
    return $etag;
}

sub post_object {
    die;
}

sub delete_object {
    my $self = shift;
    my $rule = Data::Validator->new(
        url            => { isa => 'Str', default => $self->storage_url},
        token          => { isa => 'Str', default => $self->token },
        container_name => { isa => 'Str'},
        object_name    => { isa => 'Str'},
    );
    my $args = $rule->validate(@_);
 
    my $request_header = ['X-Auth-Token' => $args->{token}];
    my $request_url = sprintf "%s/%s/%s", $args->{url}, 
        uri_escape($args->{container_name}), 
        uri_escape($args->{object_name}); 
    debugf("delete_object() request header %s", $request_header);
    debugf("delete_object() request url: %s", $request_url);
 
    my $res = $self->_request(method=>'DELETE', url=>$request_url, header=>$request_header, 
        content => []);

    croak "Object DELETE failed: ".$res->status_line unless $res->is_success;
    my @headers = $res->headers->flatten();
    debugf("delete_object() response headers %s", \@headers);
    debugf("delete_object() response body %s",    $res->content);
    my %headers = @headers;
    return \%headers;
}

sub get_capabilities {
    die;
}


1;
__END__

=encoding utf-8

=head1 NAME

Net::OpenStack::Swift - Bindings for the OpenStack Object Storage (Swift) API.

=head1 SYNOPSIS

    use Net::OpenStack::Swift;

=head1 DESCRIPTION

This is a perl client for the OpenStack Object Storage (Swift) API. 

=head1 LICENSE

Copyright (C) masakyst.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

masakyst E<lt>masakyst.public@gmail.comE<gt>

=cut

