package My::Tests;
use strict;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib/perl5";

use base "My::Generated";

1;

__DATA__
---
- dummy:
   - foo: bar
     data:
      - one
      - two
      - three
- dummy:
   - oof: bar
     allow-extra-keys: true
     data:
       one: 1
       two: 2
       three: 3

