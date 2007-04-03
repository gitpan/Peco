use lib './lib';

use Test::More qw/no_plan/;

use Peco::Container;

my $c = Peco::Container->new;
ok( $c, 'constructed a container' );

my $counter = 0;
my $coderef = sub { ++$counter };

$c->register( 'key1', $coderef );
ok( $c->get('key1') == 1 );
ok( $c->get('key1') == 2 );
ok( $c->get('key1') == 3 );
ok( $counter == 3 );

$c->register( 'const', 5 );
$c->register( 'key2', sub { $counter * $_[2] }, [ 'const' ] );
ok( $c->get('key2') == 15 );
