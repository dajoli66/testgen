package Test::Generated::ControlFlow;
use strict;
use warnings;

use Test::More;

sub can_handle {
  my $class = shift;
  my $tdoc  = shift;

  return 0 unless ref($tdoc) eq 'HASH';
  return 1 if exists $tdoc->{include};
  return 1 if exists $tdoc->{todo};
  return 1 if exists $tdoc->{skip};
  return 1 if exists $tdoc->{skip_if};
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

  my $count = 0;

  map { $count += $_->[1] }
	Test::Generated->base_class->gen_test_file( $tdoc->{include} )
		if $tdoc->{include};

  map { $count += $_->[1] }
	Test::Generated->base_class->gen_test_seq( $tdoc->{todo} )
		if $tdoc->{todo};

  map { $count += $_->[1] }
	Test::Generated->base_class->gen_test_seq( $tdoc->{skip} )
		if $tdoc->{skip};


  return $count;
}

our $TGCF_skip_count = 0;

sub make_tests {
  my $class = shift;
  my $tdoc  = shift;

  if (exists $tdoc->{include}) {
    my @testseqs = Test::Generated->base_class->gen_test_file( $tdoc->{include} );
    return (
        sub { Test::Generated->base_class->run_test_sequence( shift, @testseqs ) }
    );
  }

  if (exists $tdoc->{todo}) {
    my $reason = $tdoc->{reason};
    $reason ||= 'TODO';

    my $TB = Test::Builder->new; # singleton

    my @testseqs = Test::Generated->base_class->gen_test_seq( $tdoc->{todo} );
    return (
	      sub {
	          $TB->todo_start( $reason );
            Test::Generated->base_class->run_test_sequence( shift, @testseqs );
            $TB->todo_end;
 	      }
    );
  }

  if (exists $tdoc->{skip}) {

    my @testseqs = Test::Generated->base_class->gen_test_seq( $tdoc->{skip} );
    my $skip_block = 0;
    map {$skip_block += $_->[1]} @testseqs; # total test count in this skip block
    return (
      sub {
        my $fixt = shift;
        local $TGCF_skip_count = $skip_block;
      SKIP: {
          foreach my $testseq (@testseqs) {
            Test::Generated->base_class->run_one_test_sequence( $fixt, @$testseq );
            $TGCF_skip_count -= $testseq->[1];
          }
        }
      }
    );
  }

  if (exists $tdoc->{skip_if}) {
      my $expr = $tdoc->{skip_if};
      my $reason = $tdoc->{reason} || 'remaining tests';
      my $count  = $tdoc->{count}  || 1;
      return (
	  sub {
		my $fixt = shift;
		my $tdoc = shift;
		my $pkg  = ref $fixt;
	        my $cond = (eval "package $pkg; $expr");
		if ($@) {
		    diag "skip condition error: $@";
		} else {
		    diag "skip condition evaluated ".($cond ? 'true' : 'false');
		}
		# gotta love perl that this can work...
		Test::More::skip( $reason, $TGCF_skip_count ) if $cond;
	  }
	);
  }

}

1;
__END__

=head1 NAME

Test::Generated::ControlFlow - generator module for Test::Generated to allow simple control flow

=head1 SYNOPSIS

  ---
  - include: /my/basic/tests.yml
  - todo:
    reason: not yet implemented
      - cmd: /bin/false
  - skip:
      - skip_if: 1<2
        reason: my secret
      - cmd: /bin/true

=head1 DESCRIPTION

This module controls generation of tests for Test::Generated with simple control flow
methods.

The "include" key allows a set of tests to be kept in a separate file, for clarity
or reuse. Relative paths will be resolved from the current working directory.

The "todo" key marks a set of tests as not expected to pass, so that their failure
is not counted as the whole test suite failing. A "reason" may be supplied as
documentation.

The "skip" key allow a set of tests to be skipped, subject to a condition. A sequence of
test specifications should be given under the "skip" key, which will be executed as normal.
A "skip_if" test will evaluate a perl expression and if it evaluates to a true value, the
remainder of the test sequence under the (innermost) "skip" key will not be executed. A
"reason" can be given, as with "todo".


=head1 AUTHOR

David Lillie

=head1 BUGS

=head1 COPYRIGHT

=cut
