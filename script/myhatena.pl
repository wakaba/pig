use strict;
use warnings;
use Pig;
use Pig::Service::MyHatena;

my $pig = Pig->new(
    service => Pig::Service::MyHatena->new( 
        interval => 300,  # 5分毎にチェック
    ),
    config => { port => 16667 },
);
$pig->run;

