package Test::Server;
use strict;
use warnings;

use POSIX qw(:sys_wait_h);

use IPC::Open3;
use IO::Handle;
use IO::Select;


sub new {
  my $class = shift;
  my %param = @_;

  my $self = {
    tag      => $param{tag} || 'dummy',
    launcher => $param{launcher},
    cmd      => $param{cmd},
    args     => $param{args} || [],
  };

  return bless $self, $class;
}

sub _get_launcher {
  my $self = shift;
  my $launcher = '';
  if ($self->{launcher}) {
    $launcher = $self->{launcher};
    $launcher .= ' ' unless $launcher =~ /\s$/;
  }
  return $launcher;
}


sub startup {
  my $self = shift;

  my $launcher = $self->_get_launcher;
  my $cmdline = qq{${launcher}$self->{cmd} @{$self->{args}}};
  #warn "startup server: $cmdline\n";

  my $t0 = time;

  # Perl Cookbook 16.9, Example 16.2
  my ($in, $out, $err);
  $err = IO::Handle->new; # o/w shared with stdout!
  my $pid = open3($in, $out, $err, $cmdline);

  close($in);

  $self->{pid}    = $pid;
  $self->{stdout} = $out;
  $self->{stderr} = $err;
  $self->{stime}  = $t0;

  return $self;
}

sub shutdown {
  my $self = shift;

  #my $count = kill 3 => $self->{pid};

  my $launcher = $self->_get_launcher;
  my $cmdline  = qq{${launcher}/bin/kill -3 $self->{pid} 2>/dev/null};
  #warn "shutdown server: $cmdline\n";
  my $rc = system($cmdline);

  # drain I/O
  my $selector = IO::Select->new;
  $selector->add( $self->{stdout}, $self->{stderr} );

  while (my @ready = $selector->can_read) {
    foreach my $fh (@ready) {
      my $line = $fh->getline;
      if ($fh->fileno == $self->{stdout}->fileno) {
        #LOG(MSLogInfo, "%s", $line) if $line;
        print STDOUT $line if $line;
      } else {
        #LOG(MSLogErr,  "%s", $line) if $line;
        print STDERR $line if $line;
      }
      $selector->remove($fh) if eof($fh);
    }
  }

  close($self->{stdout}) if $self->{stdout};
  close($self->{stderr}) if $self->{stderr};

  $self->{etime} = time;

  return $self;
}

sub is_running {
  my $self = shift;
  return 0 unless defined $self->{pid};
  # check for zombie if nobody handled SIGCHLD
  waitpid($self->{pid}, WNOHANG);
  #return kill 0 => $self->{pid};
  # need to allow for servr processes running as other users...

  my $launcher = '';
  if ($self->{launcher}) {
    $launcher = $self->{launcher} . ' ';
  }
  my $rc = system(qq{${launcher}/bin/kill -0 $self->{pid} 2>/dev/null});
  if (($rc & 0x00ff) == 0) {
    return 1;
  } else {
    return 0;
  }
}

sub wait_for_ready {
  my $self = shift;

  # place holder in case some servers have lengthy startup
}

1;
__END__

=head1 NAME

Test::Server - simple asynchronous command execution

=head1 SYNOPSIS

  use Test::More;
  use Test::Server;
  my $ts = Test::Server->new( cmd => 'mydaemon params' );
  $ts->startup;
  $ts->wait_for_ready;
  ...
  # run client commands against daemon service
  ...
  $ts->shutdown;

=head1 DESCRIPTION

This module provides an object interface for running daemon processes asynchronously,
primarily for testing client-server interaction.

The object constructor allows a custom C<launcher> to be configured for the daemon
in question, for example to use C<sudo> where the commands needs to run as a specific
entitled ID, or C<ssh> where a remote process is required.

It is expected that the process will produce little or no output. Any stdio is buffered
until shutdown, so the process may block if too much output is produced.

=head2 Methods

=over 4

=item B<new>

  my $ts = Test::Server->new( launcher => ..., cmd => ..., tag => ..., args => ... )

Constructs an object to execute the daemon process. Only the C<cmd> parameter
is required.

=item B<startup>

  $ts->startup;

The command specified in the C<cmd> parameter string is executed, with C<launcher> prepended if
specified, and C<args> appended.

IPC::Open3 is used to execute the command.

=item B<shutdown>

  $ts->shutdown;

The daemon is shutdown. The default behaviour is to send a C<SIGQUIT>. The kill
command will use the same C<launcher> as the original daemon process.

After shutdown, the stdout and stderr filehandles will be drained and any content
recorded in the object C<stdout> and C<stderr> attributes respectively.

=item B<is_running>

  print "The daemon is " . ($ts->is_running ? "" : "not") . " running\n";

Check whether the daemon process is running or not. This will poll for pending
C<SIGCHLD> signals before attempting C<kill -0> on the daemon process id.
Again this will be run with the same C<launcher> as the original daemon process.

The method will return C<1> if the process is running, C<0> if not.

=item B<wait_for_ready>

  $ts->wait_for_ready;

This method should be called after C<$ts->startup> to allow a custom test for the
process being ready for use. This is to cater for daemons with a non-trivial delay
between execution and readiness. It is separate from the C<startup> method to allow
for parallel startup of multiple daemons.

The default implementation does nothing, it is intended for override in subclasses
where appropriate.

=head1 AUTHOR

David Lillie

=head1 BUGS

=head1 COPYRIGHT

=cut
