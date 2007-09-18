###########################
# Module: Config_info
# By: Russell E Glaue
# Date: July 9, 1998
# Revised: 12/04/2002
##

##
# Revision History
##
# 1.00803 MOD 20021204
# Minor bug fix. ->assign() will assign a key=val pair even when it is not
# created. So when assign but not created, and then written, it is not
# formatted correctly.
#
# 1.00802 MOD 20021127
# Modified the routine for parsing by undefined element.  Now undefind element
#  is not allowed to have spaces. "\s" must be used to define spaces if needed.
#      } elsif ($line =~ /^\s*([^\=\s]*)\s*=A=([^\=\s]*)=\s*(.*)\s*$/) {
#        # key=val val val - multiple values, seperated by undefined element
# The write routine was also modified for placing a " " after =A=<string>= so
#  that this bug will not occur with files Config_info has written to.
# This problem caused a key=A=value with an "=" in the value to be recognized
#  in this routine as =A=<string>= which was bad.  This will still happen, and
#  is now a know bug, if a key=A=value with an "=" in the value if one does not
#  put a space between the =A= type and the value.
#  Work around is to put in the space, ex:  key=A= subkey=subvalue
#
# 1.00801 MOD 20020429
# Quick clean up of routine &chop_trailing_slash
#
# 1.008 MOD 20020420
# Added new utility subroutine
#	$new_path = &chop_trailing_slash($unix_or_win32_shell_path)
# Added new routine to use to utility
#	$path_from_config = getcts('HANDLE','KEY_FOR_SHELL_PATH_VARIABLE');
#
# 1.007 MOD 20020414
# Modifed Load routine to accept spaces in between key/var, example:
#   KEY  =A=  A B C D	|	is {'KEY'} = ['A','B','C','D']
# Modifed Load routine to accept a different deliminator in the var elements
#   of an array definition. Example:
#   KEY  =A=|=    The|blue|fox|will|eat|the|turtle.
#     same as {'KEY'} = ['The','blue','fox','will','eat','the','turtle.']
# Modifed Load routine; Changed =A=F= to deliminate values in file by '\n'
#   Pre 1.007 versions only deliminated variables on one line by '\s'.
#   This version changed to identify each value to be on its own line.
# Fixed problem with load/reload. &load would not actually load into a CONFIG
#   or HANDLE object if it was not undefined, and &reload just wrappped
#   around the &load. So it never worked if the object to reload was not
#   undefined.
#   Now &reload first undefines the objects then wraps around &load.
#   This could be a problem if the config file does not exists or cannot be
#   read because the object will then be empty when reload/load completes.
#
#   It would be a good idea to add a new function to check to see if a 
#   file exists before trying to read it. This could be used in many places.
#   Right now an unsucessful element is returned if file could not be read,
#   except for when read in =F= or =A=F= contexts.
#
# 1.006 MOD 20010506
# Fixed problem caused by flock and NFS files.
# CAIT Infrastructure moved to NFS volumes, and thus flock does not work
# causing the perl app to spin for ever. So I changed the flock useage to
# fcntl which has corrected the problem. Fcntl supposedly does more percise
# work on file flags which is needed for files maintained on NFS Volumes.
#
# 1.00501 -- August 10, 2000
# Quick-Fixed a little bug that referenced @arrays from the config file into
# the internal config tree. Put my @array for =A= and =A=F= so new memory is
# Allocated each time arround. Arrays in the same handle where getting overwritten
# by the last key=@val because they all used the same memory spot!
#
# 1.005 -- July 12, 2000
# Fixed a single line of code in the 'write' subroutine that caused any program
# to fail when calling this routine if one of the fields/variables to write out
# was an array that was empty. Now the routine checks to see that the array is
# not empty before attempting to write it out the configuration file.
#
# 1.004 -- July 21, 1999
# Fixed file locking routine to lock the correct FILEHANDLE in 'write' subroutine.
# .. oops!
# This is some unknown times... I believe the bug was inserted on June 4, 1999.
# I refuse to believe I had this bug in the module for 5 months without knowing!
#
# 1.002 - 1.003 -- February 25, 1999 or June 4, 1999
# Fixed Bugs and made the module much much better, and complicated.
# I do not believe version 1.002 was ever released into production.
# This module became used in more programs than the one it was originally created for.
#
# 1.001 -- July 9, 1998
# Became a very updated and more useful module.
# Fixed many bugs, and added many features.
#
# 1.000 -- August 1997
# First relase of Config_info.pm
# This was the version that was originally written as a small add-on module to
# a larger program that I wanted to write configuration information out to a 
# file for easier manageability and configuration recall. It did not do very
# much at all!
##

package Config_info;

use strict;
use Fcntl;

BEGIN {
  use Exporter      ();
  use vars          qw($NAME $VERSION $REVISION);
  use vars          qw($AUTHOR_NAME $AUTHOR_EMAIL $COMMISSION);
  use vars          qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
  use vars          qw(%CFGD %CFGT $AUTOLOAD $load $get);

  @ISA            = qw(Exporter);
  @EXPORT_OK      = qw();
  %EXPORT_TAGS    = ( );  # eg: TAG => [qw!name1 name2! ],

  $NAME           = 'Config_info';
  $VERSION        = '1.00803';
  $REVISION       = 20021204;
  $AUTHOR_NAME    = 'Russell E Glaue';
  $AUTHOR_EMAIL   = 'rglaue@cait.org';
  $COMMISSION     = 'Center for the Application of Information Technologies';


  ## Default Values
  $CFGD{'ENV'}{'BASE'} = $ENV{'PWD'};
  $CFGD{'ENV'}{'CFG'} = ($CFGD{'ENV'}{'BASE'} . "/" . $0 . ".cfg");
  ## End Default Values

  ## More Default Values
  if (exists $CFGD{'ENV'}{'PM'}) {
    $ENV{'PM'} = ($CFGD{'ENV'}{'PM'});
    unshift(@INC,$ENV{'PM'});  # put {'PM'} at beginning of @INC
  }
  ## End More Default Values

}


# set flock paramaters
sub LOCK_SH { 1 }
sub LOCK_EX { 2 }
sub LOCK_NB { 4 }
sub LOCK_UN { 8 }
my $packed_return_buffer;


my $load = sub {
  my $get_file_cont = sub {
    my $file	= shift;
    my $cont;
    open (FILE, $file) || return undef;
    while(<FILE>) { $cont .= $_; }
    close(FILE);
    return $cont;
  };
  my $strip_trailing_spaces = sub {
    my $string	= shift;
    $string =~ s/^\s*([^\s].*[^\s])\s*$/$1/;
    return $string;
  };

  my $config = shift || $CFGD{'ENV'}{'CFG'} || return 0;
  my $h_only = uc shift || undef;  # handle only

  open (CFG, $config) || return 0;
  my ($line, $handle, @array, $key, $val, $type, $file);
  while ($line = <CFG>) {
    undef $key;  undef $val;  undef $type;  undef $file;
    if ($line =~ /\[([^\[\]].*)\]/) {
      $handle = uc $1; 
    } else { 
      next if defined $h_only && $handle ne $h_only;
      if ($line =~ /^\s*([^\=\s]*)\s*=A=F=\s*(.*)\s*$/) {
        # key=/file/path (val val val) - multiple values contained in file
	#  annd each value in the file is deliminated by a '\n'
	$key	= $1;
        $type	= "=A=F=";
	$val	= undef;
	$file	= $2;
        chomp($file) if $file =~ /\n$/;
	$key	= &$strip_trailing_spaces($key);
	$file	= &$strip_trailing_spaces($file);
        $val	= &$get_file_cont($file);
        my @array = split(/\n/,$val);
	$val	= \@array;
      } elsif ($line =~ /^\s*([^\=\s]*)\s*=A=([^\=\s]*)=\s*(.*)\s*$/) {
        # key=val val val - multiple values, seperated by undefined element
	$key	= $1;
        $type	= "=A=$2=";
	$val	= $3;
	$file	= undef;
        chomp($val) if $val =~ /\n$/;
	$key	= &$strip_trailing_spaces($key);
	$val	= &$strip_trailing_spaces($val);
        my @array = split(/$2/,$val);
        $val	= \@array;
      } elsif ($line =~ /^\s*([^\=\s]*)\s*=A=\s*(.*)\s*$/) {
        # key=val val val - multiple values, seperated by spaces
	$key	= $1;
        $type	= "=A=";
	$val	= $2;
        $file	= undef;
        chomp($val) if $val =~ /\n$/;
	$key	= &$strip_trailing_spaces($key);
	$val	= &$strip_trailing_spaces($val);
        my @array = split(/\s/,$val);
        $val = \@array;
      } elsif ($line =~ /^\s*([^\=\s]*)\s*=F=\s*(.*)\s*$/) {
        # key=/path/to/file (val) - single value contained in file
	$key	= $1;
        $type	= "=F=";
	$val	= undef;
        $file	= $2;
        chomp($file) if $val =~ /\n$/;
	$key	= &$strip_trailing_spaces($key);
	$val	= &$strip_trailing_spaces($file);
        $val	= &$get_file_cont($file);
      } elsif ($line =~ /^\s*([^\=\s]*)\s*=\s*(.*)\s*$/) {
        # key=val - single value
        $key	= $1;
        $type	= "=";
	$val	= $2;
        $file	= undef;
        chomp($val) if $val =~ /\n$/;
	$key	= &$strip_trailing_spaces($key);
	$val	= &$strip_trailing_spaces($val);
      } else { next; }  # else = line is not one to be used
      $key = uc $key;
      $CFGD{$config}{$handle}{$key} = $val;
      $CFGT{$config}{$handle}{$key} = [ $type, $file ];
    }
  }
  close(CFG);
  return 1;
};


# we know this works
# creats a new Config_info object
sub new {
  my $pkg    = shift;
  my $class  = ref($pkg) || $pkg;
  my $config = shift || undef;
  my $handle = uc shift || undef;
  my $rhash;

  $rhash = bless {}, $class;
  $rhash->set_config($config) if defined $config;
  $rhash->set_handle($handle) if defined $handle;

  return $rhash;
}


# we know this works
# returns current config_file or sets provided config_file as current
sub set_config {
  my $self   = shift;
  my $config = shift || undef;
  if (!defined $config) {
    if (exists $self->{'_config_file'}) {
      return $self->{'_config_file'} || undef;
    } else {
      return undef;
    }
  } else {
    my $old_config;
    if (exists $self->{'_config_file'}) {
      $old_config = $self->{'_config_file'};
    } else {
      $old_config = undef;
    }
    $self->{'_config_file'} = $config;
    return $old_config;
  }
# why does above work, and not this code here instead?
# my $config = shift || return $self->{'_config_file'} || return undef;
# my $old_config = $self->{'_config_file'};
# return 0 unless $self->{'_config_file'} = $config && return $old_config;
}


# we know this works
# returns current handle and/or sets provided handle as current
sub set_handle {
  my $self   = shift;
  my $handle = uc shift || undef;
  if (!defined $handle) {
    if (exists $self->{'_handle'}) {
      return $self->{'_handle'} || undef;
    } else {
      return undef;
    }
  } else {
    my $old_handle;
    if (exists $self->{'_handle'}) {
      $old_handle = $self->{'_handle'};
    } else {
      $old_handle = undef;
    }
    $self->{'_handle'} = $handle;
    return $old_handle;
  }
}


AUTOLOAD {
  return if $AUTOLOAD =~ /::DESTROY$/;

  my $self   = shift;
  my $config = $self->{'_config_file'};
  my $var    = uc $AUTOLOAD;
     $var    =~ s/^.*:://;
  my $key    = uc shift;
  my $val    = shift;

  if ($var =~ /ASSIGN(.*)/) {
    return $self->assign($1, $key, $val) if defined $1;
    return $self->assign($self->{'_handle'}, $key, $val) if !defined $1;
  }
  elsif ($var =~ /DELETE(.*)/) {
    return $self->delete($1, $key) if defined $1;
    return $self->delete($self->{'_handle'}, $key) if !defined $1;
  }
  elsif ($var =~ /GETCTS(.*)/) {
    return $self->get($1, $key) if defined $1;
    return $self->get($self->{'_handle'}, $key) if !defined $1;
  }
  elsif ($var =~ /GET(.*)/) {
    return $self->get($1, $key) if defined $1;
    return $self->get($self->{'_handle'}, $key) if !defined $1;
  }
  else {  # else command not recognized
    return 0;
  }

}


# assign
# assigns a new value to an existing key.
# returns 1 on success or 0 on failure
# returns undef on error
sub assign {
  my $err    = undef;
  my $self   = shift;
  my ($config,$handle,$key);
  # if 4 variables passed in, assume 1st 4 are $config,$handle,$key;
  if (@_==4) { $config = shift } else { $config = $self->set_config; }
  if (@_==3) { $handle = uc shift } else { $handle = $self->set_handle; }
  if (@_==2) { $key    = uc shift || undef; } else { return $err; }
  if ((!defined $config) || (!defined $handle)) { return $err; }
  my $val    = shift;
  # One must create the the key=val pair first.
  return $err if ! exists $CFGT{$config}{$handle}{$key};
  $CFGD{$config}{$handle}{$key} = $val; 
  $self->changed(1);
  return 1;
}


# create
# creates a variable/handle of defined type $op with value $value
# or assigns new designation type and value to existing variable
# returns 1 on success or 0 on failure
# returns undef on error
sub create {
  my $err    = undef;
  my $self   = shift;
  my ($config,$handle,$key);
  # if 5 variables passed in, assume 1st 5 are $config,$handle,$key;
  if (@_==5) { $config = shift } else { $config = $self->set_config; }
  if (@_==4) { $handle = uc shift } else { $handle = $self->set_handle; }
  if (@_==3) { $key    = uc shift || undef; } else { return $err; }
  if ((!defined $config) || (!defined $handle)) { return $err; }
  my $op     = shift;
  my $val    = shift;
  $CFGT{$config}{$handle}{$key} = [$op]; 
  $CFGD{$config}{$handle}{$key} = $val; 
  $self->changed(1);
  return 1;
}


# delete
# delete the specified variable of handle
# returns 1 if success or 0 on failure
# returns undef on error;
sub delete {
  my $err    = undef;
  my $self   = shift;
  my ($config,$handle,$key);
  # if 3 variables passed in, assume they are $config,$handle,$key;
  if (@_==3) { $config = shift } else { $config = $self->set_config; }
  if (@_==2) { $handle = uc shift } else { $handle = $self->set_handle; }
  if (@_==1) { $key    = uc shift || undef; } else { return $err; }
  if ((!defined $config) || (!defined $handle)) { return $err; }
  my $status = 0;
  if (defined $key) {
    if (delete $CFGD{$config}{$handle}{$key}) {
      delete $CFGT{$config}{$handle}{$key};
      $self->changed(1);
      $status = 1;
    } else { $status = 0; }
  } else {
    if (delete $CFGD{$config}{$handle}) {
      delete $CFGT{$config}{$handle};
      $self->changed(1);
      $status = 1;
    } else { $status = 0; }
  }
  return $status;
}


# get
# get the value of a variable in the Configuration data
# returns value or undef if there is no value.
# returns 0 if error
sub get {
  my $err    = 0;
  my $self   = shift;
  my ($config,$handle,$key);
  # if 3 variables passed in, assume they are $config,$handle,$key;
  if (@_==3) { $config = shift } else { $config = $self->set_config; }
  if (@_==2) { $handle = uc shift } else { $handle = $self->set_handle; }
  if (@_==1) { $key    = uc shift || undef; } else { return $err; }
  if ((!defined $config) || (!defined $handle)) { return $err; }
  if ((!exists $CFGD{$config}) || (!exists $CFGD{$config}{$handle})
    || (!exists $CFGD{$config}{$handle}{$key})) {
    return undef;
  } else {
    return $CFGD{$config}{$handle}{$key} || undef;
  }
}


# getcts
# same as get, but chops trailing slash on string to be returned
# useful for string which values is a shell path
sub getcts () {
  my $self	= shift;
  my $return	= $self->get(@_);
  return chop_trailing_slash($return);
}


# handle_exists
# return 1 if exists; return 0 if not exists; or return undef if error
sub handle_exists {
  my $err    = undef;
  my $self   = shift;
  my ($config,$handle);
  # if 2 variables passed in, assume they are $config,$handle;
  if (@_==2) { $config = shift } else { $config = $self->set_config; }
  if (@_==1) { $handle = uc shift } else { $handle = $self->set_handle; }
  return 0 unless exists $CFGD{$config}{$handle} && return 1;
}


# key_exists
# return 1 if exists; return 0 if not exists; or return undef if error
sub key_exists {
  my $err    = undef;
  my $self   = shift;
  my ($config,$handle,$key);
  # if 3 variables passed in, assume they are $config,$handle,$key;
  if (@_==3) { $config = shift } else { $config = $self->set_config; }
  if (@_==2) { $handle = uc shift } else { $handle = $self->set_handle; }
  if (@_==1) { $key    = uc shift || undef; } else { return $err; }
  return 0 unless exists $CFGD{$config}{$handle}{$key} && return 1;
}


# changed
# Sets _changed flag to $arg if $arg not undef and returns value of
# _changed flag before it was set;  else returns value of _changed flag if
# $arg is undef; Should probably be only assigned internally. Can be
# checked internally or externally to tell if data has changed.
# returns 1 if success or 0 if failure
# returns undef if error
sub changed {
  my $err    = undef;
  my $self   = shift;
  my $value  = shift || undef;
  return $self->{'_changed'} if !defined $value;
  $self->{'_changed'} = $value || return $err;
  return 1 if exists $self->{'_changed'} && $self->{'_changed'} == $value;
  return 0;
}


# handles
# returns a sorted list of handles of the Configuration data
# else returns undef if no handles exists in given config data
# else returns 0 if error
sub handles {
  my $err    = 0;
  my $self   = shift;
  my $config = shift || $self->set_config || return $err;
  return undef unless exists $CFGD{$config} && return sort keys %{$CFGD{$config}};
}


# keys
# returns a sorted list of keys of a given handle of the Config data
# else retuen undef if no keys exist in given handle
# else returns 0 if error
sub keys {
  my $err    = 0;
  my $self   = shift;
  my ($config,$handle);
  # if 2 variables passed in, assume they are $config,$handle;
  if (@_==2) { $config = shift } else { $config = $self->set_config; }
  if (@_==1) { $handle = uc shift } else { $handle = $self->set_handle; }
  if ((!defined $config) || (!defined $handle)) { return $err; }
  return undef unless exists $CFGD{$config}{$handle} && return keys %{$CFGD{$config}{$handle}};
}


# load
# loads or reloads a configuration file, or handle subset of a
# configuration file.
# returns 1 on success or 0 on failure
# returns undef if error;
sub load {
  my $err    = undef;
  my $self   = shift;
  my ($config,$handle);
  # if 2 variables passed in, assume they are $config,$handle;
  if (@_==2) { $config = shift } else { $config = $self->set_config; }
  if (@_==1) { $handle = uc shift } else { $handle = $self->set_handle; }
  if (!defined $config) { return $err; }
  if (defined $handle) {
    if (!defined %{$CFGD{$config}{$handle}}) { 
      &$load($config,$handle) && return 1 || return 0;
    } else { return 0; }
  } else {
    if (!defined %{$CFGD{$config}}) { 
      &$load($config) && return 1 || return 0;
    } else { return 0; }
  }
}


# reload
# wrapper arround &load
# However this function remove existing elements first.
# The load routine will not load unless element to load is undef.
sub reload {
  my $err	= undef;
  my @pass	= @_;
  my $self	= shift;
  my ($config,$handle);
  # if 2 variables passed in, assume they are $config,$handle;
  if (@_==2) { $config = shift } else { $config = $self->set_config; }
  if (@_==1) { $handle = uc shift } else { $handle = $self->set_handle; }
  if (!defined $config) { return $err; }
  if (defined $handle) {
    %{$CFGD{$config}{$handle}} = undef;
    %{$CFGD{$config}{$handle}} = undef;
  } else {
    %{$CFGT{$config}} = undef;
    %{$CFGT{$config}} = undef;
  }

  return $self->load(@pass);
}


# used to write out a configuration file from the %CFGD
# returns 1 for success or 0 for failure
# returns undef if error
sub write {
  my $err    = undef;
  my $self   = shift;
  my $config = shift || $self->set_config;
  my ($handle, $key, $temp);

  my $fsave = sub {
    my $file = shift || return $err;
    my $data = shift || return $err;
    open(FILE, ">$file") || return 0;
#    unless (flock(FILE,LOCK_EX | LOCK_NB)) {
#      # Can't write unless lock is exclusive... wait for write lock
#      unless (flock(FILE,LOCK_EX)) { close(FILE); return 0; }  # flock: $!
#    }
    unless (fcntl(FILE, F_WRLCK, $packed_return_buffer)) {
      # Can't write unless lock is exclusive... wait for write lock
      unless (fcntl(FILE, F_WRLCK, $packed_return_buffer)) { close(FILE); return 0; }  # fcntl F_WRLCK: $!
    }
    print FILE $data;
#    flock(FILE,LOCK_UN);
    fcntl(FILE, F_UNLCK, $packed_return_buffer);
    close(FILE);
  };

  open(CFG,">$config") || return 0;
#  unless (flock(CFG,LOCK_EX | LOCK_NB)) {
#    # Can't write unless lock is exclusive... wait for write lock
#    unless (flock(CFG,LOCK_EX)) { close(CFG); return 0; }  # flock $!
#  }
  unless (fcntl(CFG, F_WRLCK, $packed_return_buffer)) {
    # Can't write unless lock is exclusive... wait for write lock
    unless (fcntl(CFG, F_WRLCK, $packed_return_buffer)) { close(CFG); return 0; }  # fcntl F_WRLCK $!
  }
  foreach $handle(sort keys(%{$CFGD{$config}})) {
    print CFG "[$handle]\n";
    foreach $key(sort keys(%{$CFGD{$config}{$handle}})) {
      print CFG $key;
      print CFG $CFGT{$config}{$handle}{$key}->[0];
      $temp = $CFGD{$config}{$handle}{$key};
      if ($CFGT{$config}{$handle}{$key}->[0] =~ /=A=/) {
        if ($CFGT{$config}{$handle}{$key}->[0] =~ /=F=/) {
          print CFG $CFGT{$config}{$handle}{$key}->[1];
          # write $temp to file
          &$fsave($CFGT{$config}{$handle}{$key}->[1],$temp);
        } elsif ($CFGT{$config}{$handle}{$key}->[0] =~ /=A=([^\=]*)=/) {
          print CFG " ";  # is correction in 1.00802 needed for fixing bug found in version 1.00801
          print CFG join($1, @$temp) if defined $temp;
        } else {
          print CFG join(" ", @$temp) if defined $temp;
        }
      } else {
        if ($CFGT{$config}{$handle}{$key}->[0] =~ /=F=/) {
          print CFG $CFGT{$config}{$handle}{$key}->[1];
          # write $key/$val to file
          &$fsave($CFGT{$config}{$handle}{$key}->[1],$temp);
        } else {
          print CFG $CFGD{$config}{$handle}{$key};
        }
      }
      undef $temp;
      print CFG "\n";
    }
  }
#  flock(CFG,LOCK_UN);
  fcntl(CFG, F_UNLCK, $packed_return_buffer);
  close(CFG);

  return 1;

}



##  UTILITY ROUTINES
######################


sub chop_trailing_slash ($) {
  my $self      = shift if ref $_[0];
  my $path      = shift;
  my $D;

  if (defined $path) {
    if ('$^O' eq 'MSWin32') { $D = "\\"; } else { $D = "\/" }
    if ($path =~ /$D$/) {  chop($path);  }
  }
  
  return $path;
}


sub dump_data {
  my $self = shift;

  my ($key,$key1,$key2,$key3,$val);

  print "\n\n";

  print "MODULE OBJECT\n";
  foreach $key(keys %{$self}) {
    print "  $key -- $self->{$key}\n";
  }
  print "CONFIGURATIONS\n";
  foreach $key1(sort keys %CFGD) {
    print "  $key1\n";
    foreach $key2(sort keys %{$CFGD{$key1}}) {
      print "    $key2";
      if (ref $CFGT{$key1}{$key2}) {
      print "\n";
      foreach $key3(sort keys %{ $CFGD{$key1}{$key2} }) {
        print "\t[$key3] ";
	  print "\t" if length($key3) < 5;
	  print "\t" if length($key3) < 13;
	  print "\t";
        if ($CFGT{$key1}{$key2}{$key3}->[0] eq "=A=") {
          $val = join(" ",@{$CFGD{$key1}{$key2}{$key3}});
          print $CFGT{$key1}{$key2}{$key3}->[0];
          print "\t[$val]\n";
        } elsif (defined $CFGT{$key1}{$key2}{$key3}->[1]) {
          $val = $CFGT{$key1}{$key2}{$key3}->[1];
          print $CFGT{$key1}{$key2}{$key3}->[0];
          print "\t[$val]\n";
          print "----\n";
          print "$CFGD{$key1}{$key2}{$key3}\n";
          print "----\n";
        } else {
          print $CFGT{$key1}{$key2}{$key3}->[0];
          print "\t[$CFGD{$key1}{$key2}{$key3}]\n";
        }
      }
      } else {
        print " -> NOT REF, $key1:$key2:<$CFGT{$key1}{$key2}> ;\n";
      }
    }
  }

}



1;



__END__
