package My::Tests;
use strict;
use warnings;

use base "Test::Generated";
__PACKAGE__->load_tests (\*DATA, __FILE__);
END { __PACKAGE__->runtests_once }


sub parse_day_from_date {
  my $fixt = shift;
  my $tdoc = shift;
  my ($out, $err) = @_;

  my ($day) = ($out =~ /(Mon|Tue|Wed|Thu|Fri|Sat|Sun)/);

  $fixt->capture( day => $day );
}

1;

__DATA__
---
-
  test: test in __FILE__ at line __LINE__
  cmd: date
  out:
   - Mon|Tue|Wed|Thu|Fri|Sat|Sun
   - Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec
  parser: parse_day_from_date
-
  cmd: date
  out: \k<day>
