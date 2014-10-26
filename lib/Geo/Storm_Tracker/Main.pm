package Geo::Storm_Tracker::Main;

use Carp;
use File::Path;
use Time::Local;
use Geo::Storm_Tracker::Data;
use strict;
use vars qw($VERSION);

$VERSION = '0.01';

#---------------------------------------------------------
sub new {
	my $self=shift;
	my $base_path=shift;

	my ($msg)=undef;
	my $HR={};

	#Check to see if the base path was given
        unless (( defined($base_path) ) and (-e $base_path)){
                $msg = "The mandatory base path argument was not provided to the new method!";
                carp $msg,"\n";
                return (undef,$msg);
        }#unless

	#Insure that the base path has a trailing slash.
	$base_path =~ s!/*$!/!;

	$HR->{'base_path'}=$base_path;

	bless $HR,'Geo::Storm_Tracker::Main';
	return ($HR,undef);
}#new
#---------------------------------------------------------
sub add_advisory {
	my $self=shift;
	my $adv_obj=shift;
	my $force=shift;
	my $counter=shift;

	my ($header_frag,$region_code,$last_digits,$good)=undef;
	my ($data_obj_found,$recent_storms_AR,$recent_frags_AR)=undef;
	my ($paths_HR,$success,$error,$year,$msg,$new_path,$root_paths,$new_data_obj)=undef;

	($header_frag,$region_code,$last_digits)=$self->_disect_header($adv_obj);

	($good,$error)=$self->_check_region_syntax($region_code);

	unless ($good){
		return (undef,$error);
	}

	($paths_HR,$error)=$self->_all_paths_by_region($region_code);

	#Directory does not exist so create one.
	if ( (!defined $paths_HR) and ( !$self->_region_dir_exists($region_code) ) ){
		($good,$error)=$self->_create_region_dir($region_code);
		unless ((defined $good) and ($good)){
                        return (undef,$error);
                }#unless
	}#if


	if (defined $paths_HR){

		($recent_storms_AR,$recent_frags_AR)=$self->_recent_storms($paths_HR->{$region_code});

		$data_obj_found=$self->_associate_advisory_with_storm($adv_obj,$recent_storms_AR,$recent_frags_AR);

	}#if

	if ((defined $paths_HR) and (defined $data_obj_found)){
		($success,$error)=$data_obj_found->insert_advisory($adv_obj,$force);
		return ($success,$error);
	}
	else {
		$year=$self->_find_release_year($adv_obj);
		unless (defined($year)) {
			$msg="Advisory has a bad year in its release ";
			$msg.="date and cound not be added to database!";
			carp $msg,"\n";
			return (undef,$msg);
		}#unless

		#Come up with a new path.
		$new_path=$self->_compose_new_path($year,$paths_HR,$region_code);

		$root_paths=$self->_root_paths($new_path);

		unless ($root_paths){
			$msg="Couldn't create root directories to $new_path!";
			carp $msg,"\n";
			return (undef,$msg); 
		}#unless

		#Shiny_new method only succeeds if the path doesn't already exist.
		($new_data_obj,$error)=Geo::Storm_Tracker::Data->shiny_new($new_path);

		#Make sure the new_data_obj is good.
		#If it is not then sleep for 2 seconds and rerun recall this subroutine.
		unless (defined $new_data_obj){
			$counter=$self->_increment_counter($counter);
			if ($counter >3){
				$msg="Failed at adding advisory!";
				carp $msg,"\n";
				return (undef,$msg);
			}
			else {
				sleep 2;
				$self->add_advisory($adv_obj,$force,$counter);
			}
		}#unless

		#If this is the last advisory to be issured then make the storm inactive.
		#Use the secret 3rd argument to insert_advisory to make this happen.
		if ($adv_obj->is_final){
			($success,$error)=$new_data_obj->insert_advisory($adv_obj,$force,1);
		}
		else {
			($success,$error)=$new_data_obj->insert_advisory($adv_obj,$force);
		}

		return ($success,$error);
	}#if/else

}#add_advisory
#---------------------------------------------------------
#$region_exists=$self->_region_dir_exists($region_code)
sub _region_dir_exists {
	my $self=shift;
	my $region_code=shift;

	my $region_path=$self->{'base_path'}."$region_code/";

	if ((-e $region_path) and (-d $region_path)){
		return 1;
	}
	else {
		return 0;
	}#if/else

}#_region_dir_exists
#---------------------------------------------------------
#($good,$error)=$self->_create_region_dir($region_code);
sub _create_region_dir {
	my $self=shift;
	my $region_code=shift;

	my ($region_path, $success, $msg)=undef;
	
	$region_path=$self->{'base_path'}."$region_code/";

	if ((-e $region_path) and (-d $region_path)){
		$msg="The directory $region_path already exists and will not be created by _create_region_dir!";
		carp $msg,"\n";
		return (undef,$msg);	
	}#if

	$success=mkdir($region_path,0777);
	
	if ((defined $success) and ($success)){
		return (1,undef);
	}
	else {
		$msg="The directory $region_path could not be created by _create_region_dir!";
		carp $msg,"\n";
		return (undef,$msg);
	}
}#_create_region_dir
#---------------------------------------------------------
sub _check_region_syntax {
	my $self=shift;
	my $region_code=shift;

	my $msg=undef;

	unless ($region_code =~ m!^\w{2}$!) {
		$msg="Region code is syntatically incorrect!";
		carp $msg,"\n";
		return (undef, $msg);
	}#unless

	return (1, undef);
}#_check_region_syntax	
#---------------------------------------------------------
sub _root_paths {
	my $self=shift;
	my $path=shift;

	my ($short_path)=undef;

	#Make sure path has trailing slash.
	$path=~s!/*$!/!;

	$short_path=$path;
	$short_path=~s!/[^/]*/$!/!;
	mkpath([$short_path], 0, 0777);

	if ((-e $short_path) and (-d $short_path)){
		return 1;	
	}
	else {
		return undef;
	}#if/else

}#_root_paths
#---------------------------------------------------------
sub _increment_counter {
	my $self=shift;
	my $counter=shift;
	if (defined $counter){
		$counter++;
	}
	else {
		$counter=1;
	}
	return $counter;
}#_increment_counter
#---------------------------------------------------------
sub _compose_new_path {
	my $self=shift;
	my $year=shift;
	my $paths_HR=shift;
	my $region_code=shift;

	my ($last_used_path, $early_path, $last_used_year)=undef;
	my ($last_used_event, $next_event, $next_path, $matches)=undef;
	my @reversed_paths=();

	if (
		(defined $paths_HR) and
		(defined $paths_HR->{$region_code}) and
		(scalar(@{$paths_HR->{$region_code}}) > 0)
		) {

		@reversed_paths=(reverse @{$paths_HR->{$region_code}});
		$last_used_path=$reversed_paths[$#reversed_paths];

		$last_used_path=~ s!/*$!/!;
		$matches=($last_used_path=~ m!/(\d{4})/(\d+)/$! );

		return undef unless ((defined $matches) and ($matches));

		$last_used_year=$1;
		$last_used_event=$2;

		if ($last_used_year == $year){
			$next_event=$last_used_event+1;
		}
		else {
			$next_event=1;
		}
	}
	else {
		$next_event=1;
	}#if/else

	$next_path=$self->{'base_path'}."$region_code/$year/$next_event/";

	return $next_path;
}#_compose_new_path
#---------------------------------------------------------
sub _find_release_year {
	my $self=shift;
	my $adv_obj=shift;

	my ($release_time,$matches)=undef;

	$release_time=$adv_obj->release_time();
	$release_time =~ s!\s*$!!;

	$matches=( $release_time =~ m!\s(\d{4})$! );

	if ((defined $matches) and ($matches)){
		return $1;	
	}
	else {
		return undef;
	}#if/else

}#_find_release_year
#---------------------------------------------------------
#Path array must be in the same order as that returned by _all_paths_by_region method.
sub _recent_storms {
	my $self=shift;
	my $paths_AR=shift;

	my ($path,$data_obj,$adv_obj,$header_frag,$region_code,$last_digits)=undef;
	my ($grep_count, $error)=undef;
	my @recent_storms=();
	my @recent_header_frags=();

	unless (defined @{$paths_AR}){
		return (undef,undef);
	}#unless

	foreach $path (reverse @{$paths_AR}){
		($data_obj,$error)=Geo::Storm_Tracker::Data->new($path);
		next unless (defined $data_obj);

		$adv_obj=$data_obj->current_advisory();
		next unless (defined $adv_obj);

		($header_frag,$region_code,$last_digits)=$self->_disect_header($adv_obj);
		$grep_count=grep {$_ eq $header_frag} @recent_header_frags;

		if (!$grep_count){
			push (@recent_header_frags,$header_frag);
			push (@recent_storms,$data_obj);
		}
		else {
			return (\@recent_storms, \@recent_header_frags);
		}#if/else
	}#foreach
	return (\@recent_storms, \@recent_header_frags);
}#_recent_storms
#---------------------------------------------------------
sub _associate_advisory_with_storm {
	my $self=shift;
	my $target_adv_obj=shift;
	my $recent_storms_AR=shift;
	my $recent_frags_AR=shift;

	#$too_old and $way_too_old should be in seconds.
	#These are delta times.
	my $too_old=60*60*24*60;#60 days old
	my $way_too_old=60*60*24*90;#90 days old

	my ($max_i, $i, $target_header_frag, $target_region_code, $target_last_digits)=undef;
	my ($matched_storm_obj, $matched_current_adv_obj, $old_epoch_time, $new_epoch_time)=undef;
	my ($time_delta)=undef;

	( $target_header_frag, $target_region_code, $target_last_digits)=$self->_disect_header($target_adv_obj);

	$max_i = scalar(@{$recent_storms_AR});
	for ($i=0; $i < $max_i; $i++){
		if (@{$recent_frags_AR}[$i] eq $target_header_frag){
			$matched_storm_obj=@{$recent_storms_AR}[$i];
			#return @{$recent_storms_AR}[$i];
		}#if
	}#for

	#If a matching storm was found, make sure it is not an old one.
	#If it is an old one then return undef;
	#Otherwise return the matching storm object.
	if ($matched_storm_obj){
		
		$matched_current_adv_obj=$matched_storm_obj->current_advisory();

		$old_epoch_time=$self->_extract_epoch_date($matched_current_adv_obj);
		$new_epoch_time=$self->_extract_epoch_date($target_adv_obj);

		if (($old_epoch_time) and ($new_epoch_time)) {

			$time_delta=$new_epoch_time-$old_epoch_time;

			if ($time_delta >= $way_too_old){
				return undef;
			}
			elsif (($time_delta >= $too_old) and ($target_adv_obj->advisory_number == 1)) {
				return undef;	
			}
			else {
				return $matched_storm_obj;
			}#if/elsif/else
		}
		else {
			if (
				($target_adv_obj->advisory_number == 1) and
				($matched_current_adv_obj->advisory_number != 1)
				){
				return undef;
			}
			else {
				return $matched_storm_obj;
			}#if/else	

		}#if/else
	}
	#If a matching storm wasn't found then return undef.
	else {
		return undef;
	}#if/else

}#_associate_advisory_with_storm
#---------------------------------------------------------
sub _extract_epoch_date {
	my $self=shift;
	my $adv_obj=shift;

	my ($release_time, $match, $month,$mon,$mday,$year, $time)=undef;

	my %month_hash=(
			'JAN'=>0,
			'FEB'=>1,
			'MAR'=>2,
			'APR'=>3,
			'MAY'=>4,
			'JUN'=>5,
			'JUL'=>6,
			'AUG'=>7,
			'SEP'=>8,
			'OCT'=>9,
			'NOV'=>10,
			'DEC'=>11,
			);

	return undef unless (defined $adv_obj);

	$release_time=$adv_obj->release_time();

	$match=($release_time =~ m!\s(\w{3})\s+(\d+)\s+(\d{4})$!i);

	if ($match){
		$month=$1;
		$mday=$2;
		$year=$3;

		$mon=$month_hash{(uc $month)};

		#$time = timegm($sec,$min,$hours,$mday,$mon,$year);
		$time = timegm(0,0,0,$mday,$mon,$year);

		return $time;
	}
	else {
		return undef;
	}#if/else
}#_extract_epoch_date
#---------------------------------------------------------
sub _disect_header {
	my $self=shift;
	my $arg=shift;

	my ($wmo_header,$matches,$region_code,$last_digits,$header_frag,$msg)=undef;

	if (ref $arg){
		$wmo_header=$arg->wmo_header();
	}
	else {
		$wmo_header=$arg;
	}
	
	$matches=($wmo_header =~ m!^(WT(\w{2})(\d{2}))\s!);

	unless ($matches){
		$msg="Bad wmo header in advisory!";
		$msg="  Bad advisory has wmo header of $wmo_header!";
		croak $msg,"\n";
	}
	$region_code=$2;
	$last_digits=$3;
	$header_frag=$1;

	return ($header_frag,$region_code,$last_digits);

}#_disect_header
#---------------------------------------------------------
sub specific_storm {
        my $self=shift;
        my $region_code=shift;
        my $year=shift;
        my $event_number=shift;
 
        my ($good, $msg, $data_obj, $path)=undef;
 
        ($good,$msg)=$self->_check_region_syntax($region_code);
 
        unless ($good){
                return (undef,$msg);
        }
 
        $path=$self->{'base_path'}."$region_code/$year/$event_number/";

	#new method will fail unless storm already exists. 
	($data_obj,$msg)=Geo::Storm_Tracker::Data->new($path);

	return ($data_obj,$msg);

}#specific_storm
#---------------------------------------------------------
#Region is extracted from the abreviated WMO header
#last counter argument is a secret.
sub add_advisory_by_year_and_event {
	my $self=shift;
	my $adv_obj=shift;
	my $year=shift;
	my $event_number=shift;
	my $force=shift;
	my $counter=shift;

	my ($success, $data_obj, $header_frag, $region_code)=undef;
	my ($last_digits, $good, $msg, $error, $path, $root_paths)=undef;

	($header_frag,$region_code,$last_digits)=$self->_disect_header($adv_obj);

	($good,$msg)=$self->_check_region_syntax($region_code);

	unless ($good){
		return (undef,$msg);
	}

	#Make Region directory if necessary
	unless ($self->_region_dir_exists($region_code)){
	        ($good,$error)=$self->_create_region_dir($region_code);
	        return (undef,$error) unless ($good);
	}#unless

	$path=$self->{'base_path'}."$region_code/$year/$event_number/";

	#If the path exists then this should be a pre-existing storm, so use new method.
	if ((-e $path) and (-d $path)){
		($data_obj,$msg)=Geo::Storm_Tracker::Data->new($path);
	}
	#If the path does not exist then this should be a brand new storm, so use shiny_new method.
	else {
		#Make sure all the base paths exist.
		$root_paths=$self->_root_paths($path);
		unless ($root_paths){
                        $msg="Couldn't create root directories to $path!";
                        carp $msg,"\n";
                        return (undef,$msg); 
                }#unless
		#Call the shiny_new method.
		($data_obj,$msg)=Geo::Storm_Tracker::Data->shiny_new($path);
	}#if/else

	#If something went wrong then try several times before failing.
	#This will take account of two processes competing against each other.
	unless (defined $data_obj){
		$counter=$self->_increment_counter($counter);
		if ($counter >3){
			$msg .= "Failed at adding advisory!";
			carp $msg,"\n";
			return (undef,$msg);
		}
		else {
			sleep 2;
			$self->add_advisory_by_year_and_event($adv_obj,$year,$event_number,$force,$counter);
		}#if/else
	}#unless

	#If this is the last advisory to be issured then make the storm inactive.
	#Don't go the other way though, and make it active if it isn't the last advisory.
	#Use the secret 3rd argument to insert_advisory to make this happen.
	if ($adv_obj->is_final){
		($success,$error)=$data_obj->insert_advisory($adv_obj,$force,1);
	}
	else {
		($success,$error)=$data_obj->insert_advisory($adv_obj,$force);
	}#if/else

	return ($success,$error);

}#add_advisory_by_year_and_event
#---------------------------------------------------------
sub _croak_on_bad_region_syntax {
	my $self=shift;
	my $region=shift;

	my $msg=undef;
	
	unless ((defined $region) and ($region =~ m!^\w{2}$!)) {
		$msg="Target region code $region ";
		$msg .= "is not a two alphanumeric character string!";
		croak $msg,"\n";
	}

	return 1;

}#_croak_on_bad_region_syntax
#---------------------------------------------------------
#Searches base path to find every storm path.
#Paths are sorted lexically by region identifier and
#then subsorted numerically by year and advisory number.
#The oldest paths will first.
#Every directory returned will have a trailing slash.
#In the event that a target region has been specified then only thatd
#region's directory will be searched.
sub _all_paths_by_region {
	my $self=shift;
	my $target_region_code=shift;

	my ($base_path, $possible_region_dir, $region, $region_dir, $year_dir, $event_dir)=undef;
	my ($target_exists, $msg, $good, $error, $path_to_match)=undef;
	my @dir_list=();
	my @region_dirs=();
	my @event_dir_list=();
	my @final_dir_list=();
	my $paths_by_region_HR={};

	#Place base path in an easy to use variable.
	#New method already insured that the base path has a trailing slash. 
	$base_path=$self->{'base_path'};

	#Search top level base path dir for various regions. 
	@dir_list=$self->_dir_listing($base_path);
	foreach $possible_region_dir (@dir_list){
		next unless $possible_region_dir =~ m!/\w{2}$!;
		push (@region_dirs,$possible_region_dir);
	}#foreach

	#Sort region directories lexically.
	@region_dirs=sort _sort_dirs_lexically @region_dirs;

	#Check to see if a target region code was defined.
	#If so then only check for that region's paths.
	#Do this by modifying @region_dirs to only include the target region.
	if (defined $target_region_code){

		#Check target_region syntax.
		#_croak_on_bad_region_syntax will croak if the region fails the test.
		#$self->_croak_on_bad_region_syntax($target_region_code);
		($good,$error)=$self->_check_region_syntax($target_region_code);

		unless ($good){
			return (undef,$error);
		}

		#Look for the target_region_code in the region directories found.
		$path_to_match=$self->{'base_path'}.$target_region_code;
		$target_exists=grep {$_ eq $path_to_match} @region_dirs;
	
		if ($target_exists){
			#@region_dirs=($target_region_code);
			@region_dirs=($path_to_match);
		}
		else {
			$msg = "Directory for region $target_region_code was not found!";
			carp $msg,"\n";
			return (undef,$msg);
		}#if/else

	}#if

	#Find every year and event in every region and make one nice big array
	#with all paths found.
	foreach $region_dir (@region_dirs) {

		#Make sure final dir list is clean.
		@final_dir_list=();

		#Find every year directory for this region.
		@dir_list=$self->_dir_listing($region_dir);

		#Only keep directories that look like a 4 digit year.
		@dir_list=grep {m!/\d{4}$!} @dir_list; #notice nice y2k compliance
		
		#Sort year directories numerically
		@dir_list = sort _sort_dirs_numerically @dir_list;

		foreach $year_dir (@dir_list){
			#Find every weather event directory for this year.
			@event_dir_list=$self->_dir_listing($year_dir);

			#Only keep directories that look like a number;
			@event_dir_list=grep {m!/\d+$!} @event_dir_list;

			#Sort events numerically.
			@event_dir_list=sort _sort_dirs_numerically @event_dir_list;

			#Push the event directories onto the final directory list.
			push (@final_dir_list,@event_dir_list);
		}#foreach

		#Add trailing slash to every directory in the final directory list.
		#@final_dir_list = map {s!/*$!/!} @final_dir_list;
		map {s!/*$!/!} @final_dir_list;

		#Put information into path by region hash ref.
		$region_dir =~ m!/(\w{2})$!;
		$region=$1;
		$paths_by_region_HR->{$region}=[@final_dir_list];
	}#foreach

	return ($paths_by_region_HR, undef);

}#_all_paths_by_region
#---------------------------------------------------------
sub _sort_dirs_numerically {
	$a =~ m!/(\d+)$!;
	my $a_num = $1;
	$b =~ m!/(\d+)$!;
	my $b_num = $1;
	return $a_num <=> $b_num;
}#_sort_dirs_numerically 
#---------------------------------------------------------
sub _sort_dirs_lexically {
	$a =~ m!/([^/]+)$!;
	my $a_var = $1;
	$b =~ m!/([^/]+)$!;
	my $b_var = $1;
	return $a_var cmp $b_var;
}#_sort_dirs_lexically 
#---------------------------------------------------------
#No trailing slash on directory pathnames returned.
sub _dir_listing {
	my $self=shift;
	my $dir_name=shift;

	my ($d, $msg)=undef;
	my @dir_list=();
	my @dir_clean_list=();

	#Make sure $dir_name has a trailing slash.
	$dir_name =~ s!/*$!/!;

	#Go find out what files are in the dir_name directory.	
	$d=IO::Dir->new();
	        $d->open($dir_name);
        unless (defined($d)){  
                $msg = "Had trouble reading $dir_name directory!"; 
                carp $msg,"\n";
                return undef;  
        }      
        @dir_list=$d->read(); 
        $d->close();

	#Get rid of . and .. as directory names.
	@dir_clean_list=grep !/^(\.|\.\.)$/, @dir_list;

	#Make dir_clean_list array have full pathnames.
	map {$_=$dir_name.$_} @dir_clean_list;

	#Weed out any files which are not directories.
	@dir_list=();
	@dir_list=grep {-d $_} @dir_clean_list;

	return @dir_list; 
}#_dir_listing
#---------------------------------------------------------
sub all_storms_by_region {
	my $self=shift;
	my $target_region_code=shift;

	my ($data_obj,$path,$all_paths_by_region_HR)=undef;
	my ($region,$data_objects_by_region_HR)=undef;
	my ($good,$error)=undef;
	my @all_paths=();
	my @all_data_objects=();

	if (defined $target_region_code){

		($good,$error)=$self->_check_region_syntax($target_region_code);
		unless ($good){
			return (undef,$error);
		}#unless
	}#if

	($all_paths_by_region_HR,$error)=$self->_all_paths_by_region($target_region_code);
	unless (defined $all_paths_by_region_HR){
		return (undef,$error);
	}#unless

	foreach $region (keys %{$all_paths_by_region_HR}) {

		#Make sure @all_data_objects is empty.
		@all_data_objects=();

		foreach $path (@{$all_paths_by_region_HR->{$region}}){
			($data_obj,$error)=Geo::Storm_Tracker::Data->new($path);
			if (defined $data_obj){
				push (@all_data_objects,$data_obj);
			}
			else {
				carp $error,"\n";
			}#if/else
		}#foreach
		
		$data_objects_by_region_HR->{$region}=[@all_data_objects];

	}#foreach

	return ($data_objects_by_region_HR,undef);

}#all_storms_by_region
#---------------------------------------------------------
#Unless a target_region is specified the returned has
#will have a key for every region found.
sub all_active_storms_by_region {
        my $self=shift;
        my $target_region_code=shift;
 
        my ($data_obj,$path,$all_paths_by_region_HR)=undef;
        my ($region,$data_objects_by_region_HR)=undef;
        my ($good, $error, $is_active)=undef;
        my @all_paths=();
        my @all_data_objects=();
 
        if (defined $target_region_code){
 
                ($good,$error)=$self->_check_region_syntax($target_region_code);
                unless ($good){
                        return (undef,$error);
                }#unless
        }#if
 
        ($all_paths_by_region_HR,$error)=$self->_all_paths_by_region($target_region_code);
        unless (defined $all_paths_by_region_HR){
                return (undef,$error);
        }#unless
 
        foreach $region (keys %{$all_paths_by_region_HR}) {
 
                #Make sure @all_data_objects is empty.
                @all_data_objects=();
 
                foreach $path (@{$all_paths_by_region_HR->{$region}}){

                        ($data_obj,$error)=Geo::Storm_Tracker::Data->new($path);

			unless (defined $data_obj){
				carp $error,"\n";
				next;
			}#unless

                        ($is_active,$error)=$data_obj->is_active();
			
			unless (defined $is_active){
				carp $error,"\n";
				next;
			}#unless

			push (@all_data_objects,$data_obj) if ($is_active);

                }#foreach
 
                $data_objects_by_region_HR->{$region}=[@all_data_objects];
 
        }#foreach
 
        return ($data_objects_by_region_HR,undef);

}#all_active_storms_by_region
#---------------------------------------------------------

1;
__END__

=head1 NAME

Geo::Storm_Tracker::Main - Master method of the Storm-Tracker perl bundle for dealing with Weather Advisories.

=head1 SYNOPSIS

	use Geo::Storm_Tracker::Main;

	#Create a new main object.
	#The mandatory path argument determines the base path to
	#all the data files.
	$main_obj=Geo::Storm_Tracker::Main->new('/archives/');	

	#Add an advisory object to the database.
	#The advisory being added must be a recent advisory.
	#The add_advisory method will try and determine which
	#storm the advisory belongs to and update it accordingly.
	#Second argument can be thought of as a force flag.
	($success,$error)=$main_obj->add_advisory($adv_obj,[0|1]);

	#Add an advisory object to the database for a
	#known year and weather event number. 
	#Year must have four digits.
	#Weather event number (15th storm of 1999) says
	#which storm of the year this advisory is for.
	#This method can easily corrupt the database if given the wrong information.
	#Designed for use in initially loading and maintaining the database.
	($success,$error)=$main_obj->add_advisory_by_year_and_event($adv_obj,'1999','15');

	#Obtain a listing of data objects for every storm
	#by region (or just one region if desired).
	$region_code='NT'; #North Atlantic
	($data_HR,$error)=$main_obj->all_storms_by_region([$region_code]);
	@data_objects_for_region_code=@{$data_HR->{$region_code}};

	#Obtain a listing of data objects for every active storm
	#by region (or just one region if desired).
	$region_code='NT'; #North Atlantic
	($data_HR,$error)=$main_obj->all_storms_by_region([$region_code]);
	@active_data_objects_for_region_code=@{$data_HR->{$region_code}};

	#Obtain the data object for a specific storm.
	$region_code='NT'; #North Atlantic
	$year=1999;
	$event_number=15; #15th storm of the year.
	($data_obj,$error)=$main_obj->specific_storm($region_code,$year,$event_number);

=head1 DESCRIPTION

The C<Geo::Storm_Tracker::Main> module is a component
of the Storm-Tracker perl bundle.  The Storm-Tracker perl bundle
is designed to track weather events using the national weather advisories.
The original intent is to track tropical depressions, storms and hurricanes.
There should be a C<Geo::Storm_Tracker::Data> object for each
weather event being stored and/or tracked.  The C<Geo::Storm_Tracker::Data>
objects are managed by C<Geo::Storm_Tracker::Main>.

=cut

=head1 CONSTRUCTOR

=over 4

=item new (PATHNAME)

Creates a Geo::Storm_Tracker::Main object.
This constructor method returns an array of
the form (OBJECT,ERROR).  OBJECT being the
newly created object if successful, and
ERROR being any errors encountered during the
attempt.
 
The entire data set for this object is assumed to be contained
within the directory specified by the mandatory
PATHNAME argument.  In the event that a directory
with the given PATHNAME does not exist, the method
will fail.  Check to see if the OBJECT returned is defined.
 
=back

=head1 METHODS

=over 4

=item add_advisory (ADVISORY_OBJECT,[FORCE])

Attempts to insert a C<Geo::Storm_Tracker::Advisory>
object into the appropriate C<Geo::Storm_Tracker::Data>
object.  The C<Geo::Storm_Tracker::Main> object looks
at the most recent storms for the advisory's region and tries
to figure out which storm it belongs to.  Once it determines
this it inserts the advisory into the storm object it
determined was associated with the storm.
If necessary it will create a new data object to hold the
advisory The optional force flag argument is passed
on to the insert_advisory method of
C<Geo::Storm_Tracker::Data>.
 
The method returns an array of the form (SUCCESS,ERROR).
SUCCESS being a boolean value indicating whether or not
the operation was successful and ERROR being a scalar
string reporting what error was encountered if any.

=item add_advisory_by_year_and_event (ADVISORY_OBJECT, YEAR, EVENT_NUMBER, [FORCE])

Attempts to insert a C<Geo::Storm_Tracker::Advisory>
object into the appropriate C<Geo::Storm_Tracker::Data>
object.  The C<Geo::Storm_Tracker::Main> object uses
the data object corresponding to the year and event number
specified as arguments.  The optional force flag argument
is passed on to the insert_advisory method of
C<Geo::Storm_Tracker::Data>.  If an appropriate data object
can not be found, one will be created.

 
The method returns an array of the form (SUCCESS,ERROR).
SUCCESS being a boolean value indicating whether or not
the operation was successful and ERROR being a scalar
string reporting what error was encountered if any.

=item  all_storms_by_region ([REGION_CODE])

Returns an array of the form (HASH_REF,ERROR).
HASH_REF being a reference to a hash of
references to arrays of C<Geo::Storm_Tracker::Data>
objects.  HASH_REF will be keyed by region code.  If
the optional REGION_CODE argument was given then the
region given will be the only key available in the
returned HASH_REF, otherwise there will be a key
for every region the C<Geo::Storm_Tracker::Main> 
object knows about.  The arrays of
C<Geo::Storm_Tracker::Data> objects being referenced 
will be sorted by year and weather event order.  Both
inactive and active storms will be listed in the 
data object arrays.
 
The scalar ERROR string contains any errors encountered
if unsuccessful.  The HASH_REF will be undefined in
this case.

=item all_active_storms_by_region

Returns an array of the form (HASH_REF,ERROR).
HASH_REF being a reference to a hash of
references to arrays of C<Geo::Storm_Tracker::Data>
objects.  HASH_REF will be keyed by region code.  If
the optional REGION_CODE argument was given then the
region given will be the only key available in the
returned HASH_REF, otherwise there will be a key
for every region the C<Geo::Storm_Tracker::Main>
object knows about.  The arrays of
C<Geo::Storm_Tracker::Data> objects being referenced
will be sorted by year and weather event order.  Only
active storms will be listed in the data object arrays.
 
The scalar ERROR string contains any errors encountered
if unsuccessful.  The HASH_REF will be undefined in
this case.

=item specific_storm (REGION_CODE, YEAR, EVENT_NUMBER)

Returns an array of the form (DATA_OBJECT, ERROR).
DATA_OBJECT being a reference to a C<Geo::Storm_Tracker::Data>
object for the desired REGION_CODE, YEAR,
and weather EVENT_NUMBER.

The scalar ERROR string contains any errors encountered
if unsuccessful.

=back

=cut

=head1 AUTHOR


Jimmy Carpenter, Jimmy.Carpenter@chron.com

All rights reserved.  This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.
 
Thanks to Dr. Paul Ruscher for his assistance in helping me to understand
the weather advisory formats.


=head1 SEE ALSO

	Geo::Storm_Tracker::Data
	Geo::Storm_Tracker::Advisory
	Geo::Storm_Tracker::Parser
	perl(1).

=cut
