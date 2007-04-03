use lib './lib';

use Test::More qw/no_plan/;

use Peco::Container;

my $c = Peco::Container->new;
ok( $c, 'constructed a container' );
ok( $c->is_empty );
ok( $c->size == 0 );
$c->register( 'key1', 'scalar' );

ok( not $c->is_empty );
ok( $c->has('key1') );
ok( $c->service('key1') );
ok( $c->size == 1 );
ok( $c->get('key1') eq 'scalar' );
ok( $c->instance('key1') eq 'scalar' );
