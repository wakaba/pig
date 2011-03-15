use strict;
use warnings;
use lib qw[../lib lib];
use Pig::CLI;

my %args;
my $configfile = shift;
$args{configfile} = $configfile if $configfile;

Pig::CLI->new(%args)->run;
