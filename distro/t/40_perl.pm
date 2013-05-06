package My::Tests;
use strict;
use warnings;

use Test::More;
use base "Test::Generated";
__PACKAGE__->load_tests (\*DATA, __FILE__);

my $private_var = 0;

sub get_private_var { $private_var }

sub my_complex_test {
  my $fixt = shift;
  my $tdoc = shift;

  diag("running complex tests");

  $private_var++;

  return 1;
}

1;

=pod

=cut


__DATA__
---
- perl: my_complex_test
- perl: time > 1000
- perl: ok( 2>1, "first expr") and ok(3<4, "2nd expr")
  tests: 2
- perl: get_private_var() > 0

