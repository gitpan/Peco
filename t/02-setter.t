use lib './lib';

{
    package My::Class;
    sub new {
        my ( $class, $foo, $bar ) = @_;
        return bless {
            foo => $foo,
        }, $class;
    }
    sub bar {
        my ( $self, $bar ) = @_;
        if ( @_ == 2 ) {
            $self->{bar} = $bar;
        }
        $self->{bar};
    }
}

use Test::More qw/no_plan/;

use Peco::Container;

my $c = Peco::Container->new;
ok( $c );

$c->register( 'foo', 42 );
$c->register( 'key1', 'My::Class', [ 'foo' ], undef, { bar => 'baz' } );

my $obj1 = $c->get('key1');
ok( $obj1 );
ok( $obj1->{foo} == 42 );
ok( $obj1->{bar} eq 'baz' );
