package Geo::Storm_Tracker;

use strict; 
use Geo::Storm_Tracker::Main;
use Geo::Storm_Tracker::Data;
use Geo::Storm_Tracker::Advisory;
use Geo::Storm_Tracker::Parser;
use vars qw($VERSION);
 
$VERSION = 0.01;
 
#------------------------------
1;
__END__

=head1 NAME

Geo::Storm_Tracker - Perl bundle for working with national weather advisories

=cut

=head1 SYNOPSIS

See documentation of each module of the bundle.  This currently includes the
following:

	Geo::Storm_Tracker::Main
	Geo::Storm_Tracker::Data
	Geo::Storm_Tracker::Advisory
	Geo::Storm_Tracker::Parser

=cut


=head1 DESCRIPTION

The Storm-Tracker perl bundle is designed to track weather events
using the national weather advisories.  The original intent is to track
tropical depressions, storms and hurricanes.

=cut


=head1 AUTHOR

James Lee Carpenter, Jimmy.Carpenter@chron.com
 
All rights reserved.  This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.
 
Thanks to Dr. Paul Ruscher for his assistance in helping me to understand
the weather advisory formats.

=cut


=head1 SEE ALSO


	Geo::Storm_Tracker::Advisory
	Geo::Storm_Tracker::Parser
	Geo::Storm_Tracker::Main
	Geo::Storm_Tracker::Data
	perl(1).

=cut 
