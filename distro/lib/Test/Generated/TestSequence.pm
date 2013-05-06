package Test::Generated::TestSequence;

=pod

=head1 Test::Generated::TestSequence

Object-oriented representation of a single JSON test fragment.

NB The fragment may specify multiple tests.

=cut

sub new {
  my $class = shift;
  my %attrs = @_;

  return bless { %attrs }, $class;
}

sub get_document {
  my $self = shift;
  return $self->{document};
}

sub get_count {
  my $self = shift;
  return $self->{count};
}

sub get_tests {
  my $self = shift;
  return wantarry ? @{$self->{tests}} : $self->{tests};
}

sub get_name {
  my $self = shift;
  return $self->{name};
}

1;
