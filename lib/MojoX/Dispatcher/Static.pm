# Copyright (C) 2008, Sebastian Riedel.

package MojoX::Dispatcher::Static;

use strict;
use warnings;

use base 'Mojo::Base';

use File::stat;
use File::Spec;
use Mojo::Content;
use Mojo::File;
use MojoX::Types;

__PACKAGE__->attr(prefix => (chained => 1));
__PACKAGE__->attr(
    types => (
        chained => 1,
        default => sub { MojoX::Types->new }
    )
);
__PACKAGE__->attr(root => (chained => 1));

# Valentine's Day's coming? Aw crap! I forgot to get a girlfriend again!
sub dispatch {
    my ($self, $tx) = @_;

    # Prefix
    if (my $prefix = $self->prefix) {
        return 0 unless $tx->req->url->path =~ /^$prefix.*/;
    }

    # Path
    my @parts = @{$tx->req->url->path->clone->canonicalize->parts};

    # Shortcut
    return 0 unless @parts;

    # Serve static file
    return $self->serve($tx, File::Spec->catfile(@parts));
}

sub serve {
    my ($self, $tx, $path) = @_;

    # Append path to root
    $path = File::Spec->catfile($self->root, $path);

    # Extension
    $path =~ /\.(\w+)$/;
    my $ext = $1;

    # Type
    my $type = $self->types->type($ext) || 'text/plain';

    # Dispatch
    if (-f $path) {

        my $res = $tx->res;
        if (-r $path) {
            my $req  = $tx->req;
            my $stat = stat($path);

            # If modified since
            if (my $date = $req->headers->header('If-Modified-Since')) {

                # Not modified
                if (Mojo::Date->new($date)->epoch == $stat->mtime) {
                    $res->code(304);
                    $res->headers->remove('Content-Type');
                    $res->headers->remove('Content-Length');
                    $res->headers->remove('Content-Disposition');
                    return 1;
                }
            }

            $res->content(Mojo::Content->new(file => Mojo::File->new));
            $res->code(200);

            # Last modified
            $res->headers->header('Last-Modified',
                Mojo::Date->new($stat->mtime));

            $res->headers->content_type($type);
            $res->content->file->path($path);
            return 1;
        }

        # Exists, but is forbidden
        else {
            $res->code(403);
            return 1;
        }
    }

    return 0;
}

sub serve_404 {
    my ($self, $tx, $path) = @_;

    $path ||= File::Spec->catfile('errdocs', '404.html');

    # Append path to root
    my $abs_path = File::Spec->catfile($self->root, $path);

    my $res = $tx->res;

    # No matter what, it's going to be a 404!
    $res->code(404);

    # Dispatch
    if (-f $abs_path) {

       # Best possible case: We find the  404 file to serve and it's readable.
        if (-r $abs_path) {
            my $req  = $tx->req;
            my $stat = stat($abs_path);

            $res->content(Mojo::Content->new(file => Mojo::File->new));

            # Extension
            $path =~ /\.(\w+)$/;
            my $ext = $1;

            # Type
            my $type = $self->types->type($ext) || 'text/plain';

            $res->headers->content_type($type);
            $res->content->file->path($abs_path);
        }

        # Exists, but is forbidden
        else {
            $res->body(
                '<!doctype html>
                        <head><title>404 - Document not found.</title></head>
                        <body><h2>404 - Document not found.</h2>
                               <p>Additionally, the 404 file was not readable.</p>
                        </body></html>'
            );
        }
    }
    else {
        $res->body(
            '<!doctype html>
                        <head><title>404 - Document not found.</title></head>
                        <body><h2>404 - Document not found.</h2>
                                <p>Additionally, the 404 file was not found. </p>
                        </body></html>'
        );
    }

    # Always succeed at serving a 404
    return 1;
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
    my $success = $dispatcher->dispatch($tx);

=head1 DESCRIPTION

L<MojoX::Dispatcher::Static> is a dispatcher for static files.

=head2 ATTRIBUTES

=head2 C<prefix>

    my $prefix  = $dispatcher->prefix;
    $dispatcher = $dispatcher->prefix('/static');

Returns the path prefix if called without arguments.
Returns the invocant if called with arguments.
If defined, files will only get served for url paths beginning with this
prefix.

=head2 C<types>

    my $types   = $dispatcher->types;
    $dispatcher = $dispatcher->types(MojoX::Types->new);

Returns a L<Mojo::Types> object if called without arguments.
Returns the invocant if called with arguments.
If no type can be determined, C<text/plain> will be used.

=head2 C<root>

    my $root    = $dispatcher->root;
    $dispatcher = $dispatcher->root('/foo/bar/files');

Returns the root directory from which files get served if called without
arguments.
Returns the invocant if called with arguments.

=head1 METHODS

L<MojoX::Dispatcher::Static> inherits all methods from L<Mojo::Base> and
implements the follwing the ones.

=head2 C<dispatch>

    my $success = $dispatcher->dispatch($tx);

Returns true if a file matching the request could be found and a response be
prepared.
Returns false otherwise.
Expects a L<Mojo::Transaction> object as first argument.

=head2 C<serve>

    my $success = $dispatcher->serve($tx, '/foo/bar.html');

Returns true if a readable file could be found under C<root> and a response
be prepared.
Returns false otherwise.
Expects a L<Mojo::Transaction> object and a path as arguments.
If no type can be determined, C<text/plain> will be used.
A C<Last-Modified> header will always be set according to the last modified
time of the file.

=head2 C<serve_404>

    $dispatcher->serve_404($tx);

    # Same
    $dispatcher->serve_404($tx, '/errdocs/404.html');

Returns true after serving a 404 response.  Expects a L<Mojo::Transaction>
object and a path as arguments.  A default path of '/errdocs/404.html' will be
used if no path is provided.

When serving a regular file, it's possible that special codes may set 
if the file is forbidden or cached. When C<serve_404> is called, you can 
be assured that the 404 code is always set. If for some reason the 404 file
provided can't be read or is missing, A generic internal 404 page will be  
returned instead. 

=cut
