package Test::Generated::StructuredData;
use strict;
use warnings;

use Test::More;
use Test::Generated;

#
# define standard Test::Generated API methods
# based on a declarative description of structured data
# in terms of (1) how to generate the data and (2) how
# it is described in a test
#
# this module simply forces the caller class to
# be subclassed from this class and stashes the supplied
# config into a closure
#
# the generic API methods are implemented here for simple
# data structures (hash, list) and can be overridden to
# handle more complex structures or defaults if required
#

sub import {
    my $self   = shift;
    my %config = @_;

    my $caller = caller;

    # stash the config in a closure
    no strict 'refs';
    *{$caller . '::' . '_config'} = sub {return \%config};

    unless (UNIVERSAL::isa($caller, __PACKAGE__)) {
        push @{$caller . '::ISA'}, __PACKAGE__;
    }

    # by default structured data testers are abstract, i.e.
    # have no tests of their own.
    # set 'has_tests' to override (e.g. for startup/setup/teardown/shutdown tests)
    $caller->SKIP_CLASS(1) unless $config{has_tests};
}

sub can_handle {
    my $self = shift;
    my $tdoc = shift;

    my $cfg = $self->_config;
    my $key = $cfg->{keyword};
    return 1 if ref($tdoc) eq 'HASH' and exists $tdoc->{$key} and ref($tdoc->{$key});
    return 0;
}

sub normalize {
    my $self = shift;
    my $tdoc = shift;

    # we translate keys to their 'standard' names
    # if any translations are defined (to make the tests more
    # readable)
$DB::single=1;
    my $cfg = $self->_config;
    my $key = $cfg->{keyword};
    my $trans = $cfg->{translate};

    if (defined $trans and ref($trans) eq 'HASH') {
        foreach my $tk (keys %$trans) {
            foreach my $item (@{$tdoc->{$key}}) {
                if (exists $item->{$tk}) {
                    $item->{$trans->{$tk}} = delete $item->{$tk};
                }
            }
        }
    }

    return $tdoc;
}

sub count_tests {
    my $self = shift;
    my $tdoc = shift;

    my $cfg = $self->_config;
    my $key = $cfg->{keyword};
    my $dns = $cfg->{datanames};

    my $count = 0;

    foreach my $gn (keys %$dns) {
        my $dn = $dns->{$gn};
        foreach my $item (@{$tdoc->{$key}}) {
            if (exists $item->{$gn} and exists $item->{$dn}) {
                my $data = $item->{$dn};
                if (ref($data) eq 'ARRAY') {
                    $count += scalar @$data;
                } elsif (ref($data) eq 'HASH') {
                    $count += scalar keys %$data;
                } else {
                    diag "unexpected structure ".ref($data)." at $key/$dn";
                }
                # add a test for checking the allow-extra-keys
                $count++;
            }
        }
    }

    return $count;
}

sub make_tests {
    my $self = shift;
    my $tdoc = shift;

    my @tests;

    my $cfg = $self->_config;
    my $key = $cfg->{keyword};
    my $dns = $cfg->{datanames};

    foreach my $itemnum (0 .. @{$tdoc->{$key}}) {

        my $item = $tdoc->{$key}[$itemnum];

        foreach my $gn (keys %$dns) {

            next unless exists $item->{$gn};

            my $dn = $dns->{$gn};

            # we build one sub for each generator in the test item
            # which will run all the tests on the data produced by that generator

            my $test_code = sub {
                my $fixt = shift;
                my $tdoc = shift;

                # need to do this in the closure otherwise we
                # capture the original test doc fragment from the
                # test-building environment, which may not be the
                # same by now
                my $item = $tdoc->{$key}[$itemnum];

                # generate the structured data we need to test
                my $data = $self->generate_data( $item, $gn );

                my $extra = 0;
                my @extra;

                my $spec = $item->{$dn};

                if (ref($spec) ne ref($data)) {
                    die "unexpected structure mismatch: found ".ref($data)." where test spec expects ".ref($spec);
                }

                my @given;
                my @wants;
                my $mode;

                if (ref($data) eq 'ARRAY') {
                    @given = sort @$data;
                    @wants = sort @$spec;
                    $mode = 'list';
                } elsif (ref($data) eq 'HASH') {
                    @given = sort keys %$data;
                    @wants = sort keys %$spec;
                    $mode = 'hash';
                }

                my $w = shift @wants;
                my $g = shift @given;
                while (defined $w and defined $g) {
                    if ($w eq $g) {
                        my $same_val = $mode eq 'list' ? 1 : ($data->{$w} eq $spec->{$w});
                        ok($same_val, "found $w in $mode for $item->{$gn}");
                        if ($mode eq 'hash' and not $same_val) {
                            diag("key $w exists with different value: found '$data->{$w}' expected '$spec->{$w}'");
                        }
                        $w = shift @wants;
                        $g = shift @given;
                    } elsif ($w lt $g) {
                        if ($mode eq 'hash' and $spec->{$w} eq $cfg->{default}) {
                            ok(1, "found default value for $w in hash for $item->{$gn}");
                        } else {
                            ok(0, "found $w in $mode for $item->{$gn}");
                        }
                        $w = shift @wants;
                    } elsif ($w gt $g) {
                        $extra++;
                        push @extra, $g;
                        $g = shift @given;
                    }
                }

                my $allow_extra = exists $item->{'allow-extra-keys'} ? ($item->{'allow-extra-keys'} =~ /^[yt1]/i) : 1;
                my $text = $mode eq 'hash' ? 'keys' : 'elements';
                ok( $allow_extra ? 1 : !$extra, "validating extra $text for $item->{$gn}");
                if ($extra and not $allow_extra) {
                    diag("extra keys are: @extra");
                }

            };

            push @tests, $test_code;

        }
    }

    return @tests;
}

sub generate_data {
    my $self = shift;
    my $item = shift;
    my $gn   = shift;

    my $cfg = $self->_config;
    my $gen = $cfg->{generators}{$gn};

    if (ref($gen) eq 'CODE') {
        # run code to generate data
        return $gen->($self, $item, $gn);
    } elsif (not ref($gen)) {
        # plain string, commandline with $_ placeholder (optional)
        # usually modules will override this to implement
        # appropriate parsing of command output
        foreach ($item->{$gn}) { # to instantiate $_
            return [ eval "qx{$gen}" ];
        }
    }

    die "unhandled generator '$gn'";
}

1;
__END__

=head1 NAME

Test::Generated::StructuredData - base generator module for Test::Generated to handle structured data comparison

=head1 SYNOPSIS

  package Test::Generated::example;
  use Test::Generated::StructuredData (
    keyword    => 'example',
    generators => { foo => \&foo_generator },
    datanames  => { foo => 'data' },
    translate  => { 'allow-more-foo' => 'allow-extra-keys' },
  );

  ---
  - example:
    - foo: bar
      data:
        one: 1
        two: 2

=head1 DESCRIPTION

This module generates tests for Test::Generated where the tests are
comparisons between structured data: lists and hashes by default.

The test specifications define some aspects of the expecetd data structure, but
it is expected that subclasses will define how to construct the test data to
be compared with the specification.

Subclasses are defined just by C<use> of this module (no need for C<use base>)
and passing configuration data into the import list. The synopsis above lists all
available options, which are documented below.

=head1 CONFIGURATION

=over 4

=item B<keyword>

Required. Defines the keyword which will indicate a test document is a candidate for
tests generated by this module.

=item B<generators>

Optional. Specifies a mapping of data names to either a code reference or a command string
which will generate the test data. The test document and the generator name will be passed
to a code reference. For command strings, C<$_> will be replaced by the generator name.

In the example above, C<foo> is the generator name (and will have value C<bar>) to generate the test data,
and C<data> is the data name specifying the expected structure.

=item B<datanames>

Optional. Specifies a mapping from generator name to data name, so that test documents can be
made readable by using appropriate names for data.

=item B<translate>

Optional. Specifies a key translation so that option settings can have readable meaningful names rather than
the built-in defaults.

=head1 OPTIONS

=over 4

=item B<allow-extra-keys>

Optional (default: true). Defines whether additional entries in the test result data structure should be
treated as an error or not.

=head1 METHODS

=over 4

=item B<generate_data>

This method is called to construct the test data to be compared with the test specification. It is passed
the test fixture, the test document and the generator name.

The default implementation uses the C<generators> configuration setting to define the method to call
or the command string to execute, but subclasses are free to override if that makes more sense.

=head1 AUTHOR

David Lillie

=head1 BUGS

=head1 COPYRIGHT

=cut
