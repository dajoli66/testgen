package My::Generated;
use strict;
use warnings;

use base 'Test::Generated';

__PACKAGE__->SKIP_CLASS(1);

__PACKAGE__->generator_classes( qw(
    Test::Generated::Command
    Test::Generated::Manifest
    Test::Generated::Perl
    My::Generated::date
    My::Generated::dummy
    ) );

1;
