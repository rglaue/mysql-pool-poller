#!/usr/bin/perl
#
##
# mysql-poller.pl               ver1.00.000/REG     20051214
# Script to poll a pool of servers and report their statuses.
##

use strict;
use Getopt::Long;

# use lib '/usr/local/lib-monitor/mysqlfailoverpool';
use mysqlpool::failover;
use mysqlpool::host::mysql;
use CGIbasic;
use LogBasic;

BEGIN {
    use vars    qw($NAME $AUTHOR $VERSION $LASTMOD $DEBUG $DEBUGMSG $ERRORMSG);
    $NAME       = 'MySQL Poller';
    $AUTHOR     = 'rglaue@cait.org';
    $VERSION    = '1.00.000';
    $LASTMOD    = 20051214;
    $DEBUG      = 0;

    use vars    qw($maxRequests $timeBetweenRequests $requestLevel);
    $maxRequests            = 5;
    $timeBetweenRequests    = 30; # time in seconds # Not used!
    # INFO: not important, but and could be left unnoted
    # WARN: somewhat important, perhaps notify, and might be noted
    # SOFT: important, notify, something is wrong and should be looked at
    # HARD: very important, notify, do something or there failure procedure will be taken
    # FAIL: failure has occurred, failure procedure is to commence 
    $requestLevel	=	{
				0 => 'OK',
				1 => 'OK INFO',
				2 => 'OK WARN',
				3 => 'OK SOFT',
				4 => 'OK HARD',
				5 => 'FAIL CRITICAL',
				};

    use vars	qw($cachefile_dir $cachefile_prefix $cachefile_cacheid $failover_cachefile);
    $cachefile_dir          = "/tmp";
    $cachefile_prefix       = "cache_mysql_";
    $cachefile_cacheid      = "_monitor";
    $failover_cachefile     = ( $cachefile_dir ."/".  $cachefile_prefix."failover".$cachefile_cacheid );

    use vars    qw(%HTTP_CONFIG %options $failover $log);
    %HTTP_CONFIG    = (
                        cache   =>  {
                                        default     => "poolcache1",
                                        poolcache1  => $failover_cachefile,
                                        local       => ($failover_cachefile."-local"),
                                        global      => ($failover_cachefile."-global"),
                                        test        => ($failover_cachefile."-test")
                                    },
                        options =>  [ qw (
                                        list
                                        list-pool
                                        list-cached-pools
                                        report
                                        is-active
                                    ) ]
                      );
}

sub usage (@) {
    my $mesg    = shift || undef;
    my $help    =<<HELP_EOF;
    $NAME ver $VERSION / $AUTHOR
    
    # For Command-line Operation
        usage: $0 [options]
    
    OPTIONS:
    --cache-file=/path/to/cachefile # The cache file the poller is manipulating the information for
    --cache-init                    # Initialize/Reinitialize the cache file and failover pool configuration
    --cache-dump                    # Dump the cache to console
    --failoverpool=cfg_string       # Configuration string of the failover pool
                                    #  Example: name:mPoolA;primary:server1:3306;secondary:server2:3306;etc..
                                    #  The keys being 'name','primary', and 'secondary'
                                    #  Default is to attempt to get the configuration from the cache file
                                    #  You will need to at least specifiy the 'name=<poolname>' so this
                                    #  script knows which pool it is polling for except when utilizing the
                                    # --poll-pool=pool_name or --poll-cached-pools options
    --checkpoint=cfg_string         # Configuration string for a failover server checkpoint
                                    #  Example: server:server1:3306;internal:simple:dnsserver1:default;external:http:google.com:80
                                    #  The keys being 'server', 'internal', 'edge', 'external'
                                    #  Default is to have no checkpoints for any server.
                                    #  If a server has a checkpoint defined, they will all be attempted to be reached
                                    #  before deciphering the server's state in the pool. If The server cannot be reached
                                    #  the checkpoints will be tried. If no checkpoints can be reached, the pool is considered
                                    #  to be in a FAIL state. The external checkpoint should be reachable for the pool' state
                                    #  to remain in an OK state. The internal and edge checkpoints are used to determine
                                    #  what type of fail state the server is considered to be in.
    --poll                          # Poll failover pool as defined in --failoverpool configuration
    --poll-pool=pool_name           # Poll the servers in the specified failover pool, updating their statuses and states
                                    #  "failoverpool" configuration is retrieved from the cache for the specified pool
    --poll-cached-pools             # Poll all failover pools currently existing in the cache
                                    #  "failoverpool" configuration is retrieved from the cache for each cached pool
    --list                          # List the servers cached with stored number of requests
    --list-pool=pool_name           # same as --list, but lists the specified pool. --failoverpool config is not used
    --list-cached-pools             # same as --list but lists servers from all pools found in the cache
    --is-active=servername:portnum  # Report if given server is currently active in the failover pool
                                    #  useful if used in LVS/Pirahna to determine if server is "UP"
    --report=servername:portnumber  # Return the status based on what is in the cache
                                    #  previously: --report-from-cache
    --recover=servername:portnumber # Reset current cached response level to 0
                                    #  This is used when a failover has occured, and you want
                                    #  to restore the status of the master or a slave to OK
                                    #  previously: --reset-cached-level
    --activate-primary              # Change state of PRIMARY to ACTIVE (used after recovery to reinstate from STANDBY)
    --delete=servername:portnumber  # Removes a server from the cached response levels
                                    #  previously: --delete-cached-server
    --test-http=URI                 # Used if you wish to test the HTTP response from the command line
                                    #  Ex: --test-http=/cache=default/pool=pool1/report=server1:3306
    --help                          # This help message

    # For Pirahna/LVS or Nagios Monitoring
        usage: http://server/mysql-poller.pl/{cache_id}/{pool_name}?[option][=[value]][&[option][=[value]]]

    OPTIONS:
    /{cache_id}/                    # required: use a cache file configured in the scripts internal configuration
    /{pool_name}/                   # required: use a specified pool of the cache file 
    ?list                           # Same as --list, but response is a plain/text HTTP response for web output
    ?list-pool                      # Same as --list-pool, but response is a plain/text HTTP response for web output
    ?list-cached-pools              # Same as --list-cached-pools, but response is a plain/text HTTP response for web output
    ?report=servername:portnumber   # Same as --report, but response is a plain/text HTTP response for web output
    ?is-active=servername:portnum   # Same as --is-active, but response is a plain/text HTTP response for web output

HELP_EOF
    $help   .= ("\n".$mesg."\n") if defined $mesg;
    return $help;
}

GetOptions( \%options,
        "cache-file=s", "cache-init",       "cache-dump",
        "failoverpool=s", "checkpoint=s@",
        "poll",         "poll-pool=s",      "poll-cached-pools",
        "list",         "list-pool=s",      "list-cached-pools",
        "is-active=s",  "report=s",
        "recover=s",    "activate-primary", "delete=s",
        "database=s",   "username=s",       "password=s",
        "test-http=s",  "help",
        );
# Some defaults;
$options{'cache-file'} ||= $failover_cachefile;
$options{'database'} ||= "test";
#$options{'username'} ||= "MySQLmonitor";
#$options{'password'} ||= "MySQLmonitor0903";
$options{'username'} ||= "rglaue";
$options{'password'} ||= "wof8cet6";


if (
       ((exists $options{'test-http'}) && (defined $options{'test-http'}))
    || ((exists $ENV{'PATH_INFO'}) && (defined $ENV{'PATH_INFO'}))
    ||  (exists $ENV{'SERVER_NAME'})
    )
{
    print "Content-type: text/plain\n\n";
    if (defined $options{'test-http'}) {
        ($ENV{'PATH_INFO'},$ENV{'QUERY_STRING'}) = split(/\?/,$options{'test-http'});
    }
    my $exe_ok_flag = 0;
    if (defined $ENV{'PATH_INFO'}) {
        my $input_string    = $ENV{'PATH_INFO'};
           $input_string    =~ s/^\///;
           $input_string    =~ s/\/$//;
        my @elements = split(/\//,$input_string);
        if (@elements == 2) {
            # CACHE
            my $cache_id;
            my $default_id  = "default";
            if ($elements[0] eq $default_id) {
                $cache_id   = $HTTP_CONFIG{'cache'}{$default_id};
            } else {
                $cache_id   = $elements[0];
            }
            $options{'cache-file'} = $HTTP_CONFIG{'cache'}{$cache_id};
            # POOL
            $options{'failoverpool'} = ("name:".$elements[1]);
            # OPTIONS
            my $IN = CGIbasic::getcgi();
            KEY: foreach my $key (keys %$IN) {
                OPT: foreach my $opt (@{ $HTTP_CONFIG{'options'} }) {
                    if ($key eq $opt) {
                        $exe_ok_flag = 1;
                        my $val = $IN->{$opt};
                           $val = 1 if ! defined $val;
                        $options{$opt} = $val;
                        next KEY;
                    }
                }
                $exe_ok_flag = 0;  # EXE denied because KEY does not match any allowed OPTs
                last KEY;
            }
        }
    }
    if ($exe_ok_flag == 0) {
        print ("ERROR: Request Not Recognized: ".$ENV{'PATH_INFO'}." - ".$ENV{'QUERY_STRING'}."\n");
        exit 0;
    }
}

if (! defined $options{'cache-file'}) {
    die usage("Cache file not provided!");
} elsif ((defined $options{'help'}) && ($options{'help'})) {
    die usage();
}

$failover   = mysqlpool::failover->new(cache => {file => $options{'cache-file'}} );
$log        = LogBasic->new();
$log->load_config({ DISK => { LOGFILE => ($options{'cache-file'} . ".log") }});
# Web HTTP Requests will fail if LOG file is not writable by HTTP process uid
# chmod(($options{'cache-file'} . ".log"),"777");
# or, if all options are available to web, do not load $LOG.
$log->connect() || die $log->error_message();
$log->process_id($$);


#
# handle the exit here to ensure cache gets saved
#
sub stat_exit ($) {
    my $exitval	= shift || 0;
    $failover->cache_store() || die ("Could not save cache file: ".$failover->cache_file()."!\n");
    warn "Cache stored in file: ",$failover->cache_file(),"\n" if $DEBUG >= 2;
    $log->disconnect();
    exit $exitval;
}


sub init_checkpoint_config ($$) {
    my $failover    = shift;
    my $config_str  = shift;

    if ( split(';',$config_str) > 1) {
        $failover->config_checkpoint($config_str)
            || die ("Failure with checkpoint configuration ($config_str): ".$failover->errormsg().".");
    } else {
        if ($config_str =~ /server\:([^\;]*)/i) {
            my $server      = $1;
            my $config      = $failover->cached_checkpoint_config( server => $server );
            $failover->config_checkpoint($config)
                || die ("Failure with checkpoint configuration ($config): ".$failover->errormsg().".");
        } else {
            die usage("The checkpoint configuration ($config_str) was not formatted properly or did not define a server.");
        }
    }

    return $failover;
}

sub init_failover_config ($$$) {
    my $failover    = shift;
    my $config_str  = shift;
    my $chkpnt_cfg  = shift || undef;

    if ( split(';',$config_str) > 1 ) {
        $failover->config($config_str);
    } else {
        if ($config_str =~ /name:([^\:\;]*)/i) {
            my $poolname    = $1;
            my $config      = $failover->cached_pool_config(poolname => $poolname);
            $failover->config($config);
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
    }
    if (defined $chkpnt_cfg) {
        foreach my $checkpoint_config (@{ $chkpnt_cfg }) {
            init_checkpoint_config($failover,$checkpoint_config);
        }
    }

    return $failover;
}

##########
#
# Deal with the cache init and polling calls
#
if ($options{'cache-init'} == 1) {
    $failover   = init_failover_config($failover,$options{'failoverpool'},$options{'checkpoint'});
    foreach my $server ($failover->pooled_servers()) {
        $failover->server_delete(server => $server) || die ("Error: ".$failover->errormsg()."\n");
    }
    print "Initializing cache.\n";
    $failover   = init_failover_config($failover,$options{'failoverpool'},$options{'checkpoint'});
    stat_exit(0);

} elsif ($options{'cache-dump'} == 1) {
    print "---- CACHE -----\n";
    print $failover->cache_dump();
    print "---- CACHE -----\n";
    exit 0;

} elsif ((exists $options{'poll-pool'}) && (defined $options{'poll-pool'})) {
    my $config_string   = ("name:".$options{'poll-pool'});
    $failover   = init_failover_config($failover,$config_string,$options{'checkpoint'});
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
    stat_exit(0);
} elsif (exists $options{'poll-cached-pools'}) {
    foreach my $pn ( @{$failover->get_cached_pool_names()} ) {
        my $config_string   = ("name:".$pn);
        $failover           = init_failover_config($failover,$config_string,$options{'checkpoint'});
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
    }
    stat_exit(0);
} elsif (exists $options{'poll'}) {
    $failover           = init_failover_config($failover,$options{'failoverpool'},$options{'checkpoint'});
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
    stat_exit(0);

#
# end cache init and polling routines
#
##########
##########
#
# Deal with listing calls
#

} elsif ($options{'list-cached-pools'} == 1) {
    list_failover_pool      (
                            failover        => undef,
                            show_header     => 1,
                            show_poolname   => 0,
                            show_servers    => 0,
                            space_tab       => 0,
                            space_indent    => 2
                            );
    foreach my $pn ( @{$failover->get_cached_pool_names()} ) {
        my $config_string   = ("name:".$pn);
        $failover   = init_failover_config($failover,$config_string,$options{'checkpoint'})
            || die ("Could not initialize failover pool with configuration (".$config_string.").");
        list_failover_pool  (
                            failover        => $failover,
                            show_header     => 0,
                            show_poolname   => 1,
                            show_servers    => 1,
                            space_tab       => 0,
                            space_indent    => 2
                            );
    }
    exit 0;
} elsif ((exists $options{'list-pool'}) && (defined $options{'list-pool'})) {
    my $config_string   = ("name:".$options{'list-pool'});
    $failover   = init_failover_config($failover,$config_string,$options{'checkpoint'})
        || die ("Could not initialize failover pool with configuration (".$config_string.").");
    list_failover_pool      (
                            failover        => $failover,
                            show_header     => 1,
                            show_poolname   => 0,
                            show_servers    => 1,
                            space_tab       => 0,
                            space_indent    => 2
                            );
    exit 0;

# List all the server in the cache, and what their last status was
} elsif ($options{'list'} == 1) {
    $failover   = init_failover_config($failover,$options{'failoverpool'},$options{'checkpoint'})
        || die ("Could not initialize failover pool with configuration (".$options{'failoverpool'}.").");
    list_failover_pool      (
                            failover        => $failover,
                            show_header     => 1,
                            show_poolname   => 0,
                            show_servers    => 1,
                            space_tab       => 0,
                            space_indent    => 2
                            );
    exit 0;
}
#
# end listing routines
#
##########

$failover   = init_failover_config($failover,$options{'failoverpool'},$options{'checkpoint'});

##########
#
# Deal with the cache only and exit if we are called to do it
#
# Report the status of a server as it is recorded in the cache
if (defined $options{'is-active'}) {
    my $servername      = $options{'is-active'};
    if ( $failover->host_state( server => $servername, state => "ACTIVE" ) ) {
        print "OK\n";
        exit 0;
    } else {
        print "NO\n";
        exit 1;
    }

} elsif (defined $options{'report'}) {
    my $servername      = $options{'report'};
    my $reqlevel        = $failover->number_of_requests(server => $servername);
    my $request_num	    = $failover->number_of_requests(server => $servername);
    my $status_message	= $failover->last_status_message(server => $servername);
    my $server_status   = $failover->host_status(server => $servername);
    my $server_state    = $failover->host_state(server => $servername);

    if ($reqlevel >= $maxRequests)
        {
        $reqlevel = $maxRequests;
        }
    if (defined $status_message)
        {
        print ($requestLevel->{$reqlevel} ."/". $request_num .": (". $server_status ."/". $server_state .") ". $status_message."\n");
        }
      else
        {
        print ($requestLevel->{$reqlevel} ."\n");
        }
    # stat_exit(0);
    exit 0;

# Reset the cached request level of a particular server
} elsif (defined $options{'recover'}) {
    my $servername      = $options{'recover'};
    my $oldlevel        = $failover->number_of_requests(server => $servername);
    if (! defined $oldlevel) {
        print "Server $servername requests number not set.";
        stat_exit(0);
    }
    $failover->number_of_requests(server => $servername, requests => 0);
    $failover->last_status_message(server => $servername, message => "Manual Recovery Initiated.");
    $failover->failover_state(server => $servername, state => "UNKNOWN");
    $failover->failover_status(server => $servername, status => "OK_WARN");
    print ("OK: Cached level reset from ".$oldlevel." to ".
            $failover->number_of_requests(server => $servername)." for ".$servername."\n");
    stat_exit(0);

# Reinstate type=PRIMARY as state=ACTIVE, but only if current state=STANDBY
} elsif ((defined $options{'activate-primary'}) && ($options{'activate-primary'} == 1)) {
    my $servername      = ${$failover->primary_servers()}[0];
    unless ($failover->primary_state("STANDBY")) {
        die "PRIMARY SERVER $servername IS NOT READY. STATE must be STANDBY for activation.\n"; 
    }
    $failover->failover_state(server => $servername, state => "ACTIVE")
        && print ("PRIMARY SERVER $servername STATE is now ACTIVE.\n");
    $failover->last_status_message(server => $servername, message => "PRIMARY Manually reinstated as ACTIVE.");
    stat_exit(0);

# Remove a particular server entry from the cache
} elsif (defined $options{'delete'}) {
    my $servername      = $options{'delete'};
    my $oldlevel        = $failover->number_of_requests(server => $servername);
    $failover->server_delete(server => $options{'hostport'});
    print ("OK: Cached server ".$options{'hostport'}." with ".$oldlevel." request attempts was deleted.\n");
    stat_exit(0);
}
#
# end cache reading routines
#
##########

die usage();

sub list_failover_server_checkpoints (@) {
    my %args            = @_;
    my $failover        = $args{'failover'};
    my $server          = $args{'server'};
    my $show_header     = $args{'show_header'} || 0;
    my $show_servername = $args{'show_servername'} || 0;
    my $show_servers    = $args{'show_servers'};
    $show_servers       = 1 unless defined $show_servers;
    my $space_tab       = $args{'space_tab'};
    $space_tab          = 2 unless defined $space_tab;
    my $space_indent    = $args{'space_indent'};
    $space_indent       = 1 unless defined $space_indent;

    my %column      = (
        indent_space    => $space_indent,
        col_number      => 7,
        space           => [
            qw(1 6 3 20 45 33)
            ],
        title           => [
            "T",
            "Stat",
            "req",
            "Time of Last Request",
            "Server Name",
            "Last Status Message",
            ]
        );

    if ($show_header == 1) {
        my $colnum      = 0;
        print " "x$space_tab;
        foreach my $space (@{$column{'space'}}) {
            last if $colnum == $column{'col_number'};
            print $column{'title'}->[$colnum];
            my $indent      = ($column{'space'}->[$colnum] - length($column{'title'}->[$colnum]));
            print " "x$indent;
            print " "x$column{'indent_space'};
            $colnum++;
        }
        print "\n";
        print "-"x$space_tab;
        foreach my $space (@{$column{'space'}}) {
            print "-"x$space;
            print " "x$column{'indent_space'};
        }
        print "\n";
    }
    if ($show_servername == 1) {
        print ( " "x$space_tab                      .
                "*"                                 .
                " "x$column{'indent_space'}         .
                "[ checkpoints for ".$server." ]"
                );
        print "\n";
    }
    if ($show_servers == 1) {
        foreach my $cptserver ( sort $failover->checkpoint_servers( server => $server ) ) {
            my @cpserver        = split(":",$cptserver);
            my $cptype          = shift @cpserver;
            my $cpserver        = join(":",@cpserver);
            my $request_num	    = $failover->number_of_requests(server => $cpserver);
            my $request_time    = $failover->timestamp( time => $failover->last_request_time(server => $cpserver), format => "human" );
            my $checkpoint_status = $failover->checkpoint_status(server => $server, cpserver => $cptserver);
            my $status_message  = $failover->last_status_message(server => $cpserver);
            my $checkpoint_type = "C";
            unless ((defined $status_message) && ($status_message ne "") && ($status_message ne "\n")) {
                $status_message = undef;
            }
            print ( " "x$space_tab .
                    $checkpoint_type    ." "x($column{'space'}->[0] - length($checkpoint_type))     ." "x$column{'indent_space'} .
                    $checkpoint_status  ." "x($column{'space'}->[1] - length($checkpoint_status))   ." "x$column{'indent_space'} .
                    $request_num        ." "x($column{'space'}->[2] - length($request_num))         ." "x$column{'indent_space'} .
                    $request_time       ." "x($column{'space'}->[3] - length($request_time))        ." "x$column{'indent_space'} .
                    $cptserver          ." "x($column{'space'}->[4] - length($cptserver))           ." "x$column{'indent_space'} .
                    $status_message     );
            print "\n";
        }
    }
}

sub list_failover_pool (@) {
    my %args            = @_;
    my $failover        = $args{'failover'};
    my $show_header     = $args{'show_header'};
    $show_header        = 1 unless defined $show_header;
    my $show_poolname   = $args{'show_poolname'} || 0;
    my $show_servers    = $args{'show_servers'};
    $show_servers       = 1 unless defined $show_servers;
    my $space_tab       = $args{'space_tab'} || 0;
    my $space_indent    = $args{'space_indent'};
    $space_indent       = 2 unless defined $space_indent;

    my %column      = (
        indent_space    => $space_indent,
        col_number      => 7,
        space           => [
            qw(1 30 3 20 7 14 19)
            ],
        title           => [
            "T",
            "Server Name",
            "req",
            "Time of Last Request",
            "Status",
            "State",
            "Last Status Message",
            ]
        );

    if ($show_header == 1) {
        my $colnum      = 0;
        print " "x$space_tab;
        foreach my $space (@{$column{'space'}}) {
            last if $colnum == $column{'col_number'};
            print $column{'title'}->[$colnum];
            my $indent      = ($column{'space'}->[$colnum] - length($column{'title'}->[$colnum]));
            print " "x$indent;
            print " "x$column{'indent_space'};
            $colnum++;
        }
        print "\n";
        print "-"x$space_tab;
        foreach my $space (@{$column{'space'}}) {
            print "-"x$space;
            print " "x$column{'indent_space'};
        }
        print "\n";
    }
    if ($show_poolname == 1) {
        print ( " "x$space_tab                      .
                "*"                                 .
                " "x$column{'indent_space'}         .
                "[ ".$failover->pool_name()." ]"
                );
        print "\n";
    }
    if ($show_servers == 1) {
        foreach my $server ( sort $failover->pooled_servers() ) {
            my $failover_type;
            my $request_num	    = $failover->number_of_requests(server => $server);
            my $request_time    = $failover->timestamp( time => $failover->last_request_time(server => $server), format => "human" );
            my $failover_status = $failover->failover_status(server => $server);
            my $failover_state  = $failover->failover_state(server => $server);
            my $status_message  = $failover->last_status_message(server => $server);
            unless ((defined $status_message) && ($status_message ne "") && ($status_message ne "\n")) {
                $status_message = undef;
            }
            if ($failover->host_type(server => $server, type => "PRIMARY")) {
                $failover_type  = "P";
            } elsif ($failover->host_type(server => $server, type => "SECONDARY")) {
                $failover_type  = "S";
            } else {
                $failover_type  = "U";
            }
            print ( " "x$space_tab .
                    $failover_type      ." "x($column{'space'}->[0] - length($failover_type))   ." "x$column{'indent_space'} .
                    $server             ." "x($column{'space'}->[1] - length($server))          ." "x$column{'indent_space'} .
                    $request_num        ." "x($column{'space'}->[2] - length($request_num))     ." "x$column{'indent_space'} .
                    $request_time       ." "x($column{'space'}->[3] - length($request_time))    ." "x$column{'indent_space'} .
                    $failover_status    ." "x($column{'space'}->[4] - length($failover_status)) ." "x$column{'indent_space'} .
                    $failover_state     ." "x($column{'space'}->[5] - length($failover_state))  ." "x$column{'indent_space'} .
                    $status_message     );
            print "\n";
            list_failover_server_checkpoints(failover => $failover, server => $server);
        }
    }
}

sub poll_failover_pool (@) {
    my %args            = @_;
    my $failover        = $args{'failover'}     || return undef;
    my $dbopt           = $args{'dbopt'}        || return undef;
    my $maxRequests     = $args{'maxRequests'}  || return undef;
    my $requestLevel    = $args{'requestLevel'} || return undef;
    my $log             = $args{'log'}          || return undef;

    my $pool_name       = $failover->pool_name();
    my $poolstatus;

    my $logcheckpoint;
    foreach my $mhost (@{ $failover->primary_servers() }, @{ $failover->secondary_servers() }) {
        warn "Polling host: ",$mhost,"\n" if $DEBUG >= 2;
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
        #if ($status_level == 0) {
        #    $log->log_info($out);
        #} elsif ($status_level < $maxRequests) {
        #    $log->log_warn($out);
        #} else {
        #    $log->log_error($out);
        #}
        print $out if $DEBUG;
    }

    my $active_server   = @{ $failover->host_state( state => "ACTIVE" ) }[0] || "NONE";
    my $active_type_msg = "";
    unless ($active_server eq "NONE") {
        $active_type_msg .= (" (".$failover->host_type( server => $active_server ).")");
    }
    if ((defined $loginfo) && ($loginfo ne "") && ($loginfo =~ /\w/)) {
        $log->log_warn(("POLL CYCLE (".$pool_name.")"),("ACTIVE: ".$active_server . $active_type_msg),$loginfo);
    } else {
        $log->log_info(("POLL CYCLE (".$pool_name.")"),("ACTIVE: ".$active_server . $active_type_msg));
    }
}

__END__
