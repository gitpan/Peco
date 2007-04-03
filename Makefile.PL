use inc::Module::Install;

name('Peco');
author('Richard Hundt <richard@hive-systems.com>');
abstract('Light Inversion of Control container');
license('artistic');
version_from('lib/Peco/Container.pm');
build_requires('Test::More');

requires(
    'Carp'                  => undef,
    'Scalar::Util'          => undef,
    'Class::Accessor::Fast' => undef,
);

check_nmake();
&WriteAll();
