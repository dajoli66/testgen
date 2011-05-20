package My::Tests;
use strict;
use warnings;

use base "Test::ClientServer";

use Test::More;

sub get_client {
  my $fixt = shift;
  return Test::ClientServer->get_client( ref $fixt );
}

sub basic : Test(5) {
  my $fixt = shift;

  my $test_client = get_client( $fixt );

  # NB run_ok is 3 tests
  $test_client->run_ok(qq{date -Iseconds});
  is( $test_client->stderr, '', "basic client command has no error" );
  diag( "stdout is: " . $test_client->stdout );
  like( $test_client->stdout, qr{^\d\d\d\d-\d\d-\d\d},
      "found a good version string");
}

sub basic_xx : Test(5) {
  my $fixt = shift;

  my $test_client = get_client( $fixt );

  # NB run_ok is 3 tests
  $test_client->run_ok(qq{date -Iminutes});
  is( $test_client->stderr, '', "basic client command has no error" );
  diag( "stdout is: " . $test_client->stdout );
  like( $test_client->stdout, qr{^\d\d\d\d-\d\d-\d\d},
      "found a good version string");
}

1;
