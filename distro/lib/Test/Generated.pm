package Test::Generated;
use strict;
use warnings;

use base "Test::Class";

our $VERSION = '0.1';

use Test::More;
use YAML::XS;
use Sub::Name;
use Perl6::Slurp;
use Data::Dumper;

use Test::Generated::TestSequence;
use Test::Generated::TestSequenceList;

# this is an abstract base class, no tests here
# but we need to skip it or startup/shutdown methods
# will run for this class
Test::Generated->SKIP_CLASS( 1 );

my @generator_classes = (
  'Test::Generated::Command',
  'Test::Generated::Manifest',
  'Test::Generated::Perl',
  'Test::Generated::ControlFlow',
  );

sub generator_classes {
  my $class = shift;
  @generator_classes = @_ if scalar @_;
  return @generator_classes;
}

sub load_generator_classes {
  my $class = shift;

  foreach my $gc ($class->generator_classes) {
    my @errs = require_glob($gc);
    warn @errs if @errs;
  }
}

# Sometimes our generator classes need to access methods
# here, but if we are subclassed they should really use
# the subclass methods in case of overrides. So we
# provide a way for our subclasses to tell us they are
# in charge...
#    generators will call Test::Generated->base_class->...
#    subclasses should call __PACKAGE__->set_base_class;
my $TG_class = __PACKAGE__;
sub set_base_class { $TG_class = shift; }
sub base_class     { return $TG_class;  }

######################################################################
# Module::Require::require_glob
# copied from v0.4
#
# Copyright (C) 2001 Texas A&M University.  All Rights Reserved.
#
# This module is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
sub require_glob {
    my %modules = ( );
    while(@_) {
        my $file = shift;
        $file =~ s{::}{/}g;
        $file .= '\.pm';
        my $fileprefix = "";

        if($file =~ m{^(.*)/([^/]*)$}) {
            $fileprefix = $1;
            $file = $2;
        }

        # thanks to `perldoc -f require' for the basic logic here :)
        foreach my $prefix (@INC) {
            next unless -d "$prefix/$fileprefix";
            my @files = eval "<$prefix/$fileprefix/$file>";
            foreach my $realfilename (@files) {
                my $f = $realfilename;
                $f =~ s{^$prefix/$fileprefix/}{};
                next if $INC{$realfilename} || $INC{"$fileprefix/$f"};
                if( -f $realfilename ) {
                    $modules{"$fileprefix/$f"} = undef;
                    eval {
                        if(eval { require $realfilename }) {
                            $INC{"$fileprefix/$f"} = $realfilename;
                            delete $modules{"$fileprefix/$f"};
                            delete $INC{$realfilename};
                            warn "loaded $fileprefix/$f"
                                if defined $ENV{MODREQ_DEBUG};
                        }
                        else
                        {
                            warn "$fileprefix/$f: $@";
                        }
                    };
                warn "$fileprefix/$f: $@" if $@;
                }
            }
        }
    }
    return unless defined wantarray;
    return wantarray ? keys %modules : scalar keys %modules;
}
######################################################################


# handle for the fixture in use
# so we can access it secretly...
our $_TG_Fixture;

# generated name
my $test_name = 'generated00000000';

sub gen_test_file {
  my $package = shift;
  my $file    = shift;

  my $fh = IO::File->new($file);
  return $package->gen_tests( $fh );
}

sub gen_tests {
  my $package = shift;

  my $fh = shift || \*DATA;
  my $fn = shift || '(unknown)';
  my @contents = slurp $fh;
  $DB::single = 1;
  my $line = $.;
  foreach (@contents) {
    s{__FILE__}{$fn}g if $fn;
    s{__LINE__}{$line}g;
    s{^- (.*)$}{- test: $fn:$line\n  $1};
    s{^-$}{- test: line $line of $fn};
    $line++;
  }
  my $ydoc = Load( join('', @contents) );

  return $package->gen_test_seq( $ydoc );
}

sub gen_test_seq {
  my $package = shift;
  my $ydoc    = shift;

  $package->load_generator_classes;

  my @all_tests = ();

  foreach my $tst (@$ydoc) {

    die unless ref($tst) eq 'HASH';

    my @tests;
    my $count = 0;

    foreach my $class (@generator_classes) {
      if ($class->can_handle( $tst )) {
        my $ntst   = $class->normalize  ( $tst  );
        $count    += $class->count_tests( $ntst );
        push @tests, Test::Generated::TestSequence->new(
          document => $ntst,
          count    => $count,
          tests    => [$class->make_tests ( $ntst )],
          name     => ($ntst->{test} || ''),
        );
      }
    }

    push @all_tests, @tests;
  }

  return Test::Generated::TestSequenceList->new( tests => \@all_tests );
}

sub load_tests {
  my $package = shift;
  $package->install_tests( $package->gen_tests( @_ ) );
}

sub install_tests {
  my $package = shift;
  my $testseqlist = shift;

  foreach my $testseq ($testseqlist->get_tests) {
    my $longname = $package . '::' . $test_name;

    no strict 'refs';
    *{$longname} = subname $longname => sub {
      my $fixt = shift;
      diag("Running generated test: " . ($testseq->get_name || $longname));
      $package->run_one_test_sequence( $fixt, $testseq );
    };

    $package->add_testinfo( $test_name, 'test', $testseq->get_count );

    $test_name++;
  }

}

sub run_test_sequence {
    my $package = shift;
    my $fixt    = shift;
    my $testlist = shift;

    foreach my $testseq ($testlist->get_tests) {
        $package->run_one_test_sequence( $fixt, $testseq );
    }
}

sub run_one_test_sequence {
    my $package = shift;
    my $fixt    = shift;
    my $testseq = shift;

    no warnings 'redefine';
    no strict 'refs';
    foreach my $test ($testseq->get_tests) {
        my $clean_tdoc = $testseq->get_document;
        my $tdoc = $fixt->interpolate_preserved_captures_throughout( $clean_tdoc );
        {
            local $_TG_Fixture = $fixt;
            my $tb_regex_ok = \&Test::Builder::_regex_ok;
            local *{"Test::Builder::_regex_ok"} = _tg_regex_ok($tb_regex_ok);
            $test->( $fixt, $tdoc );
        }
    }
}


# autoload tests
# NB this only works for one file per 'module'
# additional files need an explicit
#   __PACKAGE__->load_tests(\*DATA, __FILE__);
# NBNB this line is always "safe" to include
# thanks to the eof() test below
INIT {
  foreach my $subclass (__PACKAGE__->_test_classes) {
    no strict 'refs';
    next if eof(\*{"$subclass"."::DATA"});
    __PACKAGE__->load_tests (\*{"$subclass"."::DATA"}, $subclass);
  }
}

# autorun tests
# NB this should be called in an END block in each test 'module'
# the conditional means only the first such block actually runs the tests
sub runtests_once {
  Test::Class->runtests
    unless Test::Class->builder->current_test > 1;
}


# preserved captures

# we wrap Test::Builder::_regex_ok which implements like and unlike
# any other regexp use, it's DIY
sub _tg_regex_ok {
  my $orig = shift;
  return sub {
    my ($self, $text, $re, $cmp, $desc) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    if (defined $_TG_Fixture and UNIVERSAL::can($_TG_Fixture, 'preserve_captures')) {
      $_TG_Fixture->preserve_captures($text, $re);
    }
    return $orig->($self, $text, $re, $cmp, $desc);
  };
}

# by fixture...
my %pcaps;

sub preserve_captures {
  my $fixt = shift;
  my $text = shift;
  my $re   = shift;

  my @captures = $text =~ m{$re};

  # NB this is a check that any captures were made,
  # we can't just use @captures thanks to the oh-so-helpful
  # return value when no captures are present... see perlop
  return unless defined $1;

  my $fixtref = (ref $fixt) || $fixt;

  $pcaps{$fixtref} ||= {};

  # NB captures numbered from 1, not from 0 ($0 is unrelated!)
  # *but* @captures number from 0
  $pcaps{$fixtref}{1+$_} = $captures[$_] foreach (0 .. $#captures);

  # check for named captures, which override if the name is a number
  if (scalar keys(%+)) {
    $pcaps{$fixtref}{$_} = $+{$_} foreach keys(%+);
  }
}

# API for custom parsers
sub capture {
  my $fixt = shift;
  my %caps = @_;

  my $fixtref = (ref $fixt) || $fixt;

  $pcaps{$fixtref}{$_} = $caps{$_} foreach keys(%caps);
}

sub interpolate_preserved_captures {
  my $fixt = shift;
  my $text = shift;

  my $fixtref = (ref $fixt) || $fixt;
  my $data = $pcaps{$fixtref};

  no warnings 'uninitialized';
  $text =~ s{\\k<([^>]+)>}{$data->{$1}}eg;

  return $text;
}

sub interpolate_preserved_captures_throughout { shift->_ipct(@_) }
sub _ipct {
  my $fixt = shift;
  my $ydoc = shift;

  if (ref($ydoc) eq 'ARRAY') {
    return [map {$fixt->_ipct($_)} @$ydoc];
  } elsif (ref($ydoc) eq 'HASH') {
    return {map {($fixt->_ipct($_) => $fixt->_ipct($ydoc->{$_}))} keys %{$ydoc}};
  } elsif (not ref($ydoc)) {
    return $fixt->interpolate_preserved_captures($ydoc);
  }
}


1;
__END__

=head1 NAME

Test::Generated - automatic generation of unit tests from simple YAML declarations

=head1 SYNOPSIS

  use base 'Test::Generated';
  __PACKAGE__->load_tests( \*DATA, __FILE__ ); # only needed if multiple files include tests
  1;
  __DATA__
  ---
  - cmd: date
    out:
     - Mon|Tue|Wed|Thu|Fri|Sat|Sun
     - Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec

=head1 DESCRIPTION

This module defines an extensible framework for specifying and running tests of
command-line tools, including client-server systems. Tests are defined by simple
YAML specifications which are converted by pluggable modules into Test::Class
test methods. Basic modules handle command line utilities, filesystem manifests,
perl code and structured data comparison. The pluggable API makes it easy to
extend the basic features or define new test types, for example to modify the
default settings for certain command line tools or to handle extended ACLs in
manifests.

Tests using regexp matching will preserve captured subexpressions to be referred
to in subsequent tests (in the same class of tests). Under Perl 5.10 and later,
the standard named capture syntax can be used directly. For earlier Perl versions
a similar syntax can refer to numbered captures, or some modules will allow explicit
control of the preserved capture data.

The capture mechanism can be preloaded with data to configure the actual test
execution, for example to select hosts or ports via a configuration file or
computed from the environment.

The basic modules included are each documented separately, this document
describes the common API they all implement and the way the test methods are
created.

=head2 Standard Features

In all test documents the strings __FILE__ and __LINE__ will be substituted with
the current filename (if known) and line number.

Each test has a name, which is printed as a diagnostic when the tests are run.
The default name is "__FILE__:__LINE__" but can be overridden by setting a value
for the key 'test'. The name (and file/line) are useful when running different
test subsets, since the test numbers change over time.

=head1 SUBCLASSING

The main reason for subclassing Test::Generated is to include a different set
of test generator classes, either customized or additional interpretations
of the YAML test specifications.

=head2 Example

  package Foo::Test::Generated;
  use base 'Test::Generated';
  __PACKAGE__->SKIP_CLASS(1); # No tests in this class, so don't run setup/teardown methods
  __PACKAGE__->generator_classes( qw(
        Foo::Test::Generated::Command
        Test::Generated::Manifest
        Test::Generated::Perl
    ) );
 1;

The default generator classes included are Test::Generated::Command and Test::Generated::Manifest.
Note that if an override list is specified, it replaces the default rather than adding to it.

=head1 EXECUTION

Tests are compiled by the C<load_tests> method, which is called automatically on the
DATA handle of every subclass of Test::Generated, from an INIT block. Note that the
behaviour of DATA handles means that where multiple files of tests are used, each will
need to explicitly load its own tests (as in the main SYNOPSIS).

The YAML document specifying tests should be a sequence of mappings. Each item in the sequence
is processed in turn as a separate test specification. Each generator class in turn will be
allowed to construct tests from the specification.

The tests will then be executed by Test::Class. In addition to the fixture provided by
Test::Class as the first parameter to the test method, the YAML document fragment
defining the test is passed as the second argument.

Any regexp testing done via Test::Builder::_regex_ok, which includes Test::More::like etc.,
will have any captures preserved. The test specification will have references to preserved
captures interpolated before the test method is called.

=head2 Capture Example

  package Capture::Example;
  use base 'Test::Generated';
  __PACKAGE__->load_tests (\*DATA, __FILE__);
  1;
  __DATA__
  ---
  - cmd: date
    out: (Mon|Tue|Wed|Thu|Fri|Sat|Sun)
  - cmd: date
    out: \k<1>

This test sequence will run the date command twice in succession. for the first run, the output will
be matched against the "day of week" regexp, which will be captured and preserved. The second run
will have its output matched against the regexp "\k<1>" after interpolation, which will be from
the preserved capture of the day-of-week. Thus the tests will succeed unless the two commands are
run either side of midnight.

For Perl 5.10 and later the standard named capture syntax can be used, and named captures will
override any numbered captures.

Test methods written in Perl (via Test::Generated::Perl) can directly store named (or numeric)
captures by calling the C<capture> method on the test fixture:

  sub my_capture {
    my $fixture = shift;
    my $testdoc = shift;
    $fixture->capture( myname => 'my value', myother => 'other value' );
  }

Note that captures are stored per class, for example in the code above the captures will be
available for any (subsequent) test in the Capture::Example class.

=head2 Using Captures for Configuration

Using the C<capture> method the "\k" values can be set before loading the tests, which will cause
the entire test document to be interpolated before execution. This could be used to configure a
test suite to connect to specific servers, or on specific ports, etc. based on arbitrary
computed values. For example:

=head2 Config Example

  package Config::Example
  use base 'Test::Generated';
  __PACKAGE__->capture( host => 'myhost.example.com' );
  __PACKAGE__->load_tests (\*DATA, __FILE__);
  1;
  __DATA__
  ---
  - cmd: nc \k<host> daytime
    out: Mon|Tue|Wed|Thu|Fri

This is obviously an artificial example, but this technique can be useful for random choices
or configuration via external files or databases.

=head1 TEST GENERATOR API

Each test generator must provide four class methods, each taking a single parameter: the YAML test
document for the tests being generated. Module authors should remember that these methods will be
called from an INIT block and the test documents will not yet be interpolated, so often the
test code returned will need to reexamine the tset document at run time.

=over 4

=item B<can_handle>

This method should examine the test document and return a true value if the module can generate
tests for this item. Typically a specific mapping key will be expected, but more complex tests
can be coded.

=item B<normalize>

This method will be called if C<can_handle> returns a true value and provides an
opportunity to manipulate the test document to handle defaults etc. The return
value should be an equivalent test document, which will be used for further calls.

=item B<count_tests>

Since a test document can cause many actual tests to be performed, this method should
return the expected test count for the document passed. To simplify this calculation
it is recommended that the same number of tests be generated for every document
rather than performing complex calculations based on the deep test document content.

=item B<make_tests>

Finally the C<make_tests> method should return a list of CODE references which will
be executed in turn to execute the tests specified.

=head1 AUTHOR

David Lillie

=head1 BUGS

=head1 COPYRIGHT

=cut
