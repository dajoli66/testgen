package Test::Generated::Manifest;
use strict;
use warnings;

use Test::More;
use YAML::XS;
use Sub::Name;
use Perl6::Slurp;
use File::stat;
use IO::Dir;
use POSIX qw(S_ISREG S_ISDIR);

sub can_handle {
  my $class = shift;
  my $tdoc  = shift;

  return 1 if ref($tdoc) eq 'HASH' and exists $tdoc->{manifest} and ref($tdoc->{manifest}) eq 'ARRAY';
  return 1 if ref($tdoc) eq 'HASH' and exists $tdoc->{cmpdirs}  and ref($tdoc->{cmpdirs})  eq 'ARRAY';
  return 0;
}

sub normalize { return $_[1] }

sub count_tests {
  my $class = shift;
  my $tdoc  = shift;

  my $test_count = 0;
  # TODO allow for multiple tests per item (e.g. separate owner/mode tests)
  $test_count += scalar @{$tdoc->{manifest}} if exists $tdoc->{manifest};
  $test_count++ if exists $tdoc->{cmpdirs};

  return $test_count;
}

sub filetypes { qw(dir file link none) }

sub make_tests {
  my $class = shift;
  my $tdoc  = shift;

  my @tests;

  if (exists $tdoc->{manifest}) {

    if ($ENV{TEST_GEN_DEBUG}) {
      print "defining new manifest test:\n";
      print "  ...\n";
    }

    my $test_code = sub {
      my $fixt = shift;
      my $tdoc = shift;

      my $base = $tdoc->{basedir} || '';
      $base .= '/' if $base and $base !~ m{/$};

      my $filetype_re = '^(?:' . join('|', $class->filetypes) . ')$';

      foreach my $item (@{$tdoc->{manifest}}) {

        # get the path and (expected) type
        my $type;
        my $path;
        foreach my $key ($class->filetypes()) {
          next unless exists $item->{$key};
          return "unexpected path type '$key' when '$type' seen already at '$path'"
            if defined $type;
          $type = $key;
          $path = $item->{$key};
        }

        return "missing path type in manifest"
          unless defined $type and defined $path;

        # relative paths start from $base
        $path = $base . $path unless $path =~ m{^/};

        # let's take a look...
        my $stat = lstat($path);

        if ($type eq 'none') {

          # just check the path doesn't exist
          ok( not(defined $stat), "nothing at path '$path'" );

        } else {

          # we avoid using any Test::More routines just yet
          # so we can keep to one test per item... XXX

          my $good = 1;

          # if we have a link we can check the target
          if ($type eq 'link' and -l _ and defined $item->{target}) {
            $stat = stat($path); # NB stat not lstat
            # test type of link target if specified
            if ($item->{type}) {
              $good = 0 unless $class->check_type( $item->{type}, $item->{target}, $stat );
            }
          }

          # type is not a key into the test doc, its value is
          # hence we need to process this separately
          # NB link type was tested above
          $good = 0 unless $type eq 'link' or $class->check_type( $type, $path, $stat );

          foreach my $key (keys %$item) {
            # skip known keys
            next if $key =~ m{$filetype_re};

            my $check = $class->can("check_$key");
            next unless defined $check;

            $good = 0 unless $class->$check( $item->{$key}, $path, $stat );

            last unless $good;
          }

          ok( $good,
              "${type} as expected at '$path'" );
        }
      }

    };

    push @tests, $test_code;
  }

  if (exists $tdoc->{cmpdirs}) {

    if ($ENV{TEST_GEN_DEBUG}) {
      print "defining new cmpdirs test:\n";
      print "  ...\n";
    }

    my $test_code = sub {
      my $fixt = shift;
      my $tdoc = shift;

      my $base = $tdoc->{basedir} || '';
      $base .= '/' if $base and $base !~ m{/$};

      my %opts;
      $opts{$_} = exists $tdoc->{$_}
        foreach qw(allow_deletes allow_extra check_owner check_group check_mode);

      my @dirs = @{$tdoc->{cmpdirs}};
      if (2 != scalar @dirs) {
        ok( 0, "expected two directories to compare");
        return;
      }

      ok( dircmp( \%opts, "${base}$dirs[0]", "${base}$dirs[1]" ),
          "directories '$dirs[0]' and '$dirs[1]' compare ok" );
    };

    push @tests, $test_code;
  }

  return @tests;
}

# helpers...

sub check_type {
  my $class = shift;
  my ($type, $path, $stat) = @_;
  # NB symlink handling is inline above
  return 0 if $type ne 'none' and not defined $stat;
  return 0 if $type eq 'file' and not S_ISREG($stat->mode);
  return 0 if $type eq 'dir'  and not S_ISDIR($stat->mode);
  return 1;
}

sub check_owner {
  my $class = shift;
  my ($uid, $path, $stat) = @_;
  $uid = getpwnam($uid) if $uid =~ /\D/;
  return 0 if $uid != $stat->uid;
  return 1;
}

sub check_group {
  my $class = shift;
  my ($gid, $path, $stat) = @_;
  $gid = getgrnam($gid) if $gid =~ /\D/;
  return 0 if $gid != $stat->gid;
  return 1;
}

sub check_mode {
  my $class = shift;
  my ($mode, $path, $stat) = @_;
  return 0 unless mode_good($stat->mode, $mode);
  return 1;
}

sub mode_good {
  my $mode = shift;
  my $spec = shift;

  my $good = 1;

  $mode &= 07777; # permissions and setid bits only

  foreach my $part (split /,/, $spec) {

    my $mask = 0;
    my $op;

    if ($part =~ /^\s*([+-])?(0[0-7]{3,6})\s*$/) {

      $op = $1 || '=';
      $mask = oct($2);

    } elsif ($part =~ /^\s*([ugo]+)([=+-])([rwxst]+)\s*$/) {

      $op = $2;
      my $offs = $1;
      my $bits = $3;

      my $nbits = 0;
      $nbits |= 0x01 if $bits =~ /x/;
      $nbits |= 0x02 if $bits =~ /w/;
      $nbits |= 0x04 if $bits =~ /r/;

      $mask |= ($nbits << 0) if $offs =~ /o/;
      $mask |= ($nbits << 3) if $offs =~ /g/;
      $mask |= ($nbits << 6) if $offs =~ /u/;

      $mask |= 04000 if ($bits =~ /s/ and $offs =~ /u/);
      $mask |= 02000 if ($bits =~ /s/ and $offs =~ /g/);
      $mask |= 01000 if ($bits =~ /t/);

    }

    if ($op eq '=') {
      $good = 0 unless ($mode == $mask);
    } elsif ($op eq '+') {
      $good = 0 unless (($mode & $mask) == $mask);
    } elsif ($op eq '-') {
      $good = 0 unless (!($mode & $mask));
    } else {
      $good = 0;
    }

    last unless $good;
  }

  return $good;
}


sub dircmp {
  my ($opts, $dir1, $dir2) = @_;

  my $d1 = IO::Dir->new($dir1);
  unless (defined $d1) {diag "failed to open directory '$dir1' for comparison\n"; return 0; };
  my @dents1 = grep !/^\.\.?$/, sort $d1->read;
  $d1->close;

  my $d2 = IO::Dir->new($dir2);
  unless (defined $d2) {diag "failed to open directory '$dir2' for comparison\n"; return 0; };
  my @dents2 = grep !/^\.\.?$/, sort $d2->read;
  $d2->close;

  my $ent1 = shift @dents1;
  my $ent2 = shift @dents2;

  while ($ent1 or $ent2) {

    if ($ent1 lt $ent2) {
      if ($opts->{allow_deletes}) {
        $ent1 = shift @dents1;
        next;
      } else {
        diag("no entry '$ent1' found in '$dir2'");
        return 0;
      }
    }

    if ($ent1 gt $ent2) {
      if ($opts->{allow_extra}) {
        $ent2 = shift @dents2;
        next;
      } else {
        diag("new entry '$ent2' found in '$dir2'");
        return 0;
      }
    }

    # same name ...
    my $st1 = lstat "${dir1}/${ent1}";
    my $st2 = lstat "${dir2}/${ent2}";

    # check type
    if (($st1->mode & 0170000) != ($st2->mode & 0170000)) {
      diag("entries at '${dir1}/${ent1}' and '${dir2}/${ent2}' have different types");
      return 0;
    }

    # maybe check mode, including setid/sticky bits
    if ($opts->{check_mode} and ($st1->mode & 07777) != ($st2->mode & 07777)) {
      diag("entries at '${dir1}/${ent1}' and '${dir2}/${ent2}' have different permission modes");
      return 0;
    }

    # maybe check owner
    if ($opts->{check_owner} and ($st1->uid != $st2->uid)) {
      diag("entries at '${dir1}/${ent1}' and '${dir2}/${ent2}' have different owners");
      return 0;
    }

    # maybe check group
    if ($opts->{check_group} and ($st1->gid != $st2->gid)) {
      diag("entries at '${dir1}/${ent1}' and '${dir2}/${ent2}' have different groups");
      return 0;
    }

    # recurse if necessary
    if (S_ISDIR($st1->mode) and S_ISDIR($st2->mode)) {
      return 0 unless dircmp($opts, "${dir1}/${ent1}", "${dir2}/${ent2}");
    }

    # ok, move on to next entries
    $ent1 = shift @dents1;
    $ent2 = shift @dents2;
  }

  # if we got here there were no (interesting) differences
  return 1;
}

1;
__END__

=head1 NAME

Test::Generated::Manifest - generator module for Test::Generated to handle filesystem manifests

=head1 SYNOPSIS

  ---
  - manifest:
     - dir: /var/tmp
     - file: /var/run/proc.pid
       owner: root
       group: root
       mode: u+rw,go-rwx
     - link: /tmp/sl
       target: /var/tmp/foo
  - cmpdirs:
     - /my/sub/dir/one
     - /my/sub/dir/two
    allow_deletes: 1
    allow_extra: 1

=head1 DESCRIPTION

This module generates tests for Test::Generated where a filesystem manifest
needs to be validated.

Two types of test item are supported: C<manifest> describes a sequence of
filesystem entries which are checked in turn; C<cmpdirs> compares two
directory structures as a single test.


=head1 OPTIONS for C<manifest>

=over 4

=item B<basedir>

Optional. Defines the base directory for the manifest, all paths will be taken relative
to this directory if specified.

=head1 OPTIONS for C<manifest> entries

=over 4

=item B<file>|B<dir>|B<link>|B<none>

Required. Specifies what kind of entry the path should resolve to: regular file,
directory, symbolic link or the special value C<none> meaning the path should not exist.

=item B<type>

Optional. Defines the type of the entry (file, dir, link, none) for C<link> entries,
to test the type of thee link target.

=item B<target>

Optional. Defines the symbolic link target expected, for C<link> entries.

=item B<owner>

Optional. Defines the expected owner of the entry.

=item B<group>

Optional. Defines the expected group of the entry.

=item B<mode>

Optional. Defines the expected mode, i.e. permission bits, of the entry.
Either numeric (octal) or symbolic values can be used, and multiple fragments can
be specified separated by commas. Three comparison operators are available,
as with the C<chmod> command using symbolic permissions: '=' tests for exact
equality (and is the default for numeric modes); '+' tests for the specified bits
to be set; and '-' tests for the specified bits to be unset.

=head1 OPTIONS for C<cmpdirs>

Two directories, DIR1 and DIR2, are expected as a sequence under the C<cmpdirs> key. Additional options
are available to tune the comparison:

=over 4

=item B<allow_deletes>

Optional. If set true, entries are allowed to be missing from DIR2.

=item B<allow_extra>

Optional. If set true, additional entries are allowed in DIR2.

=item B<check_owner>

Optional. If set true, matching entries are tested for same owner.

=item B<check_group>

Optional. If set true, matching entries are tested for same group.

=item B<check_mode>

Optional. If set true, matching entries are checked for same mode.

=head1 AUTHOR

David Lillie

=head1 BUGS

=head1 COPYRIGHT

=cut
