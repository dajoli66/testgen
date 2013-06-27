package My::Tests;
use strict;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib/perl5";

use base "My::Generated";
__PACKAGE__->load_tests (\*DATA, __FILE__);
END { __PACKAGE__->runtests_once }

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

