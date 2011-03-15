package Test::ClientServer;
use strict;
use warnings;

use base 'Test::Class';
use Test::Client;
use Test::Server;

use Carp qw(carp croak);
use Test::More;
use File::stat;
use Cwd;

#
# base class for testing client-server interaction
#
# limitations:
#   no control over server process state
#   server processes and client commands all run with same EUID
#   no Rev qserver for now
#

# don't test this abstract base class
Test::ClientServer->SKIP_CLASS( 1 );

# settings ... XXX maybe Moose could clean this up?

# default settings...
sub factory_config {
  {
    path    => [],
    servers => {},
    timeout => 30,
  }
}

# class-specific attributes; inside-out
my %client;
my %servers;
my %timeout;

# getters...
sub _ref { my $proto = $_[1] || $_[0]; $proto = ref $proto if ref $proto; return $proto; }
sub get_client  { $client { _ref(@_) } }
sub get_servers { $servers{ _ref(@_) } }
sub get_timeout { $timeout{ _ref(@_) } }


#
# startup/shutdown
#
# set up paths for client and servers
# start server processes / shutdown server processes
#
# testing failure scenarios will need to override the startup
#

sub _startup_clientserver : Test(startup => 1) {
  my $fixt = shift;

  my $config = $fixt->factory_config;
  my $class  = ref $fixt;

  $DB::single = 1;

  # set up our client
  $client{$class} = Test::Client->new( @{$config->{path}} );

  # a default timeout for client commands
  $timeout{$class} = $config->{timeout};

  # set server processes
  $servers{$class} ||= {};
  foreach my $serv (keys %{$config->{servers}}) {
    my $defn     = $config->{servers}{$serv};
    my $serv_pkg = $defn->{class} || 'Test::Server';
    my $launcher = $defn->{launcher} || '';
    my $cmd      = $defn->{cmd} || '';
    next unless $cmd;
    my $test_server = $serv_pkg->new( launcher => $launcher, cmd => $cmd );
    $servers{$class}{$serv} = $test_server;
  }

  # start 'em up
  $_->startup foreach values %{$servers{$class}};

  $_->wait_for_ready foreach values %{$servers{$class}};

  # initial check
  $fixt->check_servers;
}

sub _shutdown_client : Test(shutdown) {
  my $fixt = shift;
  $_->shutdown foreach values %{$fixt->get_servers};
}

##
## setup/teardown: these run either side of each test method
##

#
# check server processes are running before and after each test
#

# HACK Alert
sub _exception_failure {
  my ($self, $method, $exception, $tests) = @_;
  croak $exception;
}

sub check_servers {
  my $fixt = shift;
  my $ok = 1;
  my $servers = $fixt->get_servers;
  foreach my $serv (keys %{$servers}) {
     my $test_server = $servers->{$serv};
     unless ($test_server and $test_server->is_running) {
      $ok = 0;
      warn "check_servers: found no $serv process\n";
      $test_server->shutdown if $test_server;
      server_stderr($serv => $test_server); # show any redirected stderr
      delete $servers->{$serv}; # only once through
    }
  }
  ok($ok, "check_servers");
  unless ($ok) {
    no warnings;
    *Test::Class::_exception_failure = \&_exception_failure; # XXX
    die "not all processes running\n";
  }
}

sub server_stderr {
  my $name = shift;
  my $serv = shift;
}

sub _tdown_999_check_servers : Test(teardown => 1) { shift->check_servers; }

#
# make a timeout for each client command
#    overrides can be done by running alarm() within specific tests
#    NB alarm(0) is not recommended in case of hangs!

sub alarm_handler {
  die "test method TIMED OUT\n";
}

sub _setup_999_timeout : Test(setup) {
  my $fixt = shift;
  return unless $fixt->get_timeout;
  $SIG{ALRM} = \&alarm_handler;
  alarm($fixt->get_timeout);
}

sub _tdown_000_timeout : Test(teardown) {
  alarm(0);
  $SIG{ALRM} = sub {};
}


1;
__END__

=head1 NAME

Test::ClientServer - unit testing of client-server systems

=head1 SYNOPSIS

  package Foo::Test::ClientServer;
  use base 'Test::ClientServer';
  sub factory_config {
      return {
          path => [ qw/ bin sbin / ],
          timeout => 60,
          servers => {
              mydaemon => { class => __PACKAGE__, launcher => 'sudo', cmd => 'mydaemon' },
          },
      };
  }

  package Foo::Tests;
  use base 'Foo::Test::ClientServer';
  use Test::More;
  sub my_test : Test(5) {
      my $fixture = shift;
      my $testclient = Foo::Test::ClientServer->get_client( $fixture );
      # NB run_ok is 3 tests
      $testclient->run_ok(q{client command -with-parameters});
      is( $testclient->stderr, '', 'basic client command has no error' );
      like( $testclient->stdout, qr{expected output}, 'found the anticipated message' );
  }

=head1 DESCRIPTION

This module combines Test::Client and Test::Server to provide a simple way of
running tests of client-server systems.

For each particular system configuration, a subclass should be created which
implements a C<factory_config> method which will return a configuration hash
with data defining constructor parameters for a single Test::Client object
and one or more Test::Server objects.

(This data is returned by a method because it is needed during a CHECK block
in Test::Class when defining the tests, but may itself need data not available
in a BEGIN block.)

Accessors are defined for the constructed objects, which are available as methods
of the fixture object passed in to each test method. The Test::* objects are shared
between all tests in the same test class.

Startup and shutdown methods are defined which will create the configured objects
and startup the defined Test::Server objects, and at shutdown will in turn shutdown
the Test::Server daemons.

After startup and subsequently after each test method, the C<check_servers> method
is called (as a teardown method) to verify that all the server daemons are still
running.

If a timeout is configured, it is applied to each test method (via setup/teardown methods)
to help avoid client hangs blocking tests. The default timeout is 30 seconds. A timeout
of zero will disable the alarm processing.


=head2 Methods

=over 4

=item B<factory_config>

Should be overridden in a subclass. Returns a configuration hash defining parameters
to be passed to Test::Client and Test::Server constructors.

Timeout configuration:
  timeout => 30, # timeout in seconds

Client configuration (see Test::Client):
  path => [ qw/ bin sbin / ], # list of directories to prepend to PATH

Server configuration (see Test::Server):
  servers => {
      mykey => { cmd      => 'mydaemon -with -parameters',
                 launcher => 'sudo',
                 class    => 'Foo::Test::Server',
               },
  }

Note that Test::Server subclasses can be specified via the C<class> parameter in a
server configuration. The keys to the servers hash will be used in messages to indicate
which Test::Server object is involved.

=item B<check_servers>

The method used to confirm all server processes are still running. Can be overridden if
tests other than process ID are preferred.

The default implementation checks the process IDs still exist, and attempts to report
the standard error of any processes not found. See C<server_stderr>.

=item B<server_stderr>

This method is used by C<check_servers> to report the stderr of any failed server
processes. The default implementation does nothing.

Subclasses should override this as appropriate, e.g. when stderr is redirected to
a log file.

=head1 AUTHOR

David Lillie

=head1 BUGS

=head1 COPYRIGHT

=cut

