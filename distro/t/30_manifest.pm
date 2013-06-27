package My::Tests;
use strict;
use warnings;

use base "Test::Generated";
__PACKAGE__->load_tests (\*DATA, __FILE__);

END { __PACKAGE__->runtests_once }

1;

=pod

=cut


__DATA__
---
- cmpdirs:
  - t/cmpd/d1
  - t/cmpd/d2
- manifest:
  - dir: etc
  - file: etc/file0001
  - file: etc/file0002
  - link: etc/link0001
    target: file0001
    type: file
  - none: no-such-file
  basedir: t

