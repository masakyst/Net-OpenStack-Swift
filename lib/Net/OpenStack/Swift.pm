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
use Data::Dumper;
use Data::Validator;
use Net::OpenStack::Swift::Util;
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
has verify_ssl   => (is => 'ro', default => sub {! $ENV{OSCOMPUTE_INSECURE}});
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

sub get_auth {
    my $self = shift;
    (my $load_version = $self->auth_version) =~ s/\./_/;
    # 認証チェック
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

    my $access_url = sprintf "%s?%s", $args->{url}, join('&', @qs);
    my $res = $self->agent->get(
        $access_url,
        ['X-Auth-Token' => $args->{token}], 
    );
    croak "Account GET failed: ".$res->status_line unless $res->is_success;
    my $body_params = from_json($res->content);
    my %headers = $res->headers->flatten();
    return (\%headers, $body_params);
}

sub head_account {
    my $self = shift;
    my $rule = Data::Validator->new(
        url            => { isa => 'Str', default => $self->storage_url},
        token          => { isa => 'Str', default => $self->token },
    );
    my $args = $rule->validate(@_);

    my $res = $self->agent->head(
        $args->{url},
        ['X-Auth-Token' => $args->{token}], 
    );
    croak "Account HEAD failed: ".$res->status_line unless $res->is_success;
    my %headers = $res->headers->flatten();
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

    my $container_url = sprintf "%s/%s", $args->{url}, uri_encode($args->{container_name}); 
    my $res = $self->agent->put(
        $container_url,
        ['X-Auth-Token' => $args->{token}], 
    );
    croak "Container PUT failed: ".$res->status_line unless $res->is_success;
    my %headers = $res->headers->flatten();
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

    my $object_url = sprintf "%s/%s/%s", $args->{url}, $args->{container_name}, $args->{object_name}; 
    my %special_headers = ('Content-Length' => undef);
    my $res = $self->agent->request(
        method          => 'GET',
        url             => $object_url,
        special_headers => \%special_headers,
        headers         => ['X-Auth-Token' => $args->{token}],
        write_code      => $args->{write_code}
    );
    croak "Object GET failed: ".$res->status_line unless $res->is_success;
    my %headers = $res->headers->flatten();
    print Dumper(\%headers);
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
 
    my $object_url = sprintf "%s/%s/%s", $args->{url}, $args->{container_name}, $args->{object_name}; 
    my $res = $self->agent->head(
        $object_url,
        ['X-Auth-Token' => $args->{token}],
        [],
    );
    croak "Object HEAD failed: ".$res->status_line unless $res->is_success;
    my %headers = $res->headers->flatten();
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
        content_type   => { isa => 'Str'},
    );
    my $args = $rule->validate(@_);
 
    my $object_url = sprintf "%s/%s/%s", $args->{url}, $args->{container_name}, $args->{object_name}; 
    # todo: この辺追加オプションヘッダーも考慮する事
    # todo: chunk sizeでアップロードする仕組み http://qiita.com/ymko/items/4195cc0e76091566ccef
    my $res = $self->agent->put(
        $object_url,
        ['X-Auth-Token'   => $args->{token}, 
         'Content-Length' => $args->{content_length}, 
         'Content-Type'   => $args->{content_type}], 
        $args->{content},
    );
    croak "Object PUT failed: ".$res->status_line unless $res->is_success;
    my %headers = $res->headers->flatten();
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
 
    my $object_url = sprintf "%s/%s/%s", $args->{url}, $args->{container_name}, $args->{object_name}; 
    my $res = $self->agent->delete(
        $object_url,
        ['X-Auth-Token' => $args->{token}],
        [],
    );
    croak "Object DELETE failed: ".$res->status_line unless $res->is_success;
    my %headers = $res->headers->flatten();
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

