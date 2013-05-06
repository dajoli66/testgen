package My::Tests;
use strict;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib/perl5";

use base "My::Generated";

__PACKAGE__->set_base_class;
__PACKAGE__->load_tests (\*DATA, __FILE__);

1;

__DATA__
---
- cmd: date
  out: (Mon|Tue|Wed|Thu|Fri|Sat|Sun)
- skip:
    - cmd: date
      out: \k<1>
    - skip_if: 1
      reason: my secret
    - cmd: date
      out: \k<1>

