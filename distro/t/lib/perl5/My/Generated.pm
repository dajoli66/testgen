package My::Generated;
use strict;
use warnings;

use Test::Generated;

__PACKAGE__->set_base_class;

__PACKAGE__->SKIP_CLASS(1);

__PACKAGE__->generator_classes(
    Test::Generated->generator_classes, # standard generators
    qw(
      My::Generated::date
      My::Generated::dummy
    ) );

1;
