#!/usr/bin/perl

my $wdr   = "/usr/local/mpp";
my $exe   = "mysql-poller.pl";
my $cache = "/usr/local/mpp/cache/mpp-cache";

unless (@ARGV >= 2) {
    die "$0 [location-code] [global-host] [global-host] [etc..]\n";
}

my $location = shift @ARGV; # pass in "site-A" or "site-B"
  die "Pass in 'site-A' or 'site-B' as your setup location.\n" if $location ne "site-A" and $location ne "site-B";
# my $globalhost = shift @ARGV;
my @globalhosts = @ARGV;

my %checkpoints = (
  'site-A' => 'internal:simple:web-1.site-A.e.org:default;edge:simple:firewall.site-A.e.org:default;external:http:www.google.com:default;external:http:www.ebay.com:default',
  'site-B' => 'internal:simple:web-2.site-B.e.org:default;edge:simple:firewall.site-B.e.org:default;external:http:www.google.com:default;external:http:www.yahoo.com:default'
);

use lib '/usr/local/mpp/lib';
use mpp_server_config;
my $mservers = mpp_server_config::config();

if ($globalhosts[0] =~ /all/i) {
    @globalhosts = (keys %{$mservers->{'global'}});
}

# my $gpool = $mservers->{'global'}->{$globalhost}->{'pool'} || undef;
my (@gpools,$ghostpools,$servers);
foreach my $globalhost (@globalhosts) {
    if (! defined $mservers->{'global'}->{$globalhost}->{'pool'}) {
        print "Global Host $globalhost does not have a defined pool! Skipping....\n";
        next;
    }
    my $gpool = $mservers->{'global'}->{$globalhost}->{'pool'};
    push (@gpools, $gpool);
    $ghostpools->{$gpool} = $globalhost;
}

foreach my $gpool (@gpools) {
    if (defined $gpool) {
        SERVER: foreach my $mserver (keys %{$mservers->{'pooled'}}) {
            PORT: foreach my $mport (keys %{$mservers->{'pooled'}->{$mserver}}) {
                next unless $mservers->{'pooled'}->{$mserver}->{$mport}->{'pool'} eq $gpool;
                next unless $mservers->{'pooled'}->{$mserver}->{$mport}->{'ploc'} eq $location;
                push(@{$servers->{$gpool}},{ ip => $mserver, port => $mport });
            }
        }
    }
}

print "\nMPP Cache Initialization\n";
#foreach my $gpool (keys %$servers) {
foreach my $gpool (@gpools) {
    print "-"x40,"\n";
    print " [",$ghostpools->{$gpool}," / ",$gpool,"]\n";
    $i = 0;
    foreach my $server (@{$servers->{$gpool}}) {
        print "  ",$i++.") ",$server->{'ip'};
        print " "x( 18 - length($server->{'ip'}) );
        print $mservers->{'pooled'}->{$server->{'ip'}}->{$server->{'port'}}->{'name'},":",$server->{'port'};
        print "\n";
    }
    print "-"x40,"\n";

    my $snum;
    until ((defined $snum) && ($snum >= 0) && (defined ${$servers->{$gpool}}[$snum])) {
        print "Select Primary Server: ";
        $snum = <STDIN>;
        chomp ($snum);
        unless (($snum >= 0) && (defined ${$servers->{$gpool}}[$snum])) {
            print "The choice $snum is not possible!\n"
        }
    }
    print "\n";

    my @cmd;
    push ( @cmd, ($wdr."/".$exe) );
    push ( @cmd, ("--cache-file=".$cache) );
    push ( @cmd, ("--cache-init") );
    my $failover_string = ("--failoverpool=\"name:".$gpool);
    my @checkpoints;
    my $i=0;
    foreach my $server (@{$servers->{$gpool}}) {
        if ($i == $snum) {
            $failover_string .= (";primary:".$server->{'ip'}.":".$server->{'port'});
        } else {
            $failover_string .= (";secondary:".$server->{'ip'}.":".$server->{'port'});
        }
        my $real_location = $mservers->{'pooled'}->{$server->{'ip'}}->{$server->{'port'}}->{'loc'};
        push (@checkpoints, ("--checkpoint=\"server:".$server->{'ip'}.":".$server->{'port'}.";".$checkpoints{ $real_location }."\"") );
        $i++
    }
    $failover_string .= "\"";
    push ( @cmd, $failover_string );
    push ( @cmd, @checkpoints );

    my $cmd = join (" ",@cmd);
    print $cmd,"\n\n";
    print `$cmd`,"\n\n";

    print "Press return to continue...";
    my $wait = <STDIN>;
}


__END__
