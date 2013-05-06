package My::Tests;
use strict;
use warnings;

use base "Test::Generated";
__PACKAGE__->load_tests (\*DATA, __FILE__);

1;

__DATA__
---
-
  test: first run of date
  cmd: date
  out:
   - (Mon|Tue|Wed|Thu|Fri|Sat|Sun)
   - Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec
-
  cmd: ls
  out:
   - Build.PL
-
  cmd: date
  ###: check runs on same day as earlier run
  out: \k<1>
