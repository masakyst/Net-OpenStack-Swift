#!/usr/bin/env perl
#
#http://docs.openstack.org/ja/user-guide/cli_swift_pseudo_hierarchical_folders_directories.html

use strict;
use warnings;
use App::Rad;
use Path::Tiny;
use File::Basename;
use Text::ASCIITable;
use Net::OpenStack::Swift;
use Parallel::Fork::BossWorkerAsync;

use Data::Dumper;

sub setup {
    my $c = shift;
    
    $c->register_commands({
        'list'     => 'Show container/object.',
        'get'      => 'Get object content.',
        'put'      => 'Create or replace object and container.',
        'delete'   => 'Delete container/object.',
        'download' => 'Download container/object.',
        'upload'   => 'Upload container/object.',
    });

    $c->stash->{sw} = Net::OpenStack::Swift->new;
    $c->stash->{storage_url} = undef;
    $c->stash->{token}       = undef;
}

sub _auth {
    my $c = shift; 
    unless ($c->stash->{token}) {
        my ($storage_url, $token) = $c->stash->{sw}->get_auth();
        $c->stash->{storage_url} = $storage_url;
        $c->stash->{token}       = $token;
    }
}

sub _path_parts {
    my $target = shift;
    my $path = path($target);
    my ($container_name, $object_name);
    my $prefix    = '';
    my $delimiter = '/';

    # directory
    if ($target =~ /\/$/) {
        my @parts = split '/', $path->stringify, 2;
        $container_name = $parts[0] || '/';
        unless ($path->dirname eq '.' || $path->dirname eq '/') {
            $prefix = sprintf "%s/", $parts[1];
        }
    }
    # object
    else {
        # top level container
        if ($path->dirname eq '.') {
            $container_name = $path->basename;
        }
        # other objects
        else {
            my @parts = split '/', $path->stringify, 2;
            $container_name = $parts[0];
            $object_name    = $parts[1];
        }
    }
    return ($container_name, $object_name, $prefix, $delimiter);
}

App::Rad->run;


sub list {
    _auth(@_);
    my $c = shift;
    my $target = $ARGV[0] //= '/';
    my ($container_name, $object_name, $prefix, $delimiter) = _path_parts($target);

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
    # get_container
    else {
        my ($headers, $containers) = $c->stash->{sw}->get_container(
            container_name => $container_name,
            delimiter      => $delimiter,
            prefix         => $prefix
        );
        if (scalar @{ $containers } == 0) {
            return "container ${target} is empty.";
        }
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
    _auth(@_);
    my $c = shift;
    my $target = $ARGV[0] //= '';
    my ($container_name, $object_name, $prefix, $delimiter) = _path_parts($target);
    die "object name is required." unless $object_name;

    my $fh = *STDOUT;
    my $etag = $c->stash->{sw}->get_object(container_name => $container_name, object_name => $object_name,
        write_file => $fh,
    );
    return undef;
}

sub put {
    _auth(@_);
    my $c = shift;
    my $target = $ARGV[0] //= '';
    my $local_path = $ARGV[1] //= '';
    my ($container_name, $object_name, $prefix, $delimiter) = _path_parts($target);
    die "container name is required." unless $container_name;

    # put object
    my $t;
    my ($headers, $containers);
    if ($local_path) {
        my $basename = basename($local_path);
        open my $fh, '<', "./$local_path" or die "failed to open: $!";
        my $etag = $c->stash->{sw}->put_object(
            container_name => $target, object_name => $basename, 
            content => $fh, content_length => -s $local_path);
        my $headers = $c->stash->{sw}->head_object(container_name => $target, object_name => $basename);
        $t = Text::ASCIITable->new({headingText => "${basename} object"});
        $t->setCols('key', 'value');
        for my $key (sort keys %{ $headers }) {
            $t->addRow($key, $headers->{$key});
        }
    }
    # put container
    else {
        ($headers, $containers) = $c->stash->{sw}->put_container(container_name => $target);
        my $t = Text::ASCIITable->new({headingText => 'response header'});
        $t->setCols(sort keys %{ $headers });
        $t->addRow(map { $headers->{$_} } sort keys %{ $headers });
    }
    return $t;
}

sub delete {
    _auth(@_);
    my $c = shift;
    my $target = $ARGV[0] //= '';
    my ($container_name, $object_name, $prefix, $delimiter) = _path_parts($target);

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

sub download {
    _auth(@_);
    my $c = shift;
    die "ARGV" if scalar @ARGV >= 2;
    my $target = $ARGV[0] //= '';

    #my ($container_name, $object_name) = split '/', $target;
    my ($container_name, $object_name, $prefix, $delimiter) = _path_parts($target);
    die "container name is required." unless $container_name;
    if ($object_name) {
        $object_name =~ s/\*/\(\.\*\?\)/g; 
    }
    else {
        $object_name = '(.*?)'; 
    }

    # todo: このへんたいわで[y/n]出すか?
    if (-d $container_name) {
        #die "already exists directory [$container_name]\n";
    }
    else {
        #todo: 複数階層の場合
        mkdir "$container_name";
    }


    print "target: ", Dumper($target);
    print "container_name:", Dumper($container_name);
    print "object_name: ", Dumper($object_name);

    # 一覧を取得して、ここから正規表現に一致するファイルだけ取る
    # *のみだったら全部取った方が早い
    my @matches = ();
    my ($headers, $containers) = $c->stash->{sw}->get_container(container_name => $container_name);
    print Dumper($containers);
    for my $container (@{ $containers }) {
        if ($container->{name} =~ /$object_name/) {
            push @matches, {container_name =>$container_name , object_name => $container->{name}};
        }
    }
    print Dumper \@matches;

    # parallel
    #my $bw = Parallel::Fork::BossWorkerAsync->new(
    #    work_handler => sub {
    #        my ($job) = @_;
    #        my $fh = path($job->{container_name}, $job->{object_name})->openw;  #$binmode
    #        my $etag = $c->stash->{sw}->get_object(
    #            container_name => $job->{container_name}, 
    #            object_name => $job->{object_name},
    #            write_file => $fh,
    #        );
    #        return $job;
    #    },  
    #    result_handler => sub {
    #        my ($job) = @_; 
    #        printf "downloaded %s/%s\n", $job->{container_name}, $job->{object_name};
    #        return $job;
    #    },  
    #    worker_count => 5,
    #);
    #$bw->add_work(@matches);
    #while($bw->pending) {
    #    my $ref = $bw->get_result;
    #}
    #$bw->shut_down;

    # blocking
    for my $job (@matches) {
        my $fh = path($job->{container_name}, $job->{object_name})->openw;  #$binmode
        my $etag = $c->stash->{sw}->get_object(
            container_name => $job->{container_name}, 
            object_name => $job->{object_name},
            write_file => $fh,
        );
        printf "downloaded %s/%s\n", $job->{container_name}, $job->{object_name};
    }
    return undef;
}

sub upload {
    _auth(@_);
    my $c = shift;
    die "ARGV" if scalar @ARGV >= 2;
    my $target = $ARGV[0] //= '';

    my ($container_name, $object_name, $prefix, $delimiter) = _path_parts($target);
    die "container name is required." unless $container_name;

    print Dumper($container_name);
    print Dumper($object_name);

    #my @local_files = glob "${container_name}/*";
    #print Dumper \@local_files;

    if ($object_name) {
        $object_name =~ s/\*/\(\.\*\?\)/g; 
    }
    else {
        $object_name = '(.*?)'; 
    }

    print Dumper($container_name);
    print Dumper($object_name);


    my @matches = ();
    my $iter = path($container_name)->iterator({
        recurse         => 1,
        follow_symlinks => 0,
    }); 
    while (my $local_path = $iter->()) {
        print "local_path: ", Dumper($local_path->stringify);
        #print "matche?: ", Dumper("$container_name/$object_name");
        print "dir: ", Dumper($local_path->is_dir);
        my $partial = "$container_name/$object_name";
        my $basename = basename($local_path->stringify);
        if ($local_path->stringify =~ /$partial/) {
            push @matches, $local_path;
        }
    }

    #for my $local_file (@local_files) {
    #    my $basename = basename($local_file);
    #    if ($basename =~ /$object_name/) {
    #        push @matches, $basename;
    #    }
    #}
    #print Dumper \@matches;
 
    # put object
    #todo: top level containerだけは作っておく必要がある
    my ($headers, $containers);
    if (scalar @matches) {
        for (@matches) {
            print "path: ", Dumper $_->stringify;
            my ($up_container, $up_object) = split '/', $_->stringify, 2;
            print "path dirname: ", Dumper $up_container;
            print "path basename: ", Dumper $up_object;
            
            if ($_->is_dir) {
                my $res = $c->stash->{sw}->put_container(container_name => $_->stringify);                
            }
            else {
                my $fh = $_->openr;  #$binmode
                my $etag = $c->stash->{sw}->put_object(
                    container_name => $up_container, object_name => $up_object, 
                    content => $fh, content_length => -s $_->absolute);
                print "uploaded $up_container/$up_object\n";
            }
        }
    }

    return undef;
} 
