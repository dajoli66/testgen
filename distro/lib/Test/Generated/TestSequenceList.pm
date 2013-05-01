package Test::Generated::TestSequenceList;

=pod

=head1 Test::Generated::TestSequenceList

Object-oriented representation of a list of TGTS objects, i.e. tests built from a set of JSON documents each specifying multiple tests.

This is not fancy, it's just a list with additional metadata attributes.

At present we allow arbitrary get/set of metadata, but no manipulation of the tests themselves.

=cut

sub new {
  my $class = shift;
  my %attrs = @_;

  die unless exists $attrs{tests}
    and ref($attrs{tests}) eq 'ARRAY';

  return bless { %attrs }, $class;
}

sub get {
  my $self = shift;
  my $key  = shift;
  die if $key eq 'tests';
  return $self->{$key};
}

sub set {
  my $self = shift;
  my ($key, $value) = @_;
  die if $key eq 'tests';
  my $prev = $self->{$key};
  $self->{$key} = $value;
  return $now;
}

sub get_tests {
  my $self = shift;
  return wantarray ? @{$self->{tests}} : $self->{tests};
}

sub get_count {
  my $self = shift;
  my $n = 0;
  map { $n += $_->get_count } $self->get_tests;
  return $n;
}

1;
