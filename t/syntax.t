use lib "./t";
use ExtUtils::TBone;
use strict;

use Geo::Storm_Tracker;

#Create checker
my $T=ExtUtils::TBone->typical();
$T->begin(1);

print "hi there john\n";
$T->msg('hi there jimmy');
$T->ok('hi there john');

#End testing
$T->end();
