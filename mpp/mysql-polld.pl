#!/usr/bin/perl
#
##
# mysql-polld.pl                ver1.00.000/REG     20071126
# Script to run polling process in a daemonised way.
##

use strict;
use Getopt::Long;

use lib '/usr/local/mpp/lib';
use mysqlpool::failover;
use mysqlpool::host::mysqlproxy;
use LogBasic;

BEGIN {
    use vars    qw($NAME $AUTHOR $VERSION $LASTMOD $DEBUG $DEBUGMSG $ERRORMSG);
    $NAME       = 'MPP Poll Daemon';
    $AUTHOR     = 'rglaue@cait.org';
    $VERSION    = '1.00.000';
    $LASTMOD    = 20071126;
    $DEBUG      = 1;

    use vars    qw($pollInterval $pollThreshold $maxRequests $requestLevel);
    $pollInterval   = 10; # time in seconds
    $pollThreshold  = (($pollInterval - ($pollInterval % 3)) / 3 );
    $maxRequests    = 4;
    $requestLevel	=	{
				0 => 'OK',
				1 => 'OK INFO',
				2 => 'OK WARN',
				3 => 'OK CRITICAL',
				4 => 'FAIL CRITICAL',
				};

    use vars    qw(%options $failover_cachefile $log $failover $pid_file);
    $failover_cachefile = "/usr/local/mpp/cache/mpp-cache";  # set a default

    # Set global variables for hooks
    # hook_mysqlproxy
    use vars    qw($proxyhost);
}

sub usage (@) {
    my $mesg    = shift || undef;
    my $help    =<<HELP_EOF;
    $NAME ver $VERSION / $AUTHOR

    # For Command-line Operation
        usage: $0 [options]

    OPTIONS:
    --cache-file=/path/to/cachefile
                        # The cache file the poller is manipulating the
                        # information for
    --poll=pool_name    # Poll the servers in the specified failover pool,
                        # updating their statuses and states.
    --poll-cached-pools # Poll all failover pools currently existing in the cache

                        # For both --poll and --poll-cached-pools, the
                        # failoverpool configuration is retrieved from the cache
                        # and thus must first be initialized before calling it
                        # in this application tool.

    --interval          # The interval between polling cycles
                        # In other words, how often to poll the MySQL nodes?
    --threshold         # The threshold of time we allow a polling cycle to creep
                        # into the next cycle before skipping a cycle
                        # If a polling cycle takes interval+n time to poll all the
                        # MySQL nodes and interval+n > interval+threshold, this 
                        # application will skip to the next polling cycle rather
                        # than try and squeeze in the currently scheduled one.
                        # This defaults to interval/3 rounded down.

    # MySQL connection options
    --database          # MySQL Authorization database
    --username          # MySQL Authorization username
    --password          # MySQL Authorization password

    # MySQL Proxy connection options
    --proxyhost         # MySQL Proxy Host Address
    --proxyport         # MySQL Proxy Port Number
    --proxyuser         # MySQL Authorization username
    --proxypass         # MySQL Authorization password

HELP_EOF
    $help   .= ("\n".$mesg."\n") if defined $mesg;
    return $help;
}


#
# Process the Options list
#
GetOptions( \%options,
        "cache-file=s", "pool=s",      "poll-cached-pools",
        "interval=i",   "threshold=i",
        "database=s",   "username=s",  "password=s",
        "proxyhost=s",  "proxyport=i", "proxyuser=s", "proxypass=s",
        "verbose",      "help"
        );
# Some defaults;
$options{'cache-file'} ||= $failover_cachefile;
$options{'database'}   ||= "test";
$options{'username'}   ||= "default_mysql_username";
#$options{'password'}   ||= "default_mysql_password"; # uncomment to set a default
#$options{'proxyhost'}  ||= "0.0.0.0";
#$options{'proxyport'}  ||= "3306";
# Only set these options if we have received input for the --proxyhost option
if (exists $options{'proxyhost'}) {
    # This does not allow for a MySQL user to authenticate without a password
    # To authenticate without a password, comment out the proxypass option below
    $options{'proxyuser'}  ||= $options{'username'};
    $options{'proxypass'}  ||= $options{'password'};
}

if (! defined $options{'cache-file'}) {
    die usage("Cache file not provided!");
} elsif ((!defined $options{'poll'}) && (!defined $options{'poll-cached-pools'})) {
    die usage("A polling option was not selected");
} elsif ((defined $options{'help'}) && ($options{'help'})) {
    die usage();
}

if (defined $options{'verbose'}) {
    $DEBUG = 1 if $DEBUG == 0;
}

if (defined $options{'interval'}) {
    $pollInterval = $options{'interval'};
}
if (defined $options{'threshold'}) {
    $pollThreshold = $options{'threshold'};
}
if ((defined $options{'interval'}) && (! defined $options{'threshold'})) {
    $pollThreshold  = (($pollInterval - ($pollInterval % 3)) / 3 );
}


#
# Initialize some globally used items
#
$failover   = mysqlpool::failover->new(cache => {file => $options{'cache-file'}} );
$log        = LogBasic->new();
$log->load_config({ DISK => { LOGFILE => ($options{'cache-file'} . "-polld.log") }});
$log->connect() || die $log->error_message();
$log->process_id($$);
$pid_file=($options{'cache-file'} . "-polld.pid");
open(PID_FILE,">$pid_file");
print PID_FILE $$;
close(PID_FILE);


# Call this instead of just exit so we can do some clean up
# This is called via sig_exit if the user send ctrl-C or kills this running process
sub stat_exit ($) {
    my $exitval	= shift || 0;
    if ($failover->cache_store()) {
        warn ("Cache stored in file: ",$failover->cache_file(),"\n") if $DEBUG >= 2;
    } else {
        warn ("Could not save cache file: ".$failover->cache_file()."!\n");
    }
    $log->disconnect();  # Disconnect/Destroy LogBasic
    unlink $pid_file || warn ("Could not delete pid_file: ".$pid_file."\n");    # Delete the pid file
    exit $exitval;
}

# We have to exist unexpectedly, display description message and call stat_exit()
sub unexpected_exit ($) {
    my $msg = shift;
    warn $msg;
    stat_exit(1);
}

# print a debug message if $DEBUG
sub debugmsg (@) {
    my $DEBUG_LEVEL = $DEBUG;
    return 1 unless $DEBUG_LEVEL > 0;
    $DEBUGMSG   = join("\n",@_) || return $DEBUGMSG || return undef;
    warn $DEBUGMSG,"\n";
}

# Catch a ctrl-C, cleanup and exit
sub sig_exit {
    my $sig = shift;
    debugmsg (("Cleaning up, catching ".$sig.".\n"));
    stat_exit(0);
}
$SIG{'INT'} = \&sig_exit;

# store up and pront out application error messages
sub errormsg (@) {
    debugmsg(@_);
    if (@_ >= 1) {
        $ERRORMSG   = join("\n",@_);
    } else {
        
        $ERRORMSG || return undef;
    }
}

# fataly exit from code routines, concating error messages and passing to errormsg()
sub fatalerror (@) {
    my @msg = (errormsg(),@_);
    errormsg(@msg);
    return undef;
}

# Initialize a failover object
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


# Poll the servers of the MPP MySQL pools
sub poll_failover_pool (@) {
    my %args            = @_;
    my $failover        = $args{'failover'}     || return undef;
    my $dbopt           = $args{'dbopt'}        || return undef;
    my $maxRequests     = $args{'maxRequests'}  || return undef;
    my $requestLevel    = $args{'requestLevel'} || return undef;
    my $log             = $args{'log'}          || return undef;

    my $pool_name       = $failover->pool_name();
    my $poolstatus      = $failover->cached_pool_status( poolname => $pool_name );

    my $logcheckpoint;
    foreach my $mhost (@{ $failover->primary_servers() }, @{ $failover->secondary_servers() }) {
        warn "Polling host checkpoints: ",$mhost,"\n" if $DEBUG >= 2;
        my ($mhostname,$mhostport) = split(":",$mhost);
        my $mysql   =   $failover->get_failover_host(
            server      => $mhost,
            options     => $dbopt
        );

        unless (defined $mysql) {
            warn ("ERROR: MySQL host object for ".$mhost." could not be created!\n"
                    ."Skipping this host...");
            next;
        }
        my $pstatus =   $failover->decipher_checkpoints( host => $mysql );

        # If the pool status is FAIL, we will leave it as FAIL.
        if ((! defined $poolstatus) || ($poolstatus ne "FAIL")) {
            $poolstatus = $pstatus->{'pool'};
            $failover->cached_pool_status( poolname => $pool_name, status => $poolstatus );
        }

        if ((defined $pstatus->{'message'}) && ($pstatus->{'message'} ne "") && ($pstatus->{'message'} =~ /\w/)) {
            $logcheckpoint  .= $pstatus->{'message'} if $pstatus->{'message'};
        }
    }
    if ((defined $logcheckpoint) && ($logcheckpoint ne "") && ($logcheckpoint =~ /\w/)) {
        $log->log_warn(("POLL CHECK (".$pool_name.")"),("POOL STATUS: ".$poolstatus),$logcheckpoint);
    } else {
        $log->log_info(("POLL CHECK (".$pool_name.")"),("POOL STATUS: ".$poolstatus));
    }

    my $loginfo;
    foreach my $mhost (@{ $failover->primary_servers() }, @{ $failover->secondary_servers() }) {
        warn "Polling host: ",$mhost,"\n" if $DEBUG >= 2;
        my ($mhostname,$mhostport) = split(":",$mhost);
        my $mysql   =    mysqlpool::host::mysql->new(
            host        => $mhostname,
            port        => $mhostport,
            database    => $dbopt->{'database'},
            username    => $dbopt->{'username'},
            password    => $dbopt->{'password'}
        );
        unless (defined $mysql) {
            warn ("ERROR: MySQL host object for ".$mhost." could not be created!\n"
                    ."Skipping this host...");
            next;
        }

        my $result  =   $failover->decipher_failover(   server          => $mysql,
                                                        failover        => $failover,
                                                        maxrequests     => $maxRequests,
                                                        requestlevel    => $requestLevel,
                                                        hostileTakeover => 0,
                                                        poolstatus      => $poolstatus
                                                    );
        unless (defined $result) {
            my $pollermsg = $failover->errormsg();
            warn ("ERROR: Failed polling host: ".$mhost."\n"
                    .$pollermsg."\n"
            ) if $DEBUG;
        }
    
        # Report status to output
        my $mysqlserver     = $mhost;
        my $status_level;
        my $thishost_req    = $failover->number_of_requests(server => $mysqlserver);
        my $status_mesg     = $failover->last_status_message(server => $mysqlserver);
        if ($thishost_req >= $maxRequests) {
            $status_level   = $maxRequests;
        } else {
            $status_level   = $thishost_req;
        }
        my $out;
        if ((defined $status_mesg) && ($status_mesg ne "") && ($status_mesg ne "\n")) {
            $out =  (
                    $requestLevel->{$status_level}  .
                    "/"                             .
                    $thishost_req .": "             .
                    "(". $mysqlserver .") "         .
                    $status_mesg                    .
                    "\n");
            $loginfo .= $out;
        } else {
            $out =  (
                    $requestLevel->{$status_level}  .
                    "/"                             .
                    $thishost_req .": "             .
                    "(". $mysqlserver .") "         .
                    "\n");
        }

        print $out if $DEBUG;
    }

    my $active_server   = @{ $failover->host_state( state => "ACTIVE" ) }[0] || "NONE";
    my $active_type_msg = "";
    unless ($active_server eq "NONE") {
        $active_type_msg .= (" (".$failover->host_type( server => $active_server ).")");
    }
    if ((defined $loginfo) && ($loginfo ne "") && ($loginfo =~ /\w/)) {
        $log->log_warn(("POLL CYCLE (".$pool_name.")"),("POOL STATUS: ".$poolstatus."; ACTIVE: ".$active_server . $active_type_msg),$loginfo);
    } else {
        $log->log_info(("POLL CYCLE (".$pool_name.")"),("POOL STATUS: ".$poolstatus."; ACTIVE: ".$active_server . $active_type_msg));
    }
}


# part of the hook_mysqlproxy
# routine to set MPP evaluations into MySQL Proxy
sub set_mysql_proxy (@) {
    my %args            = @_;
    my $host            = $args{'proxyhost'}    || $options{'proxyhost'} || return undef;
    my $port            = $args{'proxyport'}    || $options{'proxyport'} || return undef;
    my $username        = $args{'proxyuser'}    || $options{'proxyuser'} || return undef;
    my $password        = $args{'proxypass'}    || $options{'proxypass'} || undef;
    my $failover        = $args{'failover'}     || return undef; # object set to desired pool
    # my $failoverpool    = $args{'pool'}         || return undef;
    my $initialize_all  = $args{'initialize_all'} || undef;
    my $set_all         = $args{'set_all'}        || undef;

    # $failover   = init_failover_config($failover,$failoverpool);
    if (!defined $proxyhost) {
        $proxyhost  = new mysqlpool::host::mysqlproxy( host => $host,         port => $port,
                                                       username => $username, password => $password )
                                                       || return fatalerror ("Could not connect to MySQL Proxy.");
    }

    sub _initialize ($$) {
        my $proxyhost = shift || return undef;
        my $failover  = shift || return undef;
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
            my $r = $proxyhost->initialize_node($server,"TYPE",$host_type)
                                  || return fatalerror("Cannot initialize node $server: ",$proxyhost->errormsg());
            if ($DEBUG) {
                foreach my $k (keys %$r) {
                    debugmsg("initialize node $server TYPE $host_type: ".$r->{$k});
                }
            }
        }
        return 1;
    }

    sub _set ($$) {
        my $proxyhost = shift || return undef;
        my $failover  = shift || return undef;
        SERVER: foreach my $server ( $failover->pooled_servers() ) {
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
                                ) || return fatalerror("Cannot set node $server: ".$proxyhost->errormsg().".");
            foreach my $s (keys %$r) {
                my $sv = $r->{$s};
                foreach my $k (keys %$sv) {
                    if ($DEBUG) {
                        debugmsg ("set node $server $s\: $sv->{$k}");
                    }
                    if ($sv->{$k} =~ /uninitialized\snode/i) {
                        _initialize($proxyhost,$failover);
                        _set($proxyhost,$failover);
                        next SERVER;
                    }
                }
            }
        }
        return 1;
    }

    if ((defined $args{'initialize_all'}) && ($args{'initialize_all'})) {
        _initialize($proxyhost,$failover)
    }
    if ((defined $args{'set_all'}) && ($args{'set_all'})) {
        _set($proxyhost,$failover)
    }
    return 1;
}


# hook called inside a polling iteration to execute mysqlproxy specific stuff
# This is a hard-coded hook, obviously
sub hook_mysqlproxy($) {
    debugmsg("hook_mysqlproxy: begin");
    my $failover    = shift;
    if ((exists $options{'proxyhost'}) && (defined $options{'proxyhost'})) {
        debugmsg("Setting MySQL Proxy...");
        set_mysql_proxy(
            failover => $failover,
            set_all => 1
        ) || debugmsg("Could not set proxy!");
    }
    debugmsg("hook_mysqlproxy: end");
}


#
# The MPP Polling Iterations
#

# We use $n for showing us some debug information
my $n = 0 if $DEBUG;
my $init_time = time() if $DEBUG;
print ("Entering Cycles...\n") if $DEBUG;

my ($start_time, $end_time, $run_time, $sleep_time);
while (1) {
    $start_time = time();
    print ("-- Interval Drift: ".($start_time - ($init_time + ($pollInterval * $n)))." sec, (actual:".$start_time."/scheduled:".($init_time + ($pollInterval * $n)).") --\n") if $DEBUG;
    print ("[Iteration: ".++$n."]\n") if $DEBUG;

    $failover->cache_retrieve() || enexpected_exit("Could not open cache file: ".$failover->cache_file()."!\n");
    if ((exists $options{'poll-pool'}) && (defined $options{'poll-pool'})) {
        $failover   = init_failover_config($failover,$options{'poll-pool'});
        poll_failover_pool(
            failover        => $failover,
            dbopt           => {    database    => $options{'database'},
                                    username    => $options{'username'},
                                    password    => $options{'password'}
                               },
            maxRequests     => $maxRequests,
            requestLevel    => $requestLevel,
            log             => $log
        );

        $failover->cache_store()
          || enexpected_exit("Could not save cache file: ".$failover->cache_file()."!\n");
        warn "Cache stored in file: ",$failover->cache_file(),"\n" if $DEBUG >= 2;
        hook_mysqlproxy($failover);
    # } elsif (exists $options{'poll-cached-pools'}) {
    } else {
        foreach my $pn ( @{$failover->get_cached_pool_names()} ) {
            $failover           = init_failover_config($failover,$pn);
            poll_failover_pool(
                failover        => $failover,
                dbopt           => {    database    => $options{'database'},
                                        username    => $options{'username'},
                                        password    => $options{'password'}
                                   },
                maxRequests     => $maxRequests,
                requestLevel    => $requestLevel,
                log             => $log
                );
            $failover->cache_store()
              || enexpected_exit("Could not save cache file: ".$failover->cache_file()."!\n");
            warn "Cache stored in file: ",$failover->cache_file(),"\n" if $DEBUG >= 2;
            hook_mysqlproxy($failover);
        }
    }
    $end_time = time();
    $run_time = $end_time - $start_time;
    if ($run_time < 1) {
        # Wow, under a second, that was fast!
        $sleep_time = $pollInterval;
    } elsif ($run_time > ($pollInterval + $pollThreshold)) {
        # skip an iteration since we have crossed the threshold of time
        # intervals are allowed to go over in processing time
        my $next_interval = $pollInterval;
        until ($next_interval > $run_time) {
            $next_interval += $pollInterval;
        }
        $sleep_time = ($next_interval - $run_time);
    } else {
        # we have not crossed the threshold so we will sleep until the next
        # interval start time
        $sleep_time = ($pollInterval - $run_time);
        # or not sleep at all if the next interval was already supposed to start
        $sleep_time = 0 if $sleep_time < 0;
    }
    print ("[Sleeping ".$sleep_time." seconds]\n") if $DEBUG;
    if ($sleep_time) {
        # Sleep until the next scheduled interval
        sleep($sleep_time) || unexpected_exit("MPP+System Error: Cannot sleep!");
    }
    # reset our time markers
    $start_time = 0;
    $end_time   = 0;
    $sleep_time = 0;
    print ("[Iteration ".$n." ended]\n") if $DEBUG;
}


stat_exit(0);

__END__

