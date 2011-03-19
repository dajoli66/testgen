package Test::Generated::Perl;
use strict;
use warnings;

use Test::More;

sub can_handle {
  my $class = shift;
  my $tdoc  = shift;

  return 1 if ref($tdoc) eq 'HASH' and exists $tdoc->{perl};
  return 0;
}

sub normalize {
  my $class = shift;
  my $tdoc  = shift;

  return $tdoc;
}

sub count_tests {
  my $class = shift;
  my $tdoc  = shift;

  return 1 + ($tdoc->{tests} || 0);
}

sub make_tests {
  my $class = shift;
  my $tdoc  = shift;

  my $expr = $tdoc->{perl};

  my $code = sub {
    my $fixt = shift;
    my $tdoc = shift;

    if ($fixt->can($expr)) {
      ok( $fixt->$expr( $tdoc ), "method call succeeds" );
    } else {
      my $pkg  = ref $fixt;
      ok( (eval "package $pkg; $expr"), "expression eval succeeds" );
    }
  };

  return ($code);
}

1;
__END__

=head1 NAME

Test::Generated::Perl - generator module for Test::Generated to handle pure perl tests

=head1 SYNOPSIS

  ---
  - perl: my_complex_tests
  - perl: time > 1000
  - perl: ok( 2>1, "first expr") and ok(3<4, "2nd expr")
    tests: 2
  - perl: get_private_var() > 0

=head1 DESCRIPTION

This module generates tests for Test::Generated where the tests are
coded in Perl.

The only option is to set the number of tests, by mapping key C<tests> to a number.

If the test names a method, that method will be called on the test fixture and
it will be passed the test document.

Otherwise, the test will be executed under C<eval> in the same package as the fixture.

In each case, the result value will be tested by Test::More::ok, producing a single
test for each test document by default.

=head2 Notes

Although the perl code is evaluated in the appropriate package, it is in a separate
lexical context from the main package code and hence lexical variables cannot
be accessed. Fully qualified variables can be accessed, but the recommendation is to
use accessor methods to deal with package data.

=head1 AUTHOR

David Lillie

=head1 BUGS

=head1 COPYRIGHT

=cut
