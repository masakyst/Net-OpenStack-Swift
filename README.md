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

## get\_account

Show account details and list containers.

- maker

    Optional.

- end\_maker

    Optional.

- limit

    Optional.

## head\_account

Show account metadata.

## post\_account

Create, update, or delete account metadata.

## get\_container

Show container details and list objects.

## head\_container

Show container metadata.

## put\_container

Create container.

## post\_container

Create, update, or delete container metadata.

## delete\_container

Delete container.

## get\_object

Get object content and metadata.

## head\_object

Show object metadata.

## put\_object

Create or replace object.

## post\_object

Create or update object metadata.

## delete\_object

Delete object.

# SEE ALSO

http://docs.openstack.org/developer/swift/

http://docs.openstack.org/developer/keystone/

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

masakyst <masakyst.public@gmail.com>
