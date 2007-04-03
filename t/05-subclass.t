use lib './lib';

use Test::More qw/no_plan/;

use Peco::Container;

my $c = Peco::Container->new;
ok( $c, 'constructed a container' );

$c->register( 'foo', 42 );
ok( $c->get('foo') == 42 );
{
    package My::Service;

    use base qw/Peco::Service/;

    sub new {
        my $class = shift;
        return bless {
            foo => shift,
        }, $class;
    }
}

$c->register( 'key1', 'My::Service', [ 'foo' ] );
my $obj1 = $c->get('key1');
ok($obj1);
ok($obj1->isa('Peco::Service'));
ok(ref($obj1) eq 'My::Service');
ok($obj1->{foo} == $c->get('foo'));
