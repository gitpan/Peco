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
$c->register( 'key1', 'My::Class', undef, 'new' );
my $obj1 = $c->get('key1');
ok( $obj1 );
$c->register( 'key2', 'My::Class', [ ], 'new' );
my $obj2 = $c->get('key2');
ok( $obj2 );

ok( $obj1 == $c->get('key1') );
ok( $obj2 != $c->get('key1') );
