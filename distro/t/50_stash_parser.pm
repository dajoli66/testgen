package My::Tests;
use strict;
use warnings;

use Test::More;

use base "Test::Generated";
__PACKAGE__->load_tests (\*DATA);

sub parse_date {
  my $fixt = shift;
  my $tdoc = shift;
  my ($out, $err) = @_;

  diag("parsing, out = '$out'");
  diag("parsing, err = '$err'");

  my ($day) = split /\s+/, $out;
  $fixt->{today} = $day;

  1;
}

1;

__DATA__
---
-
  cmd: date
  out:
   - Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec
  parser: parse_date
-
  perl: defined $fixt
-
  perl: $fixt->{today}
