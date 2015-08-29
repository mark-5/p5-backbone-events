use strict;
use warnings;
use FindBin::libs;
use Test::More;
use Test::Backbone::Events::Utils;

my $handler = test_handler();

my %triggered;
my $first  = sub { $triggered{first}++  };
my $second = sub { $triggered{second}++ };

$handler->on('test-event', $first);
$handler->on('test-event', $second);

$handler->off('test-event', $first);
$handler->trigger('test-event');
ok !$triggered{first}, 'skipped first callback after turning it off explicitly';
is $triggered{second}, 1, 'triggered second callback';

%triggered = ();
$handler->off('test-event');
$handler->trigger('test-event');
ok !%triggered, 'skipped all callbacks after calling off with only event name';

done_testing;
