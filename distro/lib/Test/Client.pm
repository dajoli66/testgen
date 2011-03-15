package Test::Client;
use strict;
use warnings;

use base 'Test::Builder::Module';
use IPC::Open3;
use IO::Select;
use Symbol qw(gensym);
use Scalar::Util qw(looks_like_number);

#########
## OO interface for TCS
## automatically saves 'last' run data
#########

sub new {
  my $class = shift;
  my $self  = {path => [@_]};
  return bless $self, $class;
}

# for near-compatibility with Test::Command::Simple
sub run {
    my $ret = shift->run_cmd(@_) ? 1 : 0;
    shift if ref $_[0] eq 'HASH'; # drop option hash
    __PACKAGE__->builder->ok( $ret, "Can run '@_'" );
}

sub run_ok {
    my $self = shift;
    my $wanted_rc = 0;
    if (looks_like_number($_[0]) &&
        0 <= $_[0] && $_[0] <= 255 &&
        int($_[0]) == $_[0])
    {
        $wanted_rc = shift();
    }
    $self->run(@_);
    __PACKAGE__->builder->is_eq($self->rc, 0, "Process terminated without a signal");
    __PACKAGE__->builder->is_eq($self->exit_status, $wanted_rc, "Check return from '@_' is $wanted_rc");
}

# Accessors

sub rc          { shift->{rc} & 0xff }
sub stdout      { shift->{stdout}    }
sub stderr      { shift->{stderr}    }
sub exit_status { shift->rc >> 8     }

sub start_time  { shift->{stime}     }
sub end_time    { shift->{etime}     }

#
# This is a slightly modified form of Test::Command::Simple::run
#
# We need to be able to execute a command without calling
# *any* test funtionality; TCS insists on testing the 
# open3() call
#
# In its place we return a value indicating that success or
# failure. A return value of 0 means the open3() call failed,
# while a true value means the call succeeded.
#
# Additionally we provide start and end times for callers that
# want to measure performance.
#
sub run_cmd {
    my $self = shift;

    my $opts = @_ && ref $_[0] eq 'HASH' ? shift : {};

    my @cmd = @_;

    # initialise everything each run.
    $self->{rc} = -1;
    $self->{stdout} = '';
    $self->{stderr} = '';

    local $ENV{PATH} = join ':', @{$self->{path}}, $ENV{PATH};
    $self->{stime} = time;

    my $ret;

    my ($wtr, $rdr, $err) = map { gensym() } 1..3;
    my $pid = open3($wtr, $rdr, $err, @cmd) or do {
        return 0;
    };
    $ret = 1;

    my $s = IO::Select->new();

    if ($opts->{stdin})
    {
        print $wtr $opts->{stdin};
    }

    close $wtr;
    $s->add($rdr);
    $s->add($err);

    my %map = (
               fileno($rdr) => \($self->{stdout}),
               fileno($err) => \($self->{stderr}),
              );
    while ($s->count())
    {
        if (my @ready = $s->can_read())
        {
            for my $fh (@ready)
            {
                my $buffer;
                my $fileno = fileno($fh);
                my $read = sysread($fh, $buffer, 1024);
                if ($read && $map{$fileno})
                {
                    ${$map{$fileno}} .= $buffer;
                }
                else
                {
                    # done.
                    $s->remove($fh);
                    close $fh;
                }
            }
        }
        elsif (my @err = $s->has_exception())
        {
            warn "Exception on ", fileno($_) for @err;
        }
    }
    waitpid $pid, 0;
    $self->{rc} = $?;
    $self->{etime} = time;

    $ret;
}

1;
__END__

=head1 NAME

Test::Client - object interface to simple command execution

=head1 SYNOPSIS

  use Test::More;
  use Test::Client;
  my $tc = Test::Client->new( path => join(':', qw( bin sbin ) );
  $tc->run_ok('mycmd arg1 arg2');
  is($tc->stderr, '', 'no error output as expected');

=head1 DESCRIPTION

This module provides an object interface as a slight modification
of Test::Command::Simple.

The object constructor allows a custom PATH to be configured for all commands run
from that object.

As well as the exit code and standard output and error data, the elapsed time
of the command is recorded.

=head2 Methods

=over 4

=item B<new>

  my $tc = Test::Client->new( path => ... )

Constructs an object that will store data about a single command execution. The same
object can be reused but that will overwrite the data of previous command executions.

If the optional C<path> parameter is specified, the associated value will be prepended
to the C<PATH> environment variable before executing a command.

=item B<run_cmd>

  $tc->run_cmd( "mycmd with args" );

The command specified in the parameter string is executed, with C<PATH> adjusted if
requested, and the resulting data is stored in the C<$tc> object for later
retrieval.

The return value will be true if the given command was executed, or false if there
was a failure to execute. In case of failure, C<$@> will contain the error.

=item B<run>

  $tc->run( "mycmd with args" );

Replacement for Test::Command::Simple::run, it calls C<run_cmd> on its parameter
and tests its return value for success or failure to execute the given command.

=item B<run_ok>

  $tc->run_ok( "mycmd with args" );
  $tc->run_ok( $rc, "myothercmd" );

Replacement for Test::Command::Simple::run_ok, calls C<run_cmd> on its command parameter
and tests for: success of execution; no signal caused exit; and return code of zero.

If the first parameter is numeric, the return code of the command is compared with that
parameter instead of the default zero.

=item B<rc>

  is($tc->rc, 0, 'command had good exit code');

Returns the last run's full C<$?> for analysis.

=item B<stdout>

Returns the last run's standard output.

=item B<stderr>

Returns the last run's standard error.

=item B<exit_status>

Return's the exit status of the last run.

=item B<start_time>

Return's the time the last command run was started.

=item B<end_time>

Return's the time the last command run completed.

=head1 AUTHOR

David Lillie

=head1 BUGS

=head1 COPYRIGHT

=cut
