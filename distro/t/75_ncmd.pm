package My::Tests;
use strict;
use warnings;

use base "Test::Generated";
__PACKAGE__->load_tests (\*DATA, __FILE__);
END { __PACKAGE__->runtests_once }


1;

__DATA__
---
-
  ncmd: mktemp /tmp/ncmd.XXXX
  out: /tmp/ncmd.(....)
-
  manifest:
    - file: /tmp/ncmd.\k<1>
-
  cmd: date
  out: Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec
-
  ncmd: rm /tmp/ncmd.\k<1>
-
  manifest:
    - none: /tmp/ncmd.\k<1>
