# Copyright (C) 2008, Sebastian Riedel.

package MojoX::Renderer;

use strict;
use warnings;

use base 'Mojo::Base';

use Carp qw/carp croak/;
use File::Spec;
use MojoX::Types;

__PACKAGE__->attr(default_format => (chained => 1));
__PACKAGE__->attr(handler => (chained => 1, default => sub { {} }));
__PACKAGE__->attr(
    types => (
        chained => 1,
        default => sub { MojoX::Types->new }
    )
);
__PACKAGE__->attr(root => (chained => 1));

# This is not how Xmas is supposed to be.
# In my day Xmas was about bringing people together, not blowing them apart.
sub add_handler {
    my $self = shift;

    # Merge
    my $handler = ref $_[0] ? $_[0] : {@_};
    $handler = {%{$self->handler}, %$handler};
    $self->handler($handler);

    return $self;
}

sub render {
    my ($self, $c) = @_;

    my $format        = $c->stash->{format};
    my $template      = $c->stash->{template};
    my $template_path = $c->stash->{template_path};

    return undef unless $format || $template || $template_path;

    # Template extension
    my $default_format = $self->default_format;

    # A template_path should be complete, including the extension.
    if ($template_path) {

        # nothing more to do
    }

    # If we have a template, build the template_path
    elsif ($template) {
        $template .= ".$default_format"
          if $default_format && $template !~ /\.\w+$/;
        my $path = File::Spec->catfile($self->root, $template);
        $c->stash->{template_path} = $path;
    }

  # Only calculate the format from the extension if one has not been provided.
    unless ($format) {
        $c->stash->{template_path} =~ /\.(\w+)$/;
        $format = $1;
    }

    return undef unless $format;

    my $handler_coderef = $self->handler->{$format};

    # Fallback
    unless ($handler_coderef) {
        carp qq/No handler for "$format" configured/;
        $handler_coderef = $self->handler->{$default_format};
        croak 'Need a valid handler for rendering' unless $handler_coderef;
    }

    # Render
    my $output;
    return undef unless $handler_coderef->($self, $c, \$output);

    # Partial
    return $output if $c->stash->{partial};

    # Response
    my $res = $c->res;
    $res->code(200) unless $c->res->code;
    $res->body($output);

    my $type = $self->types->type($format) || 'text/plain';
    $res->headers->content_type($type);

    # Success!
    return 1;
}

1;
__END__

=head1 NAME

MojoX::Renderer - Render Templates

=head1 SYNOPSIS

    use MojoX::Renderer;

    my $renderer = MojoX::Renderer->new;

    $renderer->render;

=head1 DESCRIPTION

L<MojoX::Renderer> is a MIME-type based template renderer.

=head2 ATTRIBUTES

=head2 C<default_format>

    my $format = $renderer->default_format;
    $renderer  = $renderer->default_format('phtml');

Returns the file extension of the default handler for rendering.
Returns the invocant if called with arguments.
Expects a file extension.

=head2 C<handler>

    my $handler = $renderer->handler;
    $renderer   = $renderer->handler({phtml => sub { ... }});

Returns a hashref of handlers. Keys are file extensions and values are coderefs
to render templates for that extension. See L<render> for more about the coderefs.
Returns the invocant if called with arguments.
Expects a hashref of handlers.

=head2 C<types>

    my $types = $renderer->types;
    $renderer = $renderer->types(MojoX::Types->new);

Returns a L<MojoX::Types> (or compatible) object.
Returns the invocant if called with arguments.
Expects a L<MojoX::Types> or compatible object.

=head2 C<root>

   my $root  = $renderer->root;
   $renderer = $renderer->root('/foo/bar/templates');

Return the root file system path where templates are stored.
Returns the invocant if called with arguments.
Expects a file system path.

=head1 METHODS

L<MojoX::Types> inherits all methods from L<Mojo::Base> and implements the
following the ones.

=head2 C<add_handler>

    $renderer = $renderer->add_handler(phtml => sub { ... });

Returns the invocant.
Expects a file extension and rendering coderef. See L<render> for details
of the coderef to supply.

=head2 C<render>

    $success  = $renderer->render($c);

    $c->stash->{partial} = 1;
    $output = $renderer->render($c);

Returns a true value  if a template is successfully rendered.
Returns the template output if C<< partial >> is set in the stash.
Returns C<undef> if none of C<format>, C<template>, or C<template_path> are set in the
stash.
Returns C<undef> if the C<template> is defined, but lacks an extension
and no default handler is defined.
Returns C<undef> if the handler returns a false value.
Expects a L<Mojo::Context> object.

To determine the format to use, we first check C<< $c->stash->{format} >>, and
if that is empty, we check the extension on C<< $c->stash->{template_path} >>
and then C<< $c->stash->{template} >>.

C<< $c->stash->{format} >> may contain a value like 'html'.
C<< $c->stash->{template_path} >> may contain a full filesystem path like  '/templates/page.html'.
C<< $c->stash->{template} >> may contain a template file name like 'page.html'.

If C<< $c->stash->{template_path} >> is not set, we create it by appending
C<< $c->stash->{template} >> to the C<< root >> attribute.

If C<< $c->stash->{template} >> lacks an extension, we add one, using the value
of the C<< default_format >> attribute.

If C<< $c->stash->{format} >> is not defined, we try to determine it from the
extension on C<< $c->stash->{template_path} >>.

If no handler is found for the C<< format >>, we emit a warning, and check for
a handler for the C<< default_format >>.

The handler receives three arguments: the renderer object, the L<Mojo::Context>
object, and a reference an empty scalar, where the output can be accumulated.

If C<< $c->stash->{partial} >> is defined, the output from the handler is
simply returned.

Otherwise, we build out or own L<Mojo::Message::Response> and return one for
success. We'll default to a 200 response code if none is provided, and default
to 'text/plain' if there is no type associated with this format via the C<<
types >> attribute.

=cut
