package mysqlpool::failover::logic;

##
# mysqlpool::failover::logic    ver1.00.000/REG     20051216
# Logic for failover strategy/methodology
#   Intended to be subclassed by mysqlpool::failover
##

use strict;

BEGIN {
    use vars    qw($NAME $AUTHOR $VERSION $LASTMOD $DEBUG $DEBUGMSG $ERRORMSG);
    $NAME       = 'mysqlpool::failover::logic';
    $AUTHOR     = 'rglaue@cait.org';
    $VERSION    = '1.00.000';
    $LASTMOD    = 20051216;
    $DEBUG      = 0;

    use vars    qw($MAX_REQUESTS $REQUEST_LEVEL $HOSTILE_TAKEOVER);
    $MAX_REQUESTS       = 5;
    $REQUEST_LEVEL      =
        {   0 => 'OK',      1 => 'OK INFO', 2 => 'OK WARN',
            3 => 'OK SOFT', 4 => 'OK HARD', 5 => 'FAIL CRITICAL'    };
    $HOSTILE_TAKEOVER   = 0;
}

sub new {
    my $pkg     = shift;
    my $class   = ref($pkg) || $pkg;
    my %args    = @_;

    my $self    = bless {}, $class;
    $self->{'DEBUG'} = $args{'debug'} || $args{'DEBUG'} || $DEBUG;

    return $self;
}

# decipher_checkpoints
# decipher the status of a pool based on the checkpoints of the servers it
# manages.  status being OK or FAIL
# This is useful when the poller is located geographically different from at
# least one of the servers it manages in its pool. AND/OR the poller is a part
# of a distribution of pollers which themselves act as a failover for each
# other.
sub decipher_checkpoints (@) {
    my $self            = shift;
    my %args            = @_;
    my $host            = $args{'host'} || return undef;

    my $fo_server       = $host->hostport();
    my $status          = { pool        => "UNKNOWN",
                            host        => "UNKNOWN",
                            location    => "UNKNOWN",
                            message     => undef,
                            internal    => { count => 0, failures => 0 },
                            edge        => { count => 0, failures => 0 },
                            external    => { count => 0, failures => 0 }
                            };

    my $poll_commit = sub ($$) {
        my %args        = @_;
        my $cpserver    = $args{'cpserver'};
        my $type        = $args{'type'};
        my $status      = $args{'status'} || 'FAIL';  # 'OK', 'FAIL'
        my $message     = $args{'message'};

        # Set the Polled host information
        if ($status =~ /FAIL/) {
            $self->number_of_requests(server => $cpserver, requests => '++');
        } elsif ($status =~ /OK/) {
            my $last_req_num = $self->number_of_requests( server => $cpserver );
            my $old_message;
            if ($last_req_num >= 1) {
                if ( ($message ne "--") && (defined $message) ) {
                    $old_message = $message;
                } else {
                    $old_message = $self->last_status_message(server => $cpserver);
                }
                $message    = join(" ", ("(recovering)", $old_message) );
            }
            # $self->number_of_requests(server => $cpserver, requests => '--');  # If we want the host to "HEAL" slowly
            $self->number_of_requests(server => $cpserver, requests => '0');  # Immediate host recovery
        }

        $self->failover_checkpoint( server      =>  $fo_server,
                                    checkpoint  =>  {   type    => $type,
                                                        server  => $cpserver,
                                                        status  => $status
                                                    }
                                    );

        if (defined $message) {
            $self->last_status_message(server => $cpserver, message => $message);
        }

        # Store the cache
        # $self->cache_store() || die ("Could not save cache file: ".$self->cache_file()."!\n");
    };

    if ($host->has_checkpoints()) {
        print ("Polling ".$host->hostport()." checkpoints:\n") if $DEBUG;
        my $failures    = $host->poll_checkpoints();
        foreach my $cp (keys %$failures) {
            my ($type,$proto,$server,$port) = split (':',$cp);
            $self->last_request_time( server => ($proto.":".$server.":".$port), time => $self->timestamp(format => "seconds") );
            $status->{$type}->{'count'}++;
            if (@{ $failures->{$cp} } > 0) {
                my $failure_message = ("(checkpoint $cp) ".join(" ",@{ $failures->{$cp} }));
                $status->{$type}->{'failures'}++;
                $status->{$type}->{'message'} .= $failure_message;
                if (defined $status->{'message'}) {
                    $status->{'message'} = join("\n",($status->{'message'}, $failure_message));
                } else {
                    $status->{'message'} = $failure_message;
                }
                $poll_commit->( cpserver    => ($proto.":".$server.":".$port),
                                type        => $type,
                                message     => $status->{$type}->{'message'},
                                status      => "FAIL");
            } else {
                $poll_commit->( cpserver    => ($proto.":".$server.":".$port),
                                type        => $type,
                                message     => "--",
                                status      => "OK");
            }
        }
        if ((! $host->ping()) || (! $host->isUp())) {
            $status->{'host'}   = "FAIL";
            $status->{'pool'}   = "OK";
            if ($status->{'internal'}->{'failures'} >= $status->{'internal'}->{'count'}) {
                $status->{'pool'}   = "OK";
                if ($status->{'edge'}->{'failures'} >= $status->{'edge'}->{'count'}) {
                    $status->{'pool'}   = "OK";
                    if ($status->{'external'}->{'failures'} >= $status->{'external'}->{'count'}) {
                        $status->{'pool'}   = "FAIL";
                    }
                }
            }

            ##
            # Decipher location
            # LAN    = internal=YES, edge=NO,  external=NO
            # WAN    = internal=NO,  edge=YES, external=NO
            # GLOBAL = internal=NO,  edge=NO,  external=YES
            ##
            if ($status->{'internal'}->{'failures'} >= $status->{'internal'}->{'count'}) {
                if ($status->{'edge'}->{'failures'} >= $status->{'edge'}->{'count'}) {
                    if ($status->{'external'}->{'failures'} >= $status->{'external'}->{'count'}) {
                        $status->{'location'}   = "UNKNOWN";
                    } else {
                        $status->{'location'}   = "GLOBAL";
                    }
                } else {
                    if ($status->{'external'}->{'failures'} >= $status->{'external'}->{'count'}) {
                        $status->{'location'}   = "WAN";
                    } else {
                        $status->{'location'}   = "UNKNOWN";
                    }
                }
            } else {
                if ($status->{'edge'}->{'failures'} >= $status->{'edge'}->{'count'}) {
                    if ($status->{'external'}->{'failures'} >= $status->{'external'}->{'count'}) {
                        $status->{'location'}   = "LAN";
                    } else {
                        $status->{'location'}   = "UNKNOWN";
                    }
                } else {
                    if ($status->{'external'}->{'failures'} >= $status->{'external'}->{'count'}) {
                        $status->{'location'}   = "UNKNOWN";
                    } else {
                        $status->{'location'}   = "UNKNOWN";
                    }
                }
            }
        } else {
            $status->{'host'}   = "OK";
            $status->{'pool'}   = "OK";
        }
    } else {
        print ("Server ".$host->hostport()." does not have checkpoints to poll.\n") if $DEBUG;
        $status->{'pool'}   = "OK";
    }

    return ($status);
}

# decipher_failover
# decipher the status/state of a given host according to failover pool logic and commit them to cache
# @param    server          A mysqlpool::host::* object (with poll_connect and poll_request functions)
# @param    maxrequests     Maximum failed request allowed before considering host as FAILED
# @param    requestlevel    A hash of the request level values from 0 to maxrequests
# @param    hostiletakeover Whether or not primary is allowed to perform a hostile takeover
#                           if it recovers from a FAILED state.
sub decipher_failover (@) {
    my $self            = shift;
    my %args            = @_;
    my $host            = $args{'server'}           || return undef;
    my $maxRequests     = $args{'maxrequests'}      || $MAX_REQUESTS;
    my $requestLevel    = $args{'requestlevel'}     || $REQUEST_LEVEL;
    my $hostileTakeover = $args{'hostileTakeover'}  || $HOSTILE_TAKEOVER;
    my $poolstatus      = $args{'poolstatus'}       || "OK";    # OK, FAIL

    my $server          = $host->hostport();
    my $thishost        = {
                            hostport    => $host->hostport(),
                            status      => undef,
                            state       => undef,
                            message     => undef,
                            return      => undef,
                            errors      => {
                                            connect  => [],
                                            request  => []
							}
				};


    my $poll_exit   = sub ($$) {
        my ($exitmsg, $exitval, $hoststatus);
        $exitmsg        = shift || 'FAIL';  # 'OK', 'WARN', 'FAIL'
        $exitval    = 0; # DEFAULT
        $exitval    = 1 if $exitmsg eq 'OK';
        $exitval    = 1 if $exitmsg eq 'WARN';
        $exitval    = 0 if $exitmsg eq 'ERROR';
        ### my $thishost	= shift || $thishost || die "Polled-Host object not passed in to allow an exit from poller!";
        ### my $server	= $thishost->hostport();

        # Make sure the host STATUS is not ACTIVE if the POOL STATUS is not OK (is FAIL)
        if ($poolstatus ne "OK") {
            if (
                    ( (defined $thishost->{'state'})  && ($thishost->{'state'} eq "ACTIVE") )
                ||  ( (!defined $thishost->{'state'}) && ($self->host_state( server => $server, state => "ACTIVE" )) )
                )
            {
                $thishost->{'state'}    = "STANDBY";
                $thishost->{'message'}  = join(" ", (   $thishost->{'message'},
                                                        "(Server not allowed to be active wile POOL has $poolstatus status.)"   )
                                                    );
            }
        }
        # Set the Polled host information
        if ($exitmsg =~ /WARN|FAIL/) {
            $self->number_of_requests(server => $server, requests => '++');
        } elsif ($exitmsg =~ /OK/) {
            my $last_req_num = $self->number_of_requests( server => $server );
            if ($last_req_num >= 1) {
                my $old_message;
                if ( ($thishost->{'message'} ne "--") && (defined $thishost->{'message'}) ) {
                    $old_message = $thishost->{'message'};
                } else {
                    $old_message = $self->last_status_message(server => $server);
                }
                $thishost->{'message'}  = join(" ", ("(recovering)", $old_message) );
            }
            # $self->number_of_requests(server => $server, requests => '--');  # If we want the host to "HEAL" slowly
            $self->number_of_requests(server => $server, requests => '0');  # Immediate host recovery
        }
        if (defined $thishost->{'status'}) {
            $self->failover_status(server => $server, status => $thishost->{'status'});
        }
        if (defined $thishost->{'state'}) {
            $self->failover_state(server => $server, state => $thishost->{'state'});
        }
        if (defined $thishost->{'message'}) {
            $self->last_status_message(server => $server, message => $thishost->{'message'});
        }

        # Store the cache
        # $self->cache_store() || die ("Could not save cache file: ".$self->cache_file()."!\n");

        return $exitval;
    };


    #
    # record the request time, and poll the server
    #
    $self->last_request_time( server => $server, time => $self->timestamp(format => "seconds") );
    @{$thishost->{'errors'}->{'connect'}} = $host->poll_connect();
    if (@{$thishost->{'errors'}->{'connect'}} == 0) {
        @{$thishost->{'errors'}->{'request'}} = $host->poll_request();
    }

    #
    # This first step is necessary for non-PRIMARY ACTIVE servers
    # with status=OK_WARN to be demoted to STANDBY when the PRIMARY
    # server is promoted to ACTIVE either automatically or manually
    # Servers with status=OK_WARN will EXIT before evaluation of
    # which server in the pool is to be the current state=ACTIVE
    ########### step 1/5
    # (host connectivity success/failure not known)
    # (host request success/failure not known)
    # (EVALUATE: PRIMARY)
    # IF test-server-PRIMARY is state=ACTIVE (NOT STANDBY - evaluated in last step)
    #     IF type=SECONDARY
    #         IF state=ACTIVE
    #             then state=STANDBY
    #             note: reinstating/recovering PRIMARY
    #
    # CONTINUE
    #
    if ($self->primary_state("ACTIVE")) {
        if ($self->host_type(server => $server, type => "SECONDARY")) {
            if ($self->host_state(server => $server, state => "ACTIVE")) {
                $thishost->{'state'}	= "STANDBY";
                $thishost->{'message'}	= "Relinquishing ACTIVE control to PRIMARY";
            }
        }
    }

    ########### step 2/5
    # (host connectivity success/failure not known)
    # (host request success/failure not known)
    # (EVALUATE: connectivity)
    # IF ANY connectivity failures with the host
    #    IF current connect failure count is greater than or equal to ($maxRequest - 1 to include this unaccounted failure request)
    #        IF state=ACTIVE
    #            IF test-server-LOWER-PRIORITY state=STANDBY
    #                then state=failed_offline
    #                then status=FAILED_OFFLINE
    #                EXIT FAIL
    #            IF test-server-LOWER-PRIORITY NOT state=STANDBY
    #                then state=<current>
    #                then status=OK_WARN
    #                EXIT WARN
    #        IF NOT state=ACTIVE
    #            then state=<current>
    #            then status=FAILED_OFFLINE
    #            EXIT FAIL
    #    IF current connect failure count is less than $maxRequest
    #        then state=<current>
    #        then status=OK_WARN
    #        EXIT WARN
    #
    # IF no connectivity failures
    #    CONTINUE
    #
    if (@{$thishost->{'errors'}->{'connect'}})
    {
        my $status_message = ( join(", ", @{$thishost->{'errors'}->{'connect'}}) );

        if ($self->number_of_requests(server => $server) >= ($maxRequests - 1))
        {
            $thishost->{'state'}	= 'failed_offline';
            $thishost->{'status'}	= 'FAIL';
            $thishost->{'message'}	= $status_message;
            $thishost->{'return'}	= 1;
            if ($self->host_state( server => $server, state => "ACTIVE" )) {
                if ( $self->lower_priority_server_state_ok(server => $server) ) {
                    return $poll_exit->('FAIL');
                } elsif ( $self->higher_priority_server_state_ok(server => $server) ) {
                    return $poll_exit->('FAIL');
                } else {
                    $thishost->{'message'}	.= "; Not failing from ACTIVE state because no other server is on standby";
                    return $poll_exit->('WARN');
                }
            } else {
                return $poll_exit->('FAIL');
            }
        }
        else
        {
            $thishost->{'status'}	= 'OK_WARN';
            $thishost->{'message'}	= $status_message;
            $thishost->{'return'}	= 1;
            # We cannot process this host's requests if we cannot at least connect, so return OK_WARN
            return $poll_exit->('WARN');
        }
    }
    # else continue...

    ########### step 3/5
    # (host connectivity success known)
    # (host request success/failure not known)
    # (EVALUATE: SLAVE)
    # If ANY request failures
    #    IF this host's request failure count is greater than or equal to ($maxRequests - 1 to include this unaccounted failure request)
    #        IF state=ACTIVE
    #            then state=<current>
    #            then status=OK_WARN
    #            EXIT WARN
    #        IF NOT state=ACTIVE
    #            then state=failed_online
    #            then status=FAIL
    #            EXIT FAIL
    #    IF this host's request failure count is less than $maxRequests (max) times
    #        then state=<current>
    #        then status=OK_WARN
    #        EXIT WARN
    #
    # IF NO request errors
    #    CONTINUE
    #
    if (@{$thishost->{'errors'}->{'request'}})
    {
        my $status_message = ( join(", ", @{$thishost->{'errors'}->{'request'}}) );
        $thishost->{'message'} = $status_message;

        if ($self->number_of_requests(server => $server) >= ($maxRequests - 1))
        {
            if ($self->host_state( server => $server, state => "ACTIVE" )) {
                $thishost->{'status'}	= "OK_WARN";
                return $poll_exit->('WARN');
            } else {
                $thishost->{'state'}	= "FAILED_ONLINE";
                $thishost->{'status'}	= "FAIL";
                $thishost->{'return'}	= 1;
                return $poll_exit->('FAIL');
            }
        }
        else
        {
            $thishost->{'status'} = "OK_WARN";
            return $poll_exit->('WARN');
        }
    }
    # else continue...

    ########### step 4/5 + 5/5
    # (host connectivity success known)
    # (host request success known)
    # (EVALUATE: ACTIVE)
    # IF type=PRIMARY
    #    IF state=ACTIVE
    #        IF TRUE HOSTILE-TAKEOVER
    #            IF test-server-LOWER-PRIORITY state=ACTIVE
    #                then state=<current>
    #                then status=OK_WARN
    #                CHANGE MESSAGE "Hostile takeover for recovery/reinstatement initiated."
    #                EXIT WARN
    #            IF test-server-LOWER-PRIORITY NOT state=ACTIVE
    #                then state=<current>
    #                then status=OK
    #                EXIT OK
    #        IF FALSE HOSTILE-TAKEOVER
    #            then state=<current>
    #            then status=OK
    #            EXIT OK
    #    IF state=STANDBY
    #        IF test-server-LOWER-PRIORITY NOT state=ACTIVE
    #            then state=ACTIVE
    #            then status=OK_WARN
    #            CHANGE MESSAGE "PRIMARY instatement to ACTIVE complete."
    #            EXIT WARN
    #        IF TRUE HOSTILE-TAKEOVER
    #            then state=ACTIVE
    #            then status=OK_WARN
    #            CHANGE MESSAGE "Hostile takeover for ACTIVE reinstatement initiated."
    #            EXIT WARN
    #        IF FALSE HOSTILE-TAKEOVER
    #            then state=<current>
    #            then status=OK_WARN
    #            CHANGE MESSAGE "Waiting for SECONDARY to stand down before instatement to ACTIVE."
    #            EXIT OK
    #    IF state=UNKNOWN
    #        then state=STANDBY
    #        then status=OK
    #        EXIT OK
    #    IF state=FAILED_OFFLINE OR state=FAILED_ONLINE
    #        then state=<current>
    #        then status=OK_WARN
    #        CHANGE MESSAGE "FAILED PRIMARY server is reporting recovery. Manual intervention required."
    #        EXIT OK
    #
    # IF type=SECONDARY
    #    IF state=ACTIVE
    #        IF test-server-PRIMARY state=ACTIVE
    #            then state=STANDBY
    #            then status=OK_WARN
    #            CHANGE MESSAGE "Relinquishing ACTIVE state to PRIMARY."
    #            EXIT OK
    #        IF test-server-PRIMARY NOT state=ACTIVE
    #            IF test-server-PRIMARY state=STANDBY
    #                IF TRUE HOSTILE-TAKEOVER
    #                    then state=STANDBY
    #                    then status=OK_WARN
    #                    CHANGE MESSAGE "Relinquishing ACTIVE state to PRIMARY."
    #                    EXIT OK
    #                IF FALSE HOSTILE-TAKEOVER
    #                    IF test-server-REQUESTS >= 1
    #                        then state=STANDBY
    #                        then status=OK
    #                        CHANGE MESSAGE "Relinquishing ACTIVE state to PRIMARY."
    #                        EXIT OK
    #                    IF test-server-REQUESTS = 0
    #                        then status=OK_WARN
    #                        CHANGE MESSAGE "Ready to relinquish ACTIVE state to PRIMARY."
    #                        EXIT WARN
    #
    #    IF state=STANDBY
    #        IF test-server-HIGHER-PRIORITY status=OK
    #            then state=<current>
    #            then status=OK
    #            EXIT OK
    #        IF test-server-HIGHER-PRIORITY status=FAIL
    #            then state=ACTIVE
    #            CHANGE MESSAGE "FAILOVER: Taking over ACTIVE state."
    #            then status=OK_WARN
    #            EXIT WARN
    #
    #    IF state=UNKNOWN
    #        then state=STANDBY
    #        then status=OK
    #        EXIT OK
    #
    if ($self->host_type( server => $server, type => "PRIMARY" )) {
        if ($self->host_state( server => $server, state => "ACTIVE" )) {
            if ($hostileTakeover) {
                if ($self->lower_priority_server_state(server => $server, state => "ACTIVE")) {
                    $thishost->{'status'}	= "OK_WARN";
                    $thishost->{'message'}	= "Hostile takeover for ACTIVE reinstatement initiated. Watching for secondary to change to STANDBY.";
                    return $poll_exit->('WARN');
                } else {
                    $thishost->{'status'}	= "OK";
                    $thishost->{'message'}	= "--";
                    return $poll_exit->('OK');
                }
            } else {
                $thishost->{'status'}	= "OK";
                $thishost->{'message'}	= "--";
                return $poll_exit->('OK');
            }
        } elsif ($self->host_state( server => $server, state => "STANDBY" )) {
            if (! $self->lower_priority_server_state(server => $server, state => "ACTIVE")) {
                $thishost->{'state'}	= "ACTIVE";
                $thishost->{'status'}	= "OK_WARN";
                $thishost->{'message'}	= "PRIMARY instatement to ACTIVE complete.";
                return $poll_exit->('WARN');
            } elsif ($hostileTakeover) {
                $thishost->{'state'}	= "ACTIVE";
                $thishost->{'status'}	= "OK_WARN";
                $thishost->{'message'}	= "Hostile takeover for ACTIVE reinstatement initiated.";
                return $poll_exit->('WARN');
            } else {
                $thishost->{'status'}	= "OK_WARN";
                $thishost->{'message'}	= "Waiting for SECONDARY to stand down before instatement to ACTIVE.";
                return $poll_exit->('OK');
            }
        } elsif ($self->host_state( server => $server, state => "UNKNOWN" )) {
            $thishost->{'state'}	= "STANDBY";
            $thishost->{'status'}	= "OK";
            return $poll_exit->('OK');
        } else {
            # FAILED_ONLINE | FAILED_OFFLINE
            $thishost->{'status'}	= "OK_WARN";
            $thishost->{'message'}	= "FAILED PRIMARY server is reporting recovery. Manual intervention required.";
            return $poll_exit->('OK');
        }
    }
    else  # else This host is type=SECONDARY
    {
        if ($self->host_state( server => $server, state => "ACTIVE" )) {
            if ($self->primary_state("ACTIVE")) {
                $thishost->{'state'}	= "STANDBY";
                $thishost->{'status'}	= "OK_WARN";
                $thishost->{'message'}	= "Relinquishing ACTIVE state to PRIMARY.";
                return $poll_exit->('WARN');
            } elsif ($self->primary_state("STANDBY")) {
                if ($hostileTakeover) {
                    $thishost->{'state'}	= "STANDBY";
                    $thishost->{'status'}	= "OK_WARN";
                    $thishost->{'message'}	= "Relinquishing ACTIVE state to PRIMARY.";
                    return $poll_exit->('WARN');
                } else {
                    if ( $self->number_of_requests( server => $server ) >= 1 ) {
                        $thishost->{'state'}	= "STANDBY";
                        $thishost->{'status'}	= "OK_WARN";
                        $thishost->{'message'}	= "Relinquishing ACTIVE state to PRIMARY.";
                        return $poll_exit->('OK');
                    } else {
                        $thishost->{'status'}	= "OK_WARN";
                        $thishost->{'message'}	= "Ready to relinquish ACTIVE state to PRIMARY.";
                        return $poll_exit->('WARN');
                    }
                }
            } else {
                $thishost->{'status'}	= "OK";
                $thishost->{'message'}	= "--";
                return $poll_exit->('OK');
            }
        } elsif ($self->host_state( server => $server, state => "STANDBY" )) {
            if ($self->higher_priority_server_status_ok(server => $server)) {
                    $thishost->{'status'}	= "OK";
                    $thishost->{'message'}	= "--";
                    return $poll_exit->('OK');
            } else {
                    $thishost->{'state'}	= "ACTIVE";
                    $thishost->{'status'}	= "OK_WARN";
                    $thishost->{'message'}	= "FAILOVER: Taking over ACTIVE state.";
                    return $poll_exit->('WARN');
            }
        } elsif ($self->host_state( server => $server, state => "UNKNOWN" )) {
            $thishost->{'state'}	= "STANDBY";
            $thishost->{'status'}	= "OK";
            return $poll_exit->('OK');
        } else {
            # FAILED_ONLINE | FAILED_OFFLINE
            $thishost->{'status'}	= "OK";
            $thishost->{'message'}	= "FAILED server is reporting recovery. Manual intervention required.";
            return $poll_exit->('OK');
        }
    }
    $thishost->{'state'}	= "UNKNOWN";
    $thishost->{'status'}	= "OK_WARN";
    $thishost->{'message'}  = ("Error polling server: ".$server.". No return status available!\n".
         "Current state of ".$server." is: ".$self->host_state( server => $server ) .".\n");
    return $poll_exit->('WARN');
}


sub fatalerror ($) {
    my $self    = shift;
    $self->errormsg(@_);
    return undef;
}

sub errormsg () {
    my $self    = shift;
    $ERRORMSG   = shift || return $ERRORMSG || return undef;
}

sub debugmsg () {
    my $DEBUG_LEVEL;
    if (ref $_[0]) {
        my $self        = shift;
        $DEBUG_LEVEL    = $self->{'DEBUG'};
    } else {
        $DEBUG_LEVEL    = $DEBUG;
    }
    return 1 unless $DEBUG_LEVEL > 0;
    $DEBUGMSG   = join(" ",@_) || return $DEBUGMSG || return undef;
    warn $DEBUGMSG,"\n";
}


1;

__END__
