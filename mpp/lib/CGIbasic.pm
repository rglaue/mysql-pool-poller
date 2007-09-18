package CGIbasic;


###########################
# Module: CGIbasic
# By: Russell E Glaue
# Date: April 2, 2002
# Revised: 09/17/2002
##
 
##
# Revision History
##
# v0.001 - 20020402
#	Initial compilation
##
# v0.010 - 20020917
#	Added support for multipart/formdata encoded mime type.
#	Rewrote main getcgi function. Still produces same results.
#	Modified into a registration function, now takes %hash
#	  as name charasters to signafy has is desired over array.
#	  %hash only good for uploading files/data.
##

use strict;
# use Variable_scope;

BEGIN {
  use Exporter      ();
  use vars          qw($NAME $VERSION $REVISION);
  use vars          qw($AUTHOR_NAME $AUTHOR_EMAIL $COMMISSION);
  use vars          qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
  
  @ISA            = qw(Exporter);
  @EXPORT_OK      = qw();
  %EXPORT_TAGS    = ( );  # eg: TAG => [qw!name1 name2! ],
  
  $NAME           = 'CGIbasic';
  $VERSION        = '0.010';
  $REVISION       = 20020917;
  $AUTHOR_NAME    = 'Russell E Glaue';
  $AUTHOR_EMAIL   = 'rglaue@cait.org';
  $COMMISSION     = 'Center for the Application of Information Technologies';
}


sub new {
  my $pkg    = shift;
  my $class  = ref($pkg) || $pkg;
  my $rhash;
    
  $rhash = bless {}, $class;
        
  return $rhash;
}


sub getcgi {
  my $self	= shift;

  my ($IN, @pairs, $buffer, @bufParts, $pair, $name, $value, $boundary, $warnval);
  $warnval	= 0;

  read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});

  if ($ENV{'CONTENT_TYPE'} =~ /^multipart\/form-data/) {
    $boundary	= $ENV{'CONTENT_TYPE'};
    $boundary	=~ s/multipart\/form-data\; boundary=(.*)/$1/;

    @bufParts	= split(/--$boundary-?-?([\r]\n)+\n*/, $buffer);
    foreach my $bufPart (@bufParts) {
      my (@lines,$line,$vals);
      @lines	= split(/[\r]\n/,$bufPart);
      $vals	= {};
	## TEST to see input
	# my $tt = 0;
	# foreach my $tline (@lines) {  $tt++;  print "<pre>[ $tt [[$tline]] ]</pre>\n";  }
      ## line 1;
      $line	= shift @lines || undef;
      $line	=~ s/^Content-Disposition\: form-data; //i;
      @pairs	= split(/;\s+/, $line);
      foreach $pair (@pairs) {
        my ($name,$value)	= split(/\=/,$pair,2);
        $value	=~ s/\"//g;
        $vals->{$name}		= $value
      }
      ## line 2;
      $line	= shift @lines || undef;
      if ($line =~ /^Content-Type\: ([^\s]+)$/i) {
        $vals->{'content-type'}	= $1;
        ## line 3;  # This line will be blank, next line is data
        $line	= shift @lines || undef;
        ## line 4;
        $line	= shift @lines || undef;
        $vals->{'content-data'}	= $line;
        if ($vals->{'name'} =~ /^\%(.*)/) {
          my $newname	= $vals->{'name'};
	     $newname	=~ s/^\%//; 
          register($newname,$vals);
        } elsif ($vals->{'name'} =~ /^\@(.*)/) {
          register($vals->{'name'},$vals->{'filename'});
          register($vals->{'name'},$vals->{'content-type'});
          register($vals->{'name'},$vals->{'content-data'});
        } else {
          register($vals->{'name'},$vals->{'content-data'});
        }
      } else {  # else line is blank, next line is data
        ## line 3;
        $line	= shift @lines || undef;
        $vals->{'content-data'}	= $line;
        register($vals->{'name'},$line);
      }
    }

  } else {  # POST = ($ENV{'CONTENT_TYPE'} eq "application/x-www-form-urlencoded")
    @pairs = split(/&/, $buffer);
    unless (@pairs) {  @pairs = split(/&/,$ENV{QUERY_STRING});  }

    foreach $pair (@pairs) {
      ($name, $value) = split(/=/, $pair);

      # Un-Webify plus signs and %-encoding
      $name =~ tr/+/ /;
      $name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;   
      $value =~ tr/+/ /;
      $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;

      register($name,$value);
    }
  }

  sub register ($$) {
    my $name	= shift;
    my $value	= shift || undef;

    if ($name =~ /\@([^\[]*)\[([^\]]*)\]/) {
      if (exists $IN->{$1}->{$2}) {
        push(@{$IN->{$1}->{$2}}, $value);
      } else {
        @{$IN->{$1}->{$2}}	= [$value];
      }
    } elsif ($name =~ /\@(.*)/) {
      if (exists $IN->{$1}) {
        push(@{$IN->{$1}}, $value);
      } else {
        @{$IN->{$1}}	= [$value];
      }
    } elsif ($name =~ /([^\[]*)\[([^\]]*)\]/) {
      if (exists $IN->{$1}->{$2}) {
        $IN->{$1}->{$2}	= ($IN->{$1}->{$2}.",".$value);
      } else {
        $IN->{$1}->{$2}	= $value;
      }
    } else {
      if (exists $IN->{$name}) {
        $IN->{$name}	= ($IN->{$name}.",".$value);
      } else {
        $IN->{$name}	= $value;
      }
    }
  }

  return $IN;
}


sub processURLEncodedData {
    my($self)		= shift;
    my($submittedData)	= shift;

    my(@fields) = split('&', $submittedData);

    for (@fields) {
      tr/+/ /;

      my($fieldName, $fieldValue) = split('=', $_, 2);

      # The %xx hex numbers are converted to alphanumeric.
      $fieldName   =~ s/%(..)/pack("C", hex($1))/eg;
      $fieldValue  =~ s/%(..)/pack("C", hex($1))/eg;

      if (exists $self->{$fieldName}) {
	if (ref($self->{$fieldName}) eq "ARRAY") {
          push(@{$self->{$fieldName}}, $fieldValue);
	}
	else {
	  my($tempValue) = $self->{$fieldName};
	  delete $self->{$fieldName};
	  push(@{$self->{$fieldName}}, $tempValue);
	  push(@{$self->{$fieldName}}, $fieldValue);
	}
      }
      else {
	$self->{$fieldName} = $fieldValue;
      }
    }
}

sub processMultiPartData {
    my($self)		= shift;
    my($submittedData)	= shift;

    my($boundary) = $ENV{'CONTENT_TYPE'} =~ /^.*boundary=(.*)$/;

    my(@partsArray) = split(/--$boundary/, $submittedData);

    @partsArray = splice(@partsArray, 1, (scalar(@partsArray) - 2));

    my($aPart);
    foreach $aPart (@partsArray) {
      $aPart =~ s/(\r|)\n$//g;
      my($dump, $firstline, $fieldValue) = split(/[\r]\n/, $aPart, 3);
      next if $firstline =~ /filename=\"\"/;
      $firstline =~ s/^Content-Disposition: form-data; //;
      my(@columns) = split(/;\s+/, $firstline);
      my($fieldName) = $columns[0] =~ /^name=\"([^\"]+)\"$/;
      my(%dataHash);
      if (scalar(@columns) > 1) {
        my($contentType, $blankline);
        ($contentType, $blankline, $fieldValue) = split(/[\r]\n/, $fieldValue, 3);
	($dataHash{'content-type'}) = $contentType =~ /^Content-Type: ([^\s]+)$/;
      }
      else {
	my($blankline);
	($blankline, $fieldValue) = split(/[\r]\n/, $fieldValue, 2);
	if (exists $self->{$fieldName}) {
	  if (ref($self->{$fieldName}) eq "ARRAY") {
	    push(@{$self->{$fieldName}}, $fieldValue);
          }
          else {
	    my($tempValue) = $self->{$fieldName};
	    delete $self->{$fieldName};
	    push(@{$self->{$fieldName}}, $tempValue);
	    push(@{$self->{$fieldName}}, $fieldValue);
	  }   
	}
	else {
	  next if $fieldValue =~ /^\s*$/;
          $self->{$fieldName} = $fieldValue;
        }
	next;
      }
      my($currentColumn);
      for $currentColumn (@columns) {
        my($currentHeader, $currentValue) = $currentColumn =~ /^([^=]+)="([^"]+)"$/;
        $dataHash{"$currentHeader"} = $currentValue;
      }
      $dataHash{'contents'} = $fieldValue;
      $dataHash{'size'} = length($fieldValue);
      $self->{$fieldName} = \%dataHash;
    }
}




1

__END__  # blah, blah...
