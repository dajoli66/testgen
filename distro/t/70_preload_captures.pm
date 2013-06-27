package My::Tests;
use strict;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib/perl5";

use base "My::Generated";

$DB::single = 1;
my @days = qw(Sun Mon Tue Wed Thu Fri Sat);
my $today = $days[(localtime)[6]];
__PACKAGE__->capture( config => $today, host => 'localhost' );

__PACKAGE__->load_tests (\*DATA, __FILE__);
END { __PACKAGE__->runtests_once }

1;

__DATA__
---
-
  cmd: date
  out: \k<config>
-
  cmd: nc \k<host> 13
  out: JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC


