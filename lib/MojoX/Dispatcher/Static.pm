# Copyright (C) 2008-2010, Sebastian Riedel.

package MojoX::Dispatcher::Static;

use strict;
use warnings;

use base 'Mojo::Base';

use File::stat;
use File::Spec;
use Mojo::Asset::File;
use Mojo::Content::Single;
use Mojo::Path;
use MojoX::Types;

__PACKAGE__->attr([qw/prefix root/]);
__PACKAGE__->attr(types => sub { MojoX::Types->new });

# Valentine's Day's coming? Aw crap! I forgot to get a girlfriend again!
sub dispatch {
    my ($self, $c) = @_;

    # Canonical path
    my $path = $c->req->url->path->clone->canonicalize->to_string;

    # Prefix
    if (my $prefix = $self->prefix) {
        return 1 unless $path =~ s/^$prefix//;
    }

    # Parts
    my @parts = @{Mojo::Path->new->parse($path)->parts};

    # Shortcut
    return 1 unless @parts;

    # Prevent directory traversal
    return 1 if $parts[0] eq '..';

    # Serve static file
    return $self->serve($c, File::Spec->catfile(@parts));
}

sub serve {
    my ($self, $c, $rel) = @_;

    # Append path to root
    my $path = File::Spec->catfile($self->root, split('/', $rel));

    # Extension
    $path =~ /\.(\w+)$/;
    my $ext = $1;

    # Type
    my $type = $self->types->type($ext) || 'text/plain';

    # Dispatch
    if (-f $path) {

        # Log
        $c->app->log->debug(qq/Serving static file "$rel"./);

        my $res = $c->res;
        if (-r $path) {
            my $req  = $c->req;
            my $stat = stat($path);

            # If modified since
            if (my $date = $req->headers->header('If-Modified-Since')) {

                # Not modified
                my $since = Mojo::Date->new($date)->epoch;
                if (defined $since && $since == $stat->mtime) {

                    # Log
                    $c->app->log->debug('File not modified.');

                    $res->code(304);
                    $res->headers->remove('Content-Type');
                    $res->headers->remove('Content-Length');
                    $res->headers->remove('Content-Disposition');
                    return;
                }
            }

            $res->code(200);

            # Partial content
            my $size  = $stat->size;
            my $start = 0;
            my $end   = $size - 1 >= 0 ? $size - 1 : 0;

            if (my $range = $req->headers->header('Range')) {
                if ($range =~ m/^bytes=(\d+)\-(\d+)?/ && $1 <= $end) {
                    $start = $1;
                    $end = $2 if defined $2 && $2 <= $end;
                    $res->code(206);
                    $res->headers->header(
                        'Content-Length' => $end - $start + 1);
                    $res->headers->header(
                        'Content-Range' => "bytes $start-$end/$size");
                    $c->app->log->debug("Range request: $start-$end/$size.");
                }
                else {

                    # Not satisfiable
                    $res->code(416);
                    return;
                }
            }

            # Content
            $res->content(
                Mojo::Content::Single->new(
                    asset => Mojo::Asset::File->new(
                        start_range => $start,
                        end_range   => $end
                    ),
                    headers => $res->headers
                )
            );

            # Accept ranges
            $res->headers->header('Accept-Ranges' => 'bytes');

            # Last modified
            $res->headers->header(
                'Last-Modified' => Mojo::Date->new($stat->mtime));

            $res->headers->content_type($type);
            $res->content->asset->path($path);

            return;
        }

        # Exists, but is forbidden
        else {

            # Log
            $c->app->log->debug('File forbidden.');

            $res->code(403);
            return;
        }
    }

    return 1;
}

sub serve_404 { shift->serve_error(shift, 404, shift) }
sub serve_500 { shift->serve_error(shift, 500, shift) }

sub serve_error {
    my ($self, $c, $code, $rel) = @_;

    # Shortcut
    return 1 unless $c && $code;

    my $res = $c->res;

    # Code
    $res->code($code);

    # Default to "code.html"
    $rel ||= "$code.html";

    # Append path to root
    my $path = File::Spec->catfile($self->root, split('/', $rel));

    # File
    if (-r $path) {

        # Log
        $c->app->log->debug(qq/Serving error file "$rel"./);

        # File
        $res->content(
            Mojo::Content::Single->new(asset => Mojo::Asset::File->new));
        $res->content->asset->path($path);

        # Extension
        $path =~ /\.(\w+)$/;
        my $ext = $1;

        # Type
        my $type = $self->types->type($ext) || 'text/plain';
        $res->headers->content_type($type);
    }

    # 404
    elsif ($code == 404) {

        # Log
        $c->app->log->debug('Serving 404 error.');

        $res->headers->content_type('text/html');
        $res->body(<<'EOF');
<!doctype html><html>
    <head><title>File Not Found</title></head>
    <body><h2>File Not Found</h2></body>
</html>
EOF
    }

    # Error
    else {

        # Log
        $c->app->log->debug(qq/Serving error "$code"./);

        $res->headers->content_type('text/html');
        $res->body(<<'EOF');
<!doctype html><html>
    <head><title>Internal Server Error</title></head>
    <body><h2>Internal Server Error</h2></body>
</html>
EOF
    }

    return;
}

1;
__END__

=head1 NAME

MojoX::Dispatcher::Static - Serve Static Files

=head1 SYNOPSIS

    use MojoX::Dispatcher::Static;

    my $dispatcher = MojoX::Dispatcher::Static->new(
            prefix => '/images',
            root   => '/ftp/pub/images'
    );
    my $success = $dispatcher->dispatch($c);

=head1 DESCRIPTION

L<MojoX::Dispatcher::Static> is a dispatcher for static files.

=head2 ATTRIBUTES

L<MojoX::Dispatcher::Static> implements the following attributes.

=head2 C<prefix>

    my $prefix  = $dispatcher->prefix;
    $dispatcher = $dispatcher->prefix('/static');

=head2 C<types>

    my $types   = $dispatcher->types;
    $dispatcher = $dispatcher->types(MojoX::Types->new);

=head2 C<root>

    my $root    = $dispatcher->root;
    $dispatcher = $dispatcher->root('/foo/bar/files');

=head1 METHODS

L<MojoX::Dispatcher::Static> inherits all methods from L<Mojo::Base> and
implements the follwing the ones.

=head2 C<dispatch>

    my $success = $dispatcher->dispatch($c);

=head2 C<serve>

    my $success = $dispatcher->serve($c, 'foo/bar.html');

=head2 C<serve_404>

    my $success = $dispatcher->serve_404($c);
    my $success = $dispatcher->serve_404($c, 'my_404.html');

A shortcut for L<serve_error> when serving a 404.

=head2 C<serve_500>

    my $success = $dispatcher->serve_500($c);
    my $success = $dispatcher->serve_500($c, 'my_500.html');

A shortcut for L<serve_error> when serving a 404.

=head2 C<serve_error>

    my $success = $dispatcher->serve_error($c, 404);
    my $success = $dispatcher->serve_error($c, 404, '404.html');

Returns true after serving an error page.  Expects a L<Mojo::Context> object,
an HTTP error code and an optional path as arguments.  A default path of
'$err_code.html' will be used if no path is provided.

When serving a regular file, it's possible that special codes may set if the
file is forbidden or cached. When C<serve_error> is called, you can be assured
that the requested error code is always set. If for some reason the error file
provided can't be read or is missing, A generic internal page will be returned
instead.

=cut
