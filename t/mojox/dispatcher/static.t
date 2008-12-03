#!perl

use strict;
use warnings;

use FindBin '$Bin';
use Test::More tests => 5;
use Mojo::Transaction;
use MojoX::Dispatcher::Static;

my $dispatcher = MojoX::Dispatcher::Static->new(root => "$Bin");

my $tx = Mojo::Transaction->new;
$dispatcher->serve_404($tx);
is($tx->res->code, 404, "serve_404: sets 404 when physical file is found");
like($tx->res->body, qr/physical/,
    "serve_404: found the physical file at default location");
is($tx->res->headers->header('Last-Modified'),
    undef, "serve_404: no sense setting Last-Modified from a 404 file");

$tx = Mojo::Transaction->new;
$dispatcher->serve_404($tx, 'not_found.html');
is($tx->res->code, 404, "serve_404: sets 404 when physical file is missing");
like($tx->res->body, qr/Additionally/,
    "serve_404: internal file is served when physical 404 file is also missing."
);

