use lib './lib';

{
    package My::Class;
    sub new {
        my ( $class, $foo, $bar ) = @_;
        return bless {
            foo => $foo,
            bar => $bar,
        }, $class;
    }
}

use Test::More qw/no_plan/;

use Peco::Container;

my $c = Peco::Container->new;
ok( $c, 'constructed a container' );
ok( $c->is_empty );
ok( $c->size == 0 );

$c->register( 'key1', 'My::Class' );
my $obj1 = $c->get('key1');
ok( $obj1 );
ok( not defined $obj1->{foo} );
ok( not defined $obj1->{bar} );
ok( not defined $obj1->{baz} );

$c->register( 'foo', 42 );
$c->register( 'bar', 69 );
$c->register( 'key2', 'My::Class', [ 'foo', 'bar' ] );

ok( $c->get('foo') == 42 );
ok( $c->get('bar') == 69 );
my $obj2 = $c->get('key2');
ok( $obj2 );
ok( $obj2->{foo} == 42 );
ok( $obj2->{bar} == 69 );
