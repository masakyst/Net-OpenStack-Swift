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
use Moo;
# use namespace::clean;
use JSON;
use Data::Dumper;
use Net::OpenStack::Swift::InnerKeystone;

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
    my ($storage_url, $token) = @_;
    $storage_url ||= $self->storage_url;
    $token       ||= $self->token;
    my $access_url = sprintf "%s?%s", ($storage_url, "format=json");
    #[format=>'json', marker=>'', limit=>'', prefix=>'', end_marker=>''],      # form data (HashRef/FileHandle are also okay)
    my $res = $self->agent->get(
        $access_url,
        ['X-Auth-Token'=>$token], 
    );
    croak "Account GET failed: ".$res->status_line unless $res->is_success;
    my $body_params = from_json($res->content);
    my %headers = $res->headers->flatten();
    return (\%headers, $body_params);
}

sub head_account {
    my $self = shift;
    my ($storage_url, $token) = @_;
    $storage_url ||= $self->storage_url;
    $token       ||= $self->token;
    my $res = $self->agent->head(
        $storage_url,
        ['X-Auth-Token'=>$token], 
    );
    croak "Account HEAD failed: ".$res->status_line unless $res->is_success;
    my %headers = $res->headers->flatten();
    return \%headers;
}

sub post_account {
    die;
    #my $self = shift;
    #my ($storage_url, $token) = @_;
    #$storage_url ||= $self->storage_url;
    #$token       ||= $self->token;
    #my $res = $self->agent->get(
    #    $storage_url,
    #    ['X-Auth-Token'=>$token], 
    #);
    #croak "Account HEAD failed: ".$res->status_line unless $res->is_success;
    #my %headers = $res->headers->flatten();
    #my $body_params = $res->content;
    #return \%headers;

}

sub get_container {
    die;
}

sub head_container {
    die;
}

sub put_container {
    my $self = shift;
    my ($storage_url, $token, $container_name) = @_;
    $storage_url ||= $self->storage_url;
    $token       ||= $self->token;
    # todo: container_nameにquote必須らしい
    my $container_url = sprintf "%s/%s", $storage_url, $container_name; 
    my $res = $self->agent->put(
        $container_url,
        ['X-Auth-Token'=>$token], 
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
    my ($storage_url, $token, $container_name, $object_name, $write_code) = @_;
    my $object_url = sprintf "%s/%s/%s", $storage_url, $container_name, $object_name; 
    my %special_headers = ('Content-Length' => undef);
    my $res = $self->agent->request(
        method          => 'GET',
        url             => $object_url,
        special_headers => \%special_headers,
        headers         => ['X-Auth-Token' => $token],
        write_code      => $write_code
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
    my ($storage_url, $token, $container_name, $object_name) = @_;
    my $object_url = sprintf "%s/%s/%s", $storage_url, $container_name, $object_name; 
    my $res = $self->agent->head(
        $object_url,
        ['X-Auth-Token' => $token],
        [],
    );
    croak "Object HEAD failed: ".$res->status_line unless $res->is_success;
    my %headers = $res->headers->flatten();
    return \%headers;
}

sub put_object {
    my $self = shift;
    my ($storage_url, $token, $container_name, $object_name, $content, $content_length, $content_type) = @_;
    $storage_url ||= $self->storage_url;
    $token       ||= $self->token;
    # todo: container_nameにquote必須らしい
    my $object_url = sprintf "%s/%s/%s", $storage_url, $container_name, $object_name; 
    # todo: この辺追加オプションヘッダーも考慮する事
    # todo: chunk sizeでアップロードする仕組み http://qiita.com/ymko/items/4195cc0e76091566ccef
    my $res = $self->agent->put(
        $object_url,
        ['X-Auth-Token'   => $token, 
         'Content-Length' => $content_length, 
         'Content-Type'   => $content_type], 
        $content,
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
    die;
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

