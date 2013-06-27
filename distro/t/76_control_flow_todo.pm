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
- cmd: date
  out: (Mon|Tue|Wed|Thu|Fri|Sat|Sun)
- reason: not implemented
  todo:
    - cmd: nc localhost daytime
      out: \d
    - cmd: date
      out: \k<1>
