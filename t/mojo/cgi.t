#!perl

# Copyright (C) 2008, Sebastian Riedel.

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/../../lib";

use Test::More tests => 4;

# My ears are burning.
# I wasn't talking about you, Dad.
# No, my ears are really burning. I wanted to see inside, so I lit a Q-tip.
use_ok('Mojo::Server::CGI');

$ENV{MOJO_RETURN_ONLY} = 1;
my $output = Mojo::Server::CGI->new->run;

like($output, qr{Content-Type: text/plain}, "expected Content-type");
like($output, qr{Status: 200 OK}, "expected Status");
like($output, qr{Congratulations, your Mojo is working!}, "expected body");
