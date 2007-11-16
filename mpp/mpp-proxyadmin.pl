#!/usr/bin/perl
#
##
# mpp-proxyadmin.pl               ver1.00.000/REG     20071110
# Script to load data from MPP into MySQL Proxy.
# Or to allow administrators to manage the MPP-as-Lua
#   configuration in MySQL Proxy
##

use strict;
use Getopt::Long;

use lib '/usr/local/mpp/lib';
use mysqlpool::failover;
use mysqlpool::host::mysqlproxy;
use LogBasic;

BEGIN {
    use vars    qw($NAME $AUTHOR $VERSION $LASTMOD $DEBUG $DEBUGMSG $ERRORMSG);
    $NAME       = 'MySQL Proxy Communicator';
    $AUTHOR     = 'rglaue@cait.org';
    $VERSION    = '1.00.000';
    $LASTMOD    = 20071111;
    $DEBUG      = 0;

    use vars    qw(%options $failover_cachefile $log $failover $proxyhost);
}

sub usage (@) {
    my $mesg    = shift || undef;
    my $help    =<<HELP_EOF;
    $NAME ver $VERSION / $AUTHOR

    # For Command-line Operation
        usage: $0 [options]

    OPTIONS:
    #NI# == "Not Implemented (yet) - Sorry."
    --cache-file=/path/to/cachefile
                # The cache file the poller is manipulating the information for
    --pool=cfg_string   # The pool name only you wish to deal with
                        #  Example: --pool=mPoolA
    #NI# --initialize=node      # Initialize a single node in MySQL Proxy accoring to MPP Pool
    --initialize-all    # Initialize all nodes in MySQL Proxy according to MPP Pool
    --set=node          # Set a single node in MySQL Proxy according to MPP Pool
    --set-all           # Set all MPP Pool nodes in MySQL Proxy accoriding to MPP Pool
                #---- initialize/set options will use the data in MPP to set the nodes
    --type=TYPE         # Initialize/Set the node's type [PRIMARY|SECONDARY], disregarding MPP Pool
    --state=STATE       # Initialize/Set the node's state [ACTIVE|STANDBY|FAIL_ONLINE], disregarding MPP Pool
    --status=STATUS     # Initialize/Set the node's status [OK|INFO|WARN|CRITICAL|FAIL], disregarding MPP Pool
                #---- Specifying type/state/status will cause these to be used to set the node
                #---- rather than using what MPP has stored. However MPP will change it back to
                #---- what it knows unless you turn off the Proxy-MPP communication.
    --weight=WEIGHT     # Initialize/Set the node's weight [0-99] (Used in MPP-as-Lua but not MPP Pool)
    #NI# --promote=node      # Promote the node up one level.
                        #  i.e. from UNKNOW to STANDBY, or STANDY to ACTIVE
                        #  Promoting from STANDBY to ACTIVE causes the current ACTIVE node to be demoted
    #NI# --freeze               # Do not allow any nodes to be updated until unfreeze is called
    #NI# --unfreeze          # Unfreeze the freeze and allow nodes to be updated again
    #NI# --configure=atr:val # Configure MPP-as-Lua settings in the form of attribute:value
                        #  i.e. --configure=lbmethod:rr  - to set the load balance method to round robin
                        #  i.e. --configure=freeze:1  - to set the freeze feature on (same as --freeze)
    --show-nodes        # Show the nodes and their assignments
    #NI# --show-variables    # Show the configuration variables
    --help              # This help message

    # MySQL Proxy connection options
    --host=hostname     # MySQL Proxy host name
    --port              # MySQL Proxy port number
    --database          # MySQL Authorization database
    --username          # MySQL Authorization username
    --password          # MySQL Authorization password

HELP_EOF
    $help   .= ("\n".$mesg."\n") if defined $mesg;
    return $help;
}

GetOptions( \%options,
        "cache-file=s", "pool=s",
        "host=s",       "port=s",
        "database=s",   "username=s",   "password=s",
        "initialize-all", "set-all", "show-nodes",
        "verbose", "help"
        );
# Some defaults;
$options{'cache-file'} ||= $failover_cachefile;
$options{'host'} ||= "0.0.0.0";
$options{'port'} ||= "3306";
$options{'database'} ||= "test";
$options{'username'} ||= "default_mysql_username";
# $options{'password'} ||= "default_mysql_password";

if (! defined $options{'cache-file'}) {
    die usage("Cache file not provided!");
} elsif ((defined $options{'help'}) && ($options{'help'})) {
    die usage();
}

if (defined $options{'verbose'}) {
    $DEBUG = 1 if $DEBUG == 0;
}

$failover   = mysqlpool::failover->new(cache => {file => $options{'cache-file'}} );
$log        = LogBasic->new();
$log->load_config({ DISK => { LOGFILE => ($options{'cache-file'} . "-proxyload.log") }});
$log->connect() || die $log->error_message();
$log->process_id($$);


sub init_failover_config ($$) {
    my $failover    = shift;
    my $poolname    = shift || undef;

    if ($poolname) {
        my $config      = $failover->cached_pool_config(poolname => $poolname);
        $failover->config($config) || die ("Failure configuring pool: ".$failover->errormsg().".");
    } else {
            my $mesg =<<ERROR_EOF;
        ERROR: You need to choose a failover pool to use. Available from the cache:
ERROR_EOF
            my $mesg2 = undef;
            foreach my $pn ( @{$failover->get_cached_pool_names()} ) {
                next if ! defined $pn;
                $mesg2 .= ("\t\to ".$pn."\n");
            }
            if ((! defined $mesg2) || ($mesg2 eq "")) {
                $mesg2 .= ("\t\tNone Available\n");
            }
            $mesg .= $mesg2;
            die usage($mesg);
    }
    return $failover;
}


$failover   = init_failover_config($failover,$options{'pool'});
$proxyhost  = new mysqlpool::host::mysqlproxy( host => $options{'host'}, port => $options{'port'},
                                                username => $options{'username'}, password => $options{'password'} );

if ((defined $options{'initialize-all'}) || (defined $options{'set-all'})) {
    if ((defined $options{'initialize-all'}) && ($options{'initialize-all'})) {
        foreach my $server ( $failover->pooled_servers() ) {
            my $request_num     = $failover->number_of_requests (server => $server);
            my $request_time    = $failover->timestamp          ( time => $failover->last_request_time(server => $server), format => "human" );
            my $host_type       = $failover->host_type          (server => $server);
            my $host_status     = $failover->host_status        (server => $server);
            my $host_state      = $failover->host_state         (server => $server);
            my $status_message  = $failover->last_status_message(server => $server);
            unless ((defined $status_message) && ($status_message ne "") && ($status_message ne "\n")) {
                $status_message = undef;
            }

            print ("Initializing ".$server ." [".$host_type."] ". $host_state .": (". $host_status ."/". $request_num .") ". $status_message."\n") if $DEBUG;
            my $r = $proxyhost->initialize_node($server,"TYPE",$host_type);
            die "Cannot initialize node $server: $r." unless $r;
            if (($DEBUG) || ((exists $options{'verbode'}) && ($options{'verbode'}))) {
                foreach my $k (keys %$r) {
                    print ("initialize node $server TYPE $host_type: ".$r->{$k}."\n");
                }
            }
        }
    }
    if ((defined $options{'set-all'}) && ($options{'set-all'})) {
        foreach my $server ( $failover->pooled_servers() ) {
            my $request_num     = $failover->number_of_requests (server => $server);
            my $request_time    = $failover->timestamp          ( time => $failover->last_request_time(server => $server), format => "human" );
            my $host_type       = $failover->host_type          (server => $server);
            my $host_status     = $failover->host_status        (server => $server);
            my $host_state      = $failover->host_state         (server => $server);
            my $status_message  = $failover->last_status_message(server => $server);
            unless ((defined $status_message) && ($status_message ne "") && ($status_message ne "\n")) {
                $status_message = undef;
            }

            print ("Setting ".$server ." [".$host_type."] ". $host_state .": (". $host_status ."/". $request_num .") ". $status_message."\n") if $DEBUG;
            my $r = $proxyhost->set_node(
                                node   => $server,
                                type   => $host_type,
                                state  => $host_state,
                                status => $host_status
                                ) || die ("Cannot set node $server: ".$proxyhost->errormsg().".");
            if (($DEBUG) || ((exists $options{'verbose'}) && ($options{'verbose'}))) {
                foreach my $s (keys %$r) {
                    my $sv = $r->{$s};
                    foreach my $k (keys %$sv) {
                        print ("set node $server $s\: $sv->{$k}\n");
                    }
                }
            }
        }
    }
} elsif (defined $options{'set'}) {
    my $server = $options{'set'};
    my @sets   = qw( type state status weight );

    my $sh = {};
    foreach my $s (@sets) {
        if (defined $options{$s}) {
                $sh->{$s} = $options{$s};
        }
    }

    $sh->{'node'} = $server;
    print ("Setting node $server") if $DEBUG;
    my $r = $proxyhost->set_node(%$sh);
    if (($DEBUG) || ((exists $options{'verbose'}) && ($options{'verbose'}))) {
        foreach my $s (keys %$r) {
            my $sv = $r->{$s};
            foreach my $k (keys %$sv) {
                print ("set node $server $s\: $sv->{$k}\n");
            }
        }
    }
} elsif (defined $options{'show-nodes'}) {
    my $a = $proxyhost->show("ALL");
    my $indent = {};
    # We define this only to put the columns in a preferred order
    my @tablecol = qw (nodename group element value);

    foreach my $r (@$a) {
        foreach my $k (keys %$r) {
            if ((! $indent->{$k}) || ($indent->{$k} < length($r->{$k}))) {
                $indent->{$k} = length($r->{$k});
            }
        }
    }
    print "| ";
    foreach my $k (@tablecol) {
        print ($k." "x($indent->{$k} - length($k))." | ");
    }
    print "\n";
    foreach my $r (@$a) {
        print "| ";
        foreach my $k (@tablecol) {
            print ($r->{$k}." "x($indent->{$k} - length($r->{$k}))." | ")
        }
        print "\n";
    }
}



__END__

