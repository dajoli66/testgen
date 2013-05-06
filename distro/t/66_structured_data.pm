package My::Tests;
use strict;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib/perl5";

use base "My::Generated";
__PACKAGE__->load_tests (\*DATA, __FILE__);

1;

__DATA__
---
- date:
   - tstamp: 0
     when:
      sec: 0
      min: 0
      hour: 0
- perl: time() > 0
