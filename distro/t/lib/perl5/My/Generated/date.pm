package My::Generated::date;
use strict;
use warnings;

use Test::More;

use Test::Generated::StructuredData (
        keyword    => 'date',
        datanames  => { tstamp => 'when' },
    );


sub generate_data {
    my $self = shift;
    my $item = shift;
    my $gn   = shift;

    my $tstamp = $item->{$gn};

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($tstamp);

    return {
        sec  => $sec,
        min  => $min,
        hour => $hour,
        mday => $mday,
        mon  => $mon,
        year => $year,
        wday => $wday,
        yday => $yday,
    };
}

1;

