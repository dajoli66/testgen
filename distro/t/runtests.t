#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;

use Test::Class;
use Test::Harness;
use Getopt::Long;

BEGIN { @ARGV = ( $FindBin::Bin  ) unless @ARGV; }

sub findfiles {
  my @candidates = @_;
  my @files = ();
  foreach my $fn (sort @candidates) {
    if (-d $fn) {
      push @files, findfiles(<$fn/*>);
    } elsif (-r _) {
      push @files, $fn if $fn =~ /\.pm$/;
    }
  }
  return @files;
}


BEGIN {
  my @testfiles = findfiles(@ARGV);
  $::FAIL = 0;

  $DB::single = 1;

  foreach my $test (@testfiles) {
    eval "require '$test';";
    if ($@) {
      warn $@;
      $::FAIL = 1;
    }
  }
}

END {
  $DB::single = 1;
  Test::Class->BAILOUT( "Test error in require" ) if $::FAIL;
  Test::Class->runtests
    unless Test::Class->builder->current_test > 1;
}

1;
