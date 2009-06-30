#!/usr/bin/perl
#

use strict;
use Getopt::Long;

use XML::XSLT;
use XML::Tidy;
use XML::TreePP;
use XML::TreePP::XMLPath;
use JSON::PP;
use CGI;
use Data::Dump qw(pp);
use lib '/usr/local/mpp/lib';
use mysqlpool::failover;

my $workpath = '/usr/local/mpp/ws';
my $xslfile  = ($workpath.'/client.xsl');
my $cssfile  = ($workpath.'/client.css');
my $config   = ($workpath .'/mpp-webclient-config.xml');

# Stubs
sub translate_cache (@);
sub print_html (@);
sub timestamp (@);

#
# Initialize some globally used items
#

my $tpp = new XML::TreePP;
$tpp->set(indent => 4);
my $tppx = new XML::TreePP::XMLPath;
my $json = new JSON::PP;
my $cgi = new CGI;

my $configxml = $tpp->parsefile($config);
my $mppservices = [ $tppx->filterXMLDoc($configxml, '/config/services/service/url') ];

#
# Get Input
#
my $path;
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


if ($path =~ m!/([^/]*)(/.*)!) {
    my $service_id = $1;
    my $service_path = $2;
    my $r =  $tpp->parsehttp( GET => ($mppservices->[$service_id].$service_path) );
    print "Content-type: text/plain\n\n";
    print $r->{'results'}->{'#text'} if exists $r->{'results'}->{'#text'};
} elsif ($path eq "/objup") {
    if (my $querystring = $cgi->param('json')) {
        my $jsoncode = $json->decode($querystring);
        my $cache;
        foreach my $k (keys %{$jsoncode}) {
            if ($jsoncode->{$k} =~ m!/([^/]*)(/.*)!) {
                my $service_id = $1;
                my $service_path = $2;
                if (! exists $cache->{$service_id}) {
                    my $c = $tpp->parsehttp( GET => ($mppservices->[$service_id]) );
                    $cache->{$service_id} = $c->{'results'};
                }
                my $v = $tppx->filterXMLDoc($cache->{$service_id},$service_path)->[0];
                if ($service_path =~ /last_request_time$/) {
                    $v = timestamp( epoch => $v, format => "human" );
                }
                $jsoncode->{$k} = $v;
            }
        }
        print "Content-type: text/json\n\n";
        print $json->encode($jsoncode);
    } else {
        print "Content-type: text/json\n\n";
        print '{}';
    }
} else {
    my $tcache;
    my $service_id = 0;
    foreach my $service (@{$mppservices}) {
        my $cache = $tpp->parsehttp( GET => $service );
        my $servicename = $tppx->filterXMLDoc($configxml, ('/config/services/service[url='.$service.']/@name'))->[0];
        my $translated = translate_cache($service_id, $servicename, $cache->{'results'});
        if (ref($translated->{'group'}) eq "ARRAY") {
            push(@{$tcache->{'groups'}->{'group'}},@{$translated->{'group'}});
        } else {
            push(@{$tcache->{'groups'}->{'group'}},$translated->{'group'});
        }
        push(@{$tcache->{'groups'}->{'objects'}->{'object'}},@{$translated->{'objects'}->{'object'}});
        $service_id++;
    }
    # organize layout
    my @org_groups;
    my $col1groups = $tppx->filterXMLDoc($configxml, '/config/layout/column[@id="1"]/group');
    my $col2groups = $tppx->filterXMLDoc($configxml, '/config/layout/column[@id="2"]/group');
    my $rownum = 0;
    while (1) {
        my ($group1,$group2);
        if ($group1 = $col1groups->[$rownum]) {
            my $hgroup = $tppx->filterXMLDoc($tcache, ('/groups/group[@name='.$group1->{'-name'}.'][@service='.$group1->{'-service'}.']'))->[0];
            $hgroup->{'-column'} = 'leftcol';
            push(@org_groups,$hgroup);
        }
        if ($group2 = $col2groups->[$rownum]) {
            my $hgroup = $tppx->filterXMLDoc($tcache, ('/groups/group[@name='.$group2->{'-name'}.'][@service='.$group2->{'-service'}.']'))->[0];
            $hgroup->{'-column'} = 'leftcol';
            push(@org_groups,$hgroup);
        }
        $rownum++;
        last if ! $group1 && ! $group2;
    }
    $tcache->{'groups'}->{'group'} = \@org_groups;

    my $jsonobjects;
    foreach my $object (@{$tcache->{'groups'}->{'objects'}->{'object'}}) {
        $jsonobjects->{$object->{'-id'}} = $object->{'#text'};
    }
    my $jsoncode = $json->encode($jsonobjects);
    $tcache->{'groups'}->{'objects'} = $jsoncode;
    my $xml = $tpp->write($tcache);
    #print $xml,"\n";

    if ($path eq "/obj") {
        print "Content-type: text/plain\n\n";
        print $xml;
        exit 0;
    }

    my $xslt = XML::XSLT->new($xslfile, warnings => 1);
    $xslt->transform (Source => $xml);

    print "Content-type: text/html\n\n";

    # Print it out raw
    # print $xslt->toString;

    # Or print it out formatted
    my $tidy_obj = XML::Tidy->new(xml => $xslt->toString);
    $tidy_obj->tidy();
    my $html = $tidy_obj->toString();

    my $cssdata;
    open(CSS,$cssfile);
    while (<CSS>) { $cssdata .= $_ }
    close(CSS);
    $html =~ s/\$STYLESHEETCONTENT\$/$cssdata/;
    $html =~ s/\<\?xml version=\"1.0\" encoding=\"utf-8\"\?\>//;

    print $html,"\n";
}

sub print_html (@) {
    my $hash = shift;
}

sub translate_cache (@) {
    my $id = shift;
    my $servicename = shift;
    my $cache = shift;
    my $tcache;
    my $tobject;
    my $objnum = 0;

    my $objid = sub {
        my $object = shift || undef;
        $objnum++;
        my $oid = ($id.$objnum);
        push (@{$tobject->{'object'}}, { '-id' => $oid, '#text' => $object } ) if defined $object;
        return $oid;
    };

    foreach my $cachename (keys %$cache) {
        next if ref($cache->{$cachename}) ne "HASH";
        my $tcache_group;
        $tcache_group->{'-name'} = $cachename;
        $tcache_group->{'-service'} = $servicename;
        my $fpconfig = $tppx->filterXMLDoc($cache,('/'.$cachename.'/_failover_pool_config'))->[0];
        foreach my $poolname (keys %$fpconfig) {
            my $poolconfig = $tppx->filterXMLDoc($fpconfig,('/'.$poolname))->[0];
            my @poolconfig = split(';',$poolconfig);
            my $hpool;
            $hpool->{'-name'}           = $poolname;
            $hpool->{'obj'}             = ('/'.$id.'/'.$cachename.'/_failover_pool/'.$poolname);
            $hpool->{'status'}->{'obj'}->{'-id'}   = $objid->(('/'.$id.'/'.$cachename.'/_failover_pool_status/'.$poolname));
            $hpool->{'status'}->{'obj'}->{'#text'} = '-';
            foreach my $item (@poolconfig) {
                if (($item =~ /^(primary)\:(.*)/) || ($item =~ /^(secondary)\:(.*)/)) {
                    my $servertype = $1;
                    my $servername = $2;
                    my $hserver;
                    $hserver->{'-name'}                        = $servername;
                    $hserver->{'obj'}                          = ('/'.$id.'/'.$cachename.'/_server_poll/'.$servername);
                    $hserver->{'last_request_time'}->{'obj'}->{'-id'}     = $objid->(('/'.$id.'/'.$cachename.'/_server_poll/'.$servername.'/last_request_time'));
                    $hserver->{'last_request_time'}->{'obj'}->{'#text'}   = '-';
                    $hserver->{'number_of_requests'}->{'obj'}->{'-id'}    = $objid->(('/'.$id.'/'.$cachename.'/_server_poll/'.$servername.'/number_of_requests'));
                    $hserver->{'number_of_requests'}->{'obj'}->{'#text'}  = '-';
                    $hserver->{'last_status_message'}->{'obj'}->{'-id'}   = $objid->(('/'.$id.'/'.$cachename.'/_server_poll/'.$servername.'/last_status_message'));
                    $hserver->{'last_status_message'}->{'obj'}->{'#text'} = '-';
                    push (@{$tcache_group->{'servers'}->{'server'}}, $hserver);

                    my $hpserver;
                    $hpserver->{'-name'}                       = $servername;
                    $hpserver->{'-type'}                       = $servertype;
                    $hpserver->{'-serverlastrequesttimeid'}    = $hserver->{'last_request_time'}->{'obj'}->{'-id'};
                    $hpserver->{'-servernumberofrequestsid'}   = $hserver->{'number_of_requests'}->{'obj'}->{'-id'};
                    $hpserver->{'-serverlaststatusmessageid'}  = $hserver->{'last_status_message'}->{'obj'}->{'-id'};
                    $hpserver->{'obj'}                         = ('/'.$id.'/'.$cachename.'/_failover_pool/'.$poolname.'/'.$servername);
                    $hpserver->{'failover_state'}->{'obj'}->{'-id'}       = $objid->(('/'.$id.'/'.$cachename.'/_failover_pool/'.$poolname.'/'.$servername.'/failover_state'));
                    $hpserver->{'failover_state'}->{'obj'}->{'#text'}     = '-';
                    $hpserver->{'failover_status'}->{'obj'}->{'-id'}      = $objid->(('/'.$id.'/'.$cachename.'/_failover_pool/'.$poolname.'/'.$servername.'/failover_status'));
                    $hpserver->{'failover_status'}->{'obj'}->{'#text'}    = '-';
                    $hpserver->{'failover_type'}->{'obj'}->{'-id'}        = $objid->(('/'.$id.'/'.$cachename.'/_failover_pool/'.$poolname.'/'.$servername.'/failover_type'));
                    $hpserver->{'failover_type'}->{'obj'}->{'#text'}      = '-';

                    my $cpconfig = $tppx->filterXMLDoc($cache,('/'.$cachename.'/_server_checkpoint_config/'.$poolname.'/'.$servername))->[0];
                    my @cpconfig = split(';',$cpconfig);
                    foreach my $item (@cpconfig) {
                      if (($item =~ /^(internal)\:(.*)/) || ($item =~ /^(edge)\:(.*)/) || ($item =~ /^(external)\:(.*)/)) {
                        my $checkpointtype = $1;
                        my $checkpointname = $2;
                        my $hcserver;
                        $hcserver->{'-name'}                                   = $checkpointname;
                        $hcserver->{'obj'}                                     = ('/'.$id.'/'.$cachename.'/_server_poll/'.$checkpointname);
                        $hcserver->{'last_request_time'}->{'obj'}->{'-id'}     = $objid->(('/'.$id.'/'.$cachename.'/_server_poll/'.$checkpointname.'/last_request_time'));
                        $hcserver->{'last_request_time'}->{'obj'}->{'#text'}   = '-';
                        $hcserver->{'number_of_requests'}->{'obj'}->{'-id'}    = $objid->(('/'.$id.'/'.$cachename.'/_server_poll/'.$checkpointname.'/number_of_requests'));
                        $hcserver->{'number_of_requests'}->{'obj'}->{'#text'}  = '-';
                        $hcserver->{'last_status_message'}->{'obj'}->{'-id'}   = $objid->(('/'.$id.'/'.$cachename.'/_server_poll/'.$checkpointname.'/last_status_message'));
                        $hcserver->{'last_status_message'}->{'obj'}->{'#text'} = '-';
                        push (@{$tcache_group->{'servers'}->{'server'}}, $hcserver);
                        my $hcpserver;
                        $hcpserver->{'-type'}                                  = $checkpointtype;
                        $hcpserver->{'-name'}                                  = $checkpointname;
                        $hcpserver->{'-serverlastrequesttimeid'}               = $hcserver->{'last_request_time'}->{'obj'}->{'-id'};
                        $hcpserver->{'-servernumberofrequestsid'}              = $hcserver->{'number_of_requests'}->{'obj'}->{'-id'};
                        $hcpserver->{'-serverlaststatusmessageid'}             = $hcserver->{'last_status_message'}->{'obj'}->{'-id'};
                        $hcpserver->{'obj'}->{'-id'}                           = $objid->(('/'.$id.'/'.$cachename.'/_failover_pool/'.$poolname.'/'.$servername.'/checkpoints/'.$1.'/'.$checkpointname));
                        $hcpserver->{'obj'}->{'#text'}                         = '-';
                        push (@{$hpserver->{'checkpoint'}}, $hcpserver);
                      }
                    }

                    push(@{$hpool->{'server'}},$hpserver);
                }
            }
            push (@{$tcache_group->{'pools'}->{'pool'}}, $hpool);
        }
        push(@{$tcache->{'group'}},$tcache_group);
    }
    #push(@{$tcache->{'objects'}},$tobject);
    $tcache->{'objects'} = $tobject;
    return $tcache;
}

# format = human | number | seconds
sub timestamp (@) {
    my %args    = @_;
    my $epoch   = $args{'epoch'} || 0;
    my $format  = $args{'format'} || "human";

    return $epoch if $format eq "seconds";

    # get local time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($epoch);
    if ($sec < 10)  {  $sec = "0$sec";    }
    if ($min < 10)  {  $min = "0$min";    }
    if ($hour < 10) {  $hour = "0$hour";  }
    if ($mon < 10)  {  $mon = "0$mon";    }
    if ($mday < 10) {  $mday = "0$mday";  }
    my $month = (++$mon);
    $year = $year + 1900;

    my $timestamp;
    if ($format =~ /human/) {
        $timestamp = ($year."-".$month."-".$mday." ".$hour.":".$min.":".$sec);
    } else { # Default timestamp format  eq "number"
        $timestamp = ($year.$month.$mday.$hour.$min.$sec);
    }

    return $timestamp;
}
