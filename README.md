# NAME

Net::OpenStack::Swift - Bindings for the OpenStack Object Storage API, known as Swift.

# SYNOPSIS

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

# DESCRIPTION

Bindings for the OpenStack Object Storage API, known as Swift.
Attention!! Keystone authorization is still only Identity API v2.0.

# METHODS

## new

Creates a client.

- auth\_url

    Required. The url of the authentication endpoint.

- user

    Required.

- password

    Required.

- tenant\_name

    Required.
    tenant name/project

- auth\_version

    Optional.
    still only 2.0 (Keystone/Identity 2.0 API)

## get\_auth

Get storage url and auth token.

    my ($storage_url, $token) = $sw->get_auth();

response: 

- storage\_url

    Endpoint URL

- token

    Auth Token

## get\_account

Show account details and list containers.

    my ($headers, $containers) = $sw->get_account(marker => 'hoge');

- maker

    Optional.

- end\_maker

    Optional.

- prefix

    Optional.

- limit

    Optional.

## head\_account

Show account metadata.

    my $headers = $sw->head_account();

## post\_account

Create, update, or delete account metadata.

    not implemented yet

## get\_container

Show container details and list objects.

    not implemented yet

## head\_container

Show container metadata.

    not implemented yet

## put\_container

Create container.

    my $headers = $sw->put_container(container_name => 'container1')

- container\_name

## post\_container

Create, update, or delete container metadata.

    not implemented yet

## delete\_container

Delete container.

    not implemented yet

## get\_object

Get object content and metadata.

    open my $fh, ">>:raw", "hoge.jpeg" or die $!; 
    my $etag = $sw->get_object(container_name => 'container1', object_name => 'hoge.jpeg', 
        write_code => sub {
            my ($status, $message, $headers, $chunk) = @_; 
            print $status;
            print length($chunk);
            print $fh $chunk;
    });

- container\_name
- object\_name
- write\_code

    Code reference

## head\_object

Show object metadata.

    my $headers = $sw->head_object(container_name => 'container1', object_name => 'hoge.jpeg');

## put\_object

Create or replace object.

    my $file = 'hoge.jpeg';
    open my $fh, '<', "./$file" or die;
    my $content = do { local $/; <$fh> };
    my $headers = $sw->put_object(container_name => 'container1', 
        object_name => 'hoge.jpeg', content => $content, content_length => -s $file);

## post\_object

Create or update object metadata.

    not implemented yet

## delete\_object

Delete object.

    my $headers = $sw->delete_object(container_name => 'container1', object_name => 'hoge.jpeg');

# SEE ALSO

http://docs.openstack.org/developer/swift/

http://docs.openstack.org/developer/keystone/

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

masakyst <masakyst.public@gmail.com>
