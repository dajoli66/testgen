package Test::Generated::Command;
use strict;
use warnings;

use Test::More;
use YAML::XS;
use Sub::Name;
use Perl6::Slurp;

use Test::Client;

sub can_handle {
  my $class = shift;
  my $tdoc  = shift;

  return 1 if ref($tdoc) eq 'HASH' and exists $tdoc->{cmd} and not ref($tdoc->{cmd});
  return 0;
}

sub command_runner {
  my $class = shift;
  my $fixt  = shift;

  return $fixt->get_client if $fixt->isa( 'Test::ClientServer' );
  return Test::Client->new();
}

sub normalize {
  my $class = shift;
  my $tdoc  = shift;

  chomp $tdoc->{cmd};
  $tdoc->{rc}  = 0  unless defined $tdoc->{rc};
  $tdoc->{err} = '' unless defined $tdoc->{err};

  # handle multiple out/err regexps (counting)
  $tdoc->{out} = [ $tdoc->{out} ] unless ref($tdoc->{out});
  $tdoc->{err} = [ $tdoc->{err} ] unless ref($tdoc->{err});

  if ($tdoc->{parser}) {
    $tdoc->{parser} = [ $tdoc->{parser} ] unless ref($tdoc->{parser});
  }

  return $tdoc;
}

sub count_tests {
  my $class = shift;
  my $tdoc  = shift;

  my $test_count = 0;

  $test_count += 3; # for run() + rc check + signal check
  $test_count += scalar @{$tdoc->{out}};
  $test_count += scalar @{$tdoc->{err}};

  return $test_count;
}

sub make_tests {
  my $class = shift;
  my $tdoc  = shift;

  if ($ENV{TEST_GEN_DEBUG}) {
    print "defining new test:\n";
    print "  would run '$tdoc->{cmd}'\n";
    print "  would expect rc of '$tdoc->{rc}'\n";
    print "  would expect stdout to say '$_'\n" foreach @{$tdoc->{out}};
    print "  would expect stderr to say '$_'\n" foreach @{$tdoc->{err}};
  }

  my $test_code = sub {
      my $fixt = shift;
      my $tdoc = shift;

      my $test_client = $class->command_runner( $fixt ); # NB not $self

      # NB +1 test to run the command
      $test_client->run($tdoc->{cmd});

      # check rc is as expected
      # we always expect no signal
      is( $test_client->rc & 0x00ff, 0, q{command did not exit by signal} );
      if ($tdoc->{rc} and $tdoc->{rc} =~ m/^-?\d+$/) {
        is( $test_client->rc, $tdoc->{rc}, q{command had correct non-zero exit code} );
      } elsif ($tdoc->{rc}) {
        isnt( $test_client->rc, 0, q{command had non-zero exit code} );
      } else {
        is( $test_client->rc, 0, q{command had zero exit code} );
      }

      #check stderr is as expected
      foreach my $err (@{$tdoc->{err}}) {
        if ($err) {
          like( $test_client->stderr, qr{$err}, qq{command stderr matched '$err'} );
        } else {
          is( $test_client->stderr, $err, q{command has no error} );
        }
      }

      #check stdout is as expected
      foreach my $out (@{$tdoc->{out}}) {
        if ($out) {
          like( $test_client->stdout, qr{$out}, qq{command got expected output '$out'} );
        } else {
          is( $test_client->stdout, $out, q{command had no output as expected} );
        }
      }

      # pass through to custom parsers if specified
      if ($tdoc->{parser}) {
        foreach my $parser (sort @{$tdoc->{parser}}) {
          my $method = $fixt->can($parser);
          if ($method) {
            # don't crash out if the parser dies
            eval { $fixt->$method( $tdoc, $test_client->stdout, $test_client->stderr ) };
          }
        }
      }

  };

  return $test_code;
}

1;
__END__

=head1 NAME

Test::Generated::Command - generator module for Test::Generated to handle external commands

=head1 SYNOPSIS

  ---
  - cmd: full command line to run
    rc:  0
    out: expected stdout regexp
    err: expected stderr regexp
    parser: custom output parser

=head1 DESCRIPTION

This module generates tests for Test::Generated where the exit code and output of an external
command needs to be validated.

The only required key is C<cmd>, specifying the full command line to be executed.
The command will be executed by a trivial Test::Client object by default, or if
the test fixture is a subclass of Test::ClientServer the Test::Client object constructed
by the factory config at startup will be used.

As described in Test::Client, there will be three tests automatically generated
just for running the command: execution, exit code and a check for signals.

=head1 OPTIONS

=over 4

=item B<cmd>

Required. Specifies the command to run, complete with all arguments.

=item B<rc>

Optional (default: 0). Defines the expected exit code of the command.

=item B<out>

Optional. Can be a YAML sequence. Defines regexp(s) which are matched in turn
against the command standard output.

=item B<err>

Optional (default: ''). Can be a YAML sequence. Defines regexp(s) which are matched in turn
against the command standard error.

=item B<parser>

Optional. Specifies the name of a perl method to be called on the test fixture, being passed
(in addition to the fixture) the test document and the command stdout and stderr. The main use
case is to perform more complex matching on the command output for preserving capture data.

Note that the parser is executed inside an C<eval> and does not count as a test.

=head1 AUTHOR

David Lillie

=head1 BUGS

=head1 COPYRIGHT

=cut
