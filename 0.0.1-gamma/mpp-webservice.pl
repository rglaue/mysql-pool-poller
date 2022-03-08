#!/usr/bin/perl
#

use strict;

use XML::TreePP;
use XML::TreePP::XMLPath;
use Data::Dump qw(pp);
use lib '/usr/local/mpp/lib';
use mysqlpool::failover;


#
# Initialize some globally used items
#
my $tpp = new XML::TreePP;
$tpp->set(indent => 4);
my $tppx = new XML::TreePP::XMLPath;
my $cache = {};

my $workpath = '/usr/local/mpp/ws';
my $config   = ($workpath .'/mpp-webservice-config.xml');

my $configxml = $tpp->parsefile($config);
my $mppcache;

foreach my $groupobj ( $tppx->filterXMLDoc($configxml, '/config/groups/group') ) {
    $mppcache->{ $groupobj->{'-name'} } = $groupobj->{'-cachefile'};
}


#
# Functions
#
my $flatten = sub {};
$flatten = sub ($) {
    my $tree = shift || return undef;
    my $newtree = {};
    if (ref($tree) ne 'ARRAY') {
        #DEBUG# print "=== ["; foreach my $key (keys %$tree) { print "/",$key; } print "]\n";
        return $tree if ref($tree) eq 'HASH';
        return ({'#text' => $tree});
    }
    my $merge = sub ($) {
        my $hash = shift;
        foreach my $key (keys %$hash) {
            if (! exists $newtree->{$key}) {
                $newtree->{$key} = $hash->{$key};
            } elsif (ref($newtree->{$key}) eq "ARRAY") {
                push(@{$newtree->{$key}},$hash->{$key});
            } else {
                my @tmpvalues;
                push(@tmpvalues,$newtree->{$key});
                push(@tmpvalues,$hash->{$key});
                $newtree->{$key} = \@tmpvalues;
            }
        }
    };
    foreach my $item (@{$tree}) {
        if (ref($item) eq "HASH") {
            $merge->($item);
        } else {
            my $flattree = $flatten->($item);
            $merge->($flattree);
        }
    }
    return $newtree;
};
##### END FUNCTIONS #####



# This is the path to the data inside the cache
my $path;



#
# Get Input
#
if      ( (exists $ENV{'PATH_INFO'}) && (defined $ENV{'PATH_INFO'}) ) {
    # Input is from web
    $path = $ENV{'PATH_INFO'};
} elsif ( (@ARGV >= 1) && (defined $ARGV[0]) ) {
    # Input is from shell
    $path = $ARGV[0];
} else {
    # There was no input, use default
    $path = '/';
}

if (exists $ENV{'SERVER_NAME'}) {
    print "Content-type: text/xml\n\n";
}

#
# Import cache file data
#
foreach my $cachename (keys %$mppcache) {
    my $object  = mysqlpool::failover->new(cache => { file => $mppcache->{$cachename} } );
    $cache->{$cachename} = $object->{'_cache'};
}



#
# Filter MPP cache and spit out resulting data
#
my $tree = $tppx->filterXMLDoc($cache,$path);
my $results;
$results->{'results'} = $flatten->($tree);
$results->{'results'}->{'-query'} = $path;

my $xml = $tpp->write($results);
print $xml,"\n";

exit 0;

__END__
