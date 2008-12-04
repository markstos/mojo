#!perl

use strict;
use warnings;

use FindBin '$Bin';
use Test::More tests => 5;
use Mojo;
use MojoX::Context;
use Mojo::Transaction;
use MojoX::Dispatcher::Static;

my $tx = Mojo::Transaction->new;
my $dispatcher = MojoX::Dispatcher::Static->new(root => "$Bin/errdocs");

my $ctx = MojoX::Context->new(
    tx  => Mojo::Transaction->new,
    app => Mojo->new,
);
$dispatcher->serve_404($ctx);
is($ctx->res->code, 404, "serve_404: sets 404 when physical file is found");
like($ctx->res->body, qr/physical/,
    "serve_404: found the physical file at default location");
is($ctx->res->headers->header('Last-Modified'),
    undef, "serve_404: no sense setting Last-Modified from a 404 file");

$ctx = MojoX::Context->new(
    tx  => Mojo::Transaction->new,
    app => Mojo->new,
);
$dispatcher->serve_404($ctx, 'not_found.html');
is($ctx->res->code, 404, "serve_404: sets 404 when physical file is missing");
like(
    $ctx->res->body,
    qr/File Not Found/,
    "serve_404: internal file is served when physical 404 file is also missing."
);

