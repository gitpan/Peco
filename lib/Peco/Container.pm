package Peco::Container;

use strict;
use warnings;

use Carp qw/carp croak/;

our $VERSION = '1.0';

use Peco::Service;

use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/ services /);

sub new {
    my ( $class ) = @_;
    bless { }, $class;
}

sub register {
    my ( $self, $key, $class, $depends, $create, $attrs ) = @_;

    $class   ||= $key;
    $depends ||= [ ];
    $create  ||= 'new';
    $attrs   ||= { };

    $self->{services} ||= { };

    $self->assert_not_exists( $key );
    $self->{services}{$key} = $self->_create_service(
        $class, $depends, $create, $attrs,
    );
}

sub dependencies {
    my ( $self, $key ) = @_;
    $self->service( $key )->dependencies;
}

sub multicast {
    my ( $self, $method, @args ) = @_;
    foreach ( $self->instances ) {
        $_->$method( @args ) if UNIVERSAL::can( $_, $method );
    }
}

*get = \&instance;
sub instance {
    my ( $self, $key ) = @_;
    $self->service( $key )->instance( $self, $key );
}

*get_all = \&instances;
sub instances {
    my ( $self ) = @_;
    map { $self->instance( $_ ) } keys %{ $self->{services} };
}

sub has {
    my ( $self, $key ) = @_;
    exists $self->{services}{$key};
}

sub service {
    my ( $self, $key ) = @_;
    $self->assert_exists( $key );
    $self->{services}{$key};
}

sub size {
    my ( $self ) = @_;
    scalar( keys %{ $self->{services} } );
}

sub is_empty { !$_[0]->size }

sub assert_exists {
    my ( $self, $k ) = @_;
    croak("no such service: `$k'") unless exists $self->{services}{$k};
}

sub assert_not_exists {
    my ( $self, $k ) = @_;
    croak( "service already exists: `$k'" ) if exists $self->{services}{$k};
}

sub _create_service {
    my $self = shift;
    my ( $class, $depends, $create, $attrs ) = @_;

    no strict 'refs';
    if ( ref( $class ) ) {
        if ( ref( $class ) eq 'CODE' ) {
            return Peco::Service::Factory->new( $class, $depends );
        }
        return Peco::Service::Constant->new( $class );
    }
    elsif ( UNIVERSAL::isa( $class, 'Peco::Service' ) ) {
        return $class->new_service_instance( @_ );
    }
    elsif ( _is_class( $class ) or $class =~ /\w+::\w+/ ) {
        unless ( _is_class( $class ) ) {
            eval "require $class";
            die $@ if $@;
        }
        return Peco::Service->new( @_ );
    }
    else {
        return Peco::Service::Constant->new( $class );
    }
}

sub _is_class {
    my $class = shift;
    no strict 'refs';
    return defined *{ $class.'::new' }{CODE};
}

1;

__END__

=head1 NAME

Peco::Container - Light Inversion of Control (IoC) container

=head1 SYNOPSIS

 my $c = Peco::Container->new;

 $c->register( 'my_key', 'My::Class' );
 $c->register( 'my_key', 'My::Class', [ @deps ] );
 $c->register( 'my_key', 'My::Class', [ @deps ], 'create' );
 $c->register( 'my_key', 'My::Class', [ @deps ], 'create', { %attrs } );

 $c->register( 'my_key', 'My::Class', undef, 'create' );
 $c->register( 'my_key', 'My::Class', undef, 'create', { %attrs } );
 $c->register( 'my_key', 'My::Class', [ @deps ], undef, { %attrs } );

 my $instance = $c->get('my_key');
 my @instances = $c->get_all();

 $c->has('my_key') ? 1 : 0;
 $c->is_empty ? 1 : 0;

 $c->multicast( 'method', @args );

=head1 DESCRIPTION

Peco::Container is a small, flexible Inversion of Control (IoC) container
supporting both Constructor Injection and Setter Injection patterns, as well
prototype services (factories) and multicasting.

=head2 IoC Overview

Inversion of Control is simply a way of delegating object construction,
initialisation and location, for a given system, to a framework which
takes care of the details for you.

This is done by abstraction into two kinds of objects, a Container, which
acts as both registry and locator, and a Service which acts as specifier
and wrapper for the object/service which is registered with the container.

The easiest way to understand this is to look at a couple of simple examples.

=head2 Constructor Injection

If we were to have the following logger class which takes an B<IO::File>
object has an argument to the constructor:
 
 package My::Logger;
 sub new {
     my ( $class, $handle ) = @_;
     bless {
         handle => $handle,
     }, $class;
 }
 sub log { shift->{handle}->print( @_ ) }

We can see that we need to create the file handle before the logger object
is created, so the C<$handle> is a I<dependency> of the logger object. But
looking at the documentation for B<IO::File> we see that it too needs to
have arguments passed to its constructor, the filename and the mode, so
these are its dependencies which we need to inject. With Peco we would
describe this dependency hierarchy as follows:
 
 my $c = Peco::Container->new;

 $c->register('log_mode', O_APPEND);
 $c->register('log_file', '/var/log/my-app.log');
 $c->register('log_fh', 'IO::File', ['log_file', 'log_mode']);
 $c->register('my_logger', 'My::Logger', ['log_fh']);

Now when we say:

 my $logger = $c->get( 'my_logger' );

the dependencies are automatically (and recursively) resolved and a logger
instance is handed to us with an opened file handle in the correct state for
logging.

=head2 Specifying the Create Method

The fourth argument to I<register> is a string representing the method name
of the constructor to call when instantiating the object. This defaults to
'new' if undefined. To specify an alternative, we can say:

 $c->register('log_fh', 'IO::File', ['log_file'], 'new_tmpfile');

=head2 Setter Injection

A hash reference can be passed as the fifth (and final) parameter to
I<register> which will be used to set up fields in the instance where
the keys map to the name of the setter and the values to the parameters.

For example, assuming we have a setter in the My::Logger package for setting
the log level, called I<level>, then the following specification:

 $c->register('my_logger', 'My::Logger', ['log_fh'], undef, { level => 3 });

will effectively call:

 $logger->level( 3 );

setting the logging level to '3'.

=head2 Instance Lifetime

Ordinarily when calling $container->get( 'something' ), the instance is
only created the first time 'get' is called. On subsequent calls, the I<same>
instance is returned. Therefore, these instances are basically singletons
in the context of the container and are only destroyed when the container is
destroyed. However, there are two exceptions:

=head2 Constant Services

Constant services are simple scalars or references which are registered with
a container, and therefore are I<never> constructed by the container. This
follows when the second parameter to I<register> is either a reference
(blessed or otherwise), or a simple scalar value. For example:

 $c->register('log_file', '/var/log/my-app.log');

=head2 Factory Services

Sometimes it is useful to be able to generate a new instance I<every time>
the $container->get( 'something' ) method is called. This can be done by
passing a code reference as the second parameter to I<register>:

 $c->register('log_fh', \&mk_log_fh_pid, [ 'log_file', 'log_mode' ]);

 sub mk_log_fh_pid {
     my ( $path, $mode ) = @_;
     return IO::File->new( "$path-$$", $mode );
 }

=head1 METHODS

=over 4

=item B<register( $key, $class )>

=item B<register( $key, $class, \@depends )>

=item B<register( $key, $class, \@depends, $create )>

=item B<register( $key, $class, \@depends, $create, \%attrs )>

=item B<register( $key, $coderef )>

=item B<register( $key, $ref_or_object )>

Register a service with the container identified by I<$key>. The key must
be unique as the container will croak() if you try to register twice with
the same key.

I<$class> is either a string representing the class name or
a code reference or another scalar value. If it is a classname, then a
B<Peco::Service> specifier is created. If it is a code reference, then a
B<Peco::Service::Factory> specifier is created. For any other scalar a
B<Peco::Service::Constant> specifier is created.

I<\@depends> is an optional array reference of keys which will be resolved and
passed to the I<$class>'s constructor in the order specified.

I<$create> is an optional string which is the name of the constructor
subroutine to call. The default value is: I<new>.

I<$\%attrs> is an optional hash reference of 'setter' => 'value' pairs which
is used for setter injection. This is only meaningful where I<$class> is a
class and not a scalar.

=item B<get( $key )>

Returning an instance of I<$class>, resolving dependencies, and
constructing it as required, unless I<$class> is a code
reference, in which case the code reference is executed instead.

=item B<instance( $key )>

Alias for I<get( $key )>

=item B<get_all>

Returns instances for all service specifiers registered with this container.
Services which have not yet been resolved and constructed are done as a side
effect.

=item B<instances>

Alias for I<get_all>

=item B<has( $key )>

Returns a true value (actually a reference to the Peco::Service object) if
this container has a service registered for I<$key>.

=item B<service( $key )>

Alias for I<has( $key )>

=item B<size>

Returns the number of service specifiers registered with this container.

=item B<is_empty>

Returns a true value if there are no service specifiers registered with this
container.

=item B<multicast( $method, @args )>

Attempt to call I<$method> on each instance passing I<@args> as parameters.
Services which have not yet been resolved and constructed are done as a side
effect.

=item B<dependencies( $key )>

Returns the I<\@depends> array reference passed to the service specified by
I<$key> or an empty array reference if none was given.

=head1 SEE ALSO

L<Peco::Service>, L<IOC::Container>, L<http://www.picocontainer.org>

=head1 ACKNOWLEDGMENTS

Most of this code is ported from Rico, which is a Ruby implementation
of PicoContainer... which is Java

=head1 AUTHOR

Richard Hundt

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
