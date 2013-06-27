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
-
  cmd: date
  out:
    - (Mon|Tue|Wed|Thu|Fri|Sat|Sun)
- include: 't/inc001.yml'


