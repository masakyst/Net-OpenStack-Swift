#!/usr/bin/env perl

use strict;
use warnings;
use App::Rad;
use File::Basename;
use Text::ASCIITable;
use Net::OpenStack::Swift;

sub setup {
    my $c = shift;
    
    $c->register_commands({
        'list'     => 'Show container/object.',
        'get'      => 'Get object content.',
        'put'      => 'Create or replace object and container.',
        'delete'   => 'Delete container/object.',
    });

    $c->stash->{sw} = Net::OpenStack::Swift->new;
    $c->stash->{storage_url} = undef;
    $c->stash->{token}       = undef;
}

sub auth {
    my $c = shift; 
    unless ($c->stash->{token}) {
        my ($storage_url, $token) = $c->stash->{sw}->get_auth();
        $c->stash->{storage_url} = $storage_url;
        $c->stash->{token}       = $token;
    }
}

App::Rad->run;


sub list {
    auth(@_);
    my $c = shift;
    my $target = $ARGV[0] //= '';
    my ($container_name, $object_name) = split '/', $target;
    $container_name ||= '/';

    my $t;
    # head object
    if ($object_name) {
        my $headers = $c->stash->{sw}->head_object(container_name => $container_name, object_name => $object_name);
        $t = Text::ASCIITable->new({headingText => "${object_name} object"});
        $t->setCols('key', 'value');
        for my $key (sort keys %{ $headers }) {
            $t->addRow($key, $headers->{$key});
        }
    }
    # get container
    else {
        my ($headers, $containers) = $c->stash->{sw}->get_container(container_name => $container_name);
        my $heading_text = "${container_name} container";
        my @label;
        if ($container_name eq '/') {
            @label = ('name', 'bytes', 'count');
        }
        else {
            @label = ('name', 'bytes', 'content_type', 'last_modified', 'hash');
        }
        $t = Text::ASCIITable->new({headingText => $heading_text});
        my $total_bytes = 0;
        for my $container (@{ $containers }) {
            $t->setCols(@label);
            $t->addRow(map { $container->{$_} } @label);
            $total_bytes += int($container->{bytes});
        }
        $t->addRowLine();
        $t->addRow('Total bytes', $total_bytes);
    }
    return $t;
}

sub get {
    auth(@_);
    my $c = shift;
    my $target = $ARGV[0] //= '';
    my ($container_name, $object_name) = split '/', $target;
    die "object name is required." unless $object_name;

    my $fh = *STDOUT;
    my $etag = $c->stash->{sw}->get_object(container_name => $container_name, object_name => $object_name,
        write_file => $fh,
    );
    return undef;
}

sub put {
    auth(@_);
    my $c = shift;
    my $target = $ARGV[0] //= '';
    my $local_path = $ARGV[1] //= '';
    my ($container_name, $object_name) = split '/', $target;
    die "container name is required." unless $container_name;
  
    # put object
    my $t;
    my ($headers, $containers);
    if ($local_path) {
        my $basename = basename($local_path);
        open my $fh, '<', "./$local_path" or die "failed to open: $!";
        my $etag = $c->stash->{sw}->put_object(
            container_name => $container_name, object_name => $basename, 
            content => $fh, content_length => -s $local_path);
        my $headers = $c->stash->{sw}->head_object(container_name => $container_name, object_name => $basename);
        $t = Text::ASCIITable->new({headingText => "${basename} object"});
        $t->setCols('key', 'value');
        for my $key (sort keys %{ $headers }) {
            $t->addRow($key, $headers->{$key});
        }
    }
    # put container
    else {
        ($headers, $containers) = $c->stash->{sw}->put_container(container_name => $container_name);
        my $t = Text::ASCIITable->new({headingText => 'response header'});
        $t->setCols(sort keys %{ $headers });
        $t->addRow(map { $headers->{$_} } sort keys %{ $headers });
    }
    return $t;
}

sub delete {
    auth(@_);
    my $c = shift;
    my $target = $ARGV[0] //= '';
    my ($container_name, $object_name) = split '/', $target;
    die "container name is required." unless $container_name;

    my $t;
    # delete object
    if ($object_name) {
        my ($headers, $containers) = $c->stash->{sw}->delete_object(
            container_name => $container_name,
            object_name    => $object_name
        );
        $t = Text::ASCIITable->new({headingText => 'response header'});
        $t->setCols(sort keys %{ $headers });
        $t->addRow(map { $headers->{$_} } sort keys %{ $headers });
    }
    # delete container
    else {
        my ($headers, $containers) = $c->stash->{sw}->delete_container(
            container_name => $container_name
        );
        $t = Text::ASCIITable->new({headingText => 'response header'});
        $t->setCols(sort keys %{ $headers });
        $t->addRow(map { $headers->{$_} } sort keys %{ $headers });
    }
    return $t;
}
