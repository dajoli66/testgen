package My::Generated::dummy;
use strict;
use warnings;

use Test::More;

use Test::Generated::StructuredData (
        keyword    => 'dummy',
        generators  => { foo => \&frob, oof => \&frob },
        datanames  => { foo => 'data', oof => 'data' },
    );


sub frob {
    my $self = shift;
    my $item = shift;
    my $gn   = shift;

    diag("frob: gn is $gn");
    return $gn eq 'foo'
        ?  [ qw/ one two three four/ ]
        : { one => 1, two => 2, three => 3, four => 4 }
        ;
}

1;

