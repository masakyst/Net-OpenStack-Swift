package Net::OpenStack::Swift;
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
    my %args = @_;
    my $res = $self->agent->request(
        method          => $args{method},
        url             => $args{url},
        special_headers => $args{special_headers},
        headers         => $args{header},
        write_code      => $args{write_code},
        content         => $args{content},
    );
    return $res;
}

sub auth_keystone {
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
    croak "Not found endpoint type 'object-store'" unless $endpoint;
    $self->token($auth_token);
    $self->storage_url($endpoint);
    return 1;
}

sub get_auth {
    my $self = shift;
    $self->auth_keystone();
    return ($self->storage_url, $self->token);
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

=head1 NAME

Net::OpenStack::Swift - Bindings for the OpenStack Object Storage API, known as Swift.

=head1 SYNOPSIS

    use Net::OpenStack::Swift;

    my $sw = Net::OpenStack::Swift->new(
        auth_url       => 'https://auth-endpoint-url/v2.0',
        user           => 'userid',
        password       => 'password',
        tenant_name    => 'project_id',
        # auth_version => '2.0', # by default
    );

    my ($storage_url, $token) = $sw->get_auth();

    my ($headers, $containers) = $sw->get_account(url => $storage_url, token => $token);
    # or,  storage_url and token can be omitted.
    my ($headers, $containers) = $sw->get_account();


=head1 DESCRIPTION

Bindings for the OpenStack Object Storage API, known as Swift.
Attention!! Keystone authorization is still only Identity API v2.0.

=head1 METHODS

=head2 new

Creates a client.

=over

=item auth_url

Required. The url of the authentication endpoint.

=item user

Required.

=item password

Required.

=item tenant_name

Required.
tenant name/project

=item auth_version

Optional.
still only 2.0 (Keystone/Identity 2.0 API)

=back

=head2 get_auth

Get storage url and auth token.

=head2 get_account

Show account details and list containers.

=over

=item maker

Optional.

=item end_maker

Optional.

=item prefix

Optional.

=item limit

Optional.

=back


=head2 head_account

Show account metadata.

=head2 post_account

Create, update, or delete account metadata.

=head2 get_container

Show container details and list objects.

=head2 head_container

Show container metadata.

=head2 put_container

Create container.

=over

=item container_name

=back

=head2 post_container

Create, update, or delete container metadata.

=head2 delete_container

Delete container.

=head2 get_object

Get object content and metadata.

    open my $fh, ">>:raw", "hoge.jpeg" or die $!; 
    my $etag = $sw->get_object(container_name => 'container1', object_name => 'hoge.jpeg', 
        write_code => sub {
            my ($status, $message, $headers, $chunk) = @_; 
            print $status;
            print length($chunk);
            print $fh $chunk;
    });

=over

=item container_name

=item object_name

=item write_code

Code reference

=back

=head2 head_object

Show object metadata.

=head2 put_object

Create or replace object.

=head2 post_object

Create or update object metadata.

=head2 delete_object

Delete object.

=head1 SEE ALSO

http://docs.openstack.org/developer/swift/

http://docs.openstack.org/developer/keystone/


=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

masakyst E<lt>masakyst.public@gmail.comE<gt>

=cut
