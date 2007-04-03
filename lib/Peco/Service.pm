package Peco::Service;

use strict;
use warnings;

use Carp qw/carp croak/;

*new_service_instance = \&new;
sub new {
    my ( $pkg, $class, $depends, $create, $attrs ) = @_;
    my $self = bless {
        class    => $class,
        depends  => $depends || [ ],
        create   => $create  || 'new',
        attrs    => $attrs   || { },
        instance => undef,
    }, $pkg;
    $self;
}

*depends = \&dependencies;
sub dependencies { wantarray ? @{ $_[0]->{depends} } : $_[0]->{depends} }

sub instance {
    my ( $self, $container, $key ) = @_;
    unless ( $self->{instance} ) {
        $self->{instance} = $self->_create_instance( $container, [ $key ] );
    }
    $self->{instance};
}

sub _create_instance {
    my ( $self, $container, $seen ) = @_;
    croak( "create method $self->{create} not defined for $self->{class}" )
        unless $self->{class}->can( $self->{create} );

    my @params = $self->_resolve_dependencies( $container, $seen );
    my $create = $self->{create};

    my $instance = $self->{class}->$create( @params );
    while ( my ( $setter, $value ) = each %{ $self->{attrs} } ) {
        $instance->$setter( $value );
    }
    return $instance;
}

sub _resolve_dependencies {
    my ( $self, $container, $seen ) = @_;
    $seen ||= [ ];
    my ( $dep, @resolved );
    foreach my $key ( @{ $self->dependencies } ) {
        if ( grep { $_ eq $key } @$seen ) {
            croak( 'cyclic dependency detected' );
        }
        eval { $dep = $container->instance( $key ) };
        croak( "Unsatisfied dependency $key for $self->{class}: $@" ) if $@;
        push @resolved, $dep;
    }
    @resolved;
}


package Peco::Service::Constant;

use strict;
use warnings;

use base qw/Peco::Service/;

sub new {
    my ( $class, $value ) = @_;
    bless {
        instance => $value,
    }, $class;
}

sub instance { shift->{instance} }
sub dependencies { }


package Peco::Service::Factory;

use strict;
use warnings;

use base qw/Peco::Service/;

sub new {
    my ( $class, $coderef, $depends ) = @_;
    bless {
        coderef => $coderef,
        depends => $depends,
    }, $class;
}

sub instance {
    my ( $self, $container, $key ) = @_;
    my @params = $self->_resolve_dependencies( $container, [ $key ] );
    $self->{coderef}->( $container, $key, @params );
}

1;
__END__

=head1 NAME

Peco::Service - Service specifications for Peco IoC containers

=head1 SYNOPSIS

 use Peco::Service;

 $service = Peco::Service->new( $class, \@depends, $create, \%attrs );
 $service = Peco::Service::Factory->new( \&subroutine, \@depends );
 $service = Peco::Service::Constant->new( $value );

=head1 DESCRIPTION

Service specifications for Peco IoC containers. See L<Peco::Container>
for usage details.

=head1 SERVICE TYPES

=head2 Peco::Service

A generic service registration class.

=head2 Peco::Service::Factory

Factory service registration class. Takes a coderef which is called
each time this service is accessed.

=head2 Peco::Service::Constant

For constant or scalar values.

=head1 SEE ALSO

L<Peco::Container>, L<IOC::Container>, L<http://www.picocontainer.org>

=head1 ACKNOWLEDGMENTS

Most of this code is ported from Rico, which is a Ruby implementation
of PicoContainer... which is Java

=head1 AUTHOR

Richard Hundt

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
