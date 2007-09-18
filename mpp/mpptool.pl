#!/usr/bin/perl
my $wdr   = "/usr/local/mpp";
my $exe   = "mysql-poller.pl";
my $bin   = ($wdr."/".$exe);
my $cache = "/usr/local/mpp/cache/mpp-cache";
my $location = "site-A";

use lib '/usr/local/mpp/lib';
use mpp_server_config;
my $mservers = mpp_server_config::config();

my @globalhosts = (keys %{$mservers->{'global'}});
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

sub usage {
        print "Usage: $0 [list|recover]\n";
        print "Usage: $0 list <pool-name>\n";
        print "Usage: $0 recover [site-A|site-B|all|<pool-name>] <server-name> <server-port>\n";
}


sub exe_mpp (@) {
    my @options = @_;
    open(MPP, "$bin @options|");
    while (<MPP>) {
        print;
    }
    close (MPP);
}

sub mysql_pool_list ($) {
    my $CACHE_FILE	= $cache;
    my $POOL 		= shift;
    my @options;

    if (! defined $POOL) {
        push (@options,
			"--cache-file=$CACHE_FILE",
			"--list-cached-pools"
		);
    } else {
        push (@options,
			"--cache-file=$CACHE_FILE",
			"--failoverpool=name:$POOL",
			"--list"
		);
    }
    return exe_mpp(@options);
}

sub mysql_server_recover ($$$) {
    my $CACHE_FILE	= $cache;
    my $POOL    = shift;
    my $SERVER  = shift;
    my $PORT    = shift;
    my @options;

        push (@options,
			"--cache-file=$CACHE_FILE",
			"--failoverpool=name:$POOL",
			"--recover=$SERVER:$PORT"
		);
    return exe_mpp(@options);
}

sub mysql_pool_recover ($) {
    my $CACHE_FILE	= $cache;
    my $POOL    = shift;
    my @options;

        push (@options,
			"--cache-file=$CACHE_FILE",
			"--failoverpool=name:$POOL",
			"--recover=pool:$POOL"
		);
    return exe_mpp(@options);
}

sub all_mysql_pool_recover () {
    foreach my $gpool (keys %{$servers}) {
        mysql_pool_recover($gpool);
    }
}
sub loc_mysql_server_recover ($) {
    my $location = shift;
    foreach my $gpool (keys %{$servers}) {
        foreach my $server (@{$servers->{$gpool}}) {
            next unless $mservers->{'pooled'}->{$server->{'ip'}}->{$server->{'port'}}->{'loc'} eq $location;
            mysql_server_recover($gpool, $server->{'ip'}, $server->{'port'});
        }
    }
}
sub siteA_mysql_server_recover () {
    loc_mysql_server_recover("siteA");
}
sub siteB_mysql_server_recover () {
    loc_mysql_server_recover("siteB");
}

if ($ARGV[0] eq "list") {
    my $POOL_NAME = $ARGV[1];
    mysql_pool_list($POOL_NAME);
} elsif ($ARGV[0] eq "recover") {
    my $LVS_OR_POOL = $ARGV[1];
    my $SERVER_NAME = $ARGV[2];
    my $SERVER_PORT = $ARGV[3];
    if ( defined $SERVER_NAME ) {
        if ( ! defined $SERVER_PORT ) {
            print "ERROR: You must supply a server port with the server name!";
            usage();
            exit 1;
        }
    }
    if ($LVS_OR_POOL eq "site-A") {
        all_mysql_pool_recover();
        siteA_mysql_server_recover();
    } elsif ($LVS_OR_POOL eq "site-B") {
        all_mysql_pool_recover();
        siteB_mysql_server_recover();
    } elsif ($LVS_OR_POOL eq "all") {
        all_mysql_pool_recover();
        siteB_mysql_server_recover();
        siteA_mysql_server_recover();
    } else {
        my $POOL_NAME = $LVS_OR_POOL;
        if ( defined $POOL_NAME ) {
            if ( defined $SERVER_NAME ) {
                mysql_server_recover($POOL_NAME, $SERVER_NAME, $SERVER_PORT);
            }
            mysql_pool_recover($POOL_NAME);
        } else {
            usage();
            exit 1;
        }
    }
} else {
        usage();
        exit 1;
}

$res = `chmod a+rw $cache`;
$res = `chmod a+rw $cache.log`;
