package mysqlpool::failover::cache;

##
# mysqlpool::failover::cache    ver1.00.001/REG     20060302
# added function cache->failover_pool_delete($poolname)
##
# mysqlpool::failover::cache    ver1.00.000/REG     20051216
# cache object to store data of a managed pool of
# failover mysql servers and their state/status in
# regards to their activity in the failover pool
##
#
# Internal object variables
#   $self->{'_cache'}	# The cache file hash
#   $self->{'_cache_file'}	# The cache file on the system
#

use strict;
use Storable qw(lock_store lock_retrieve);

BEGIN {
    use vars    qw($NAME $AUTHOR $VERSION $LASTMOD $DEBUG $DEBUGMSG $ERRORMSG);
    $NAME       = 'mysqlpool::failover::cache';
    $AUTHOR     = 'rglaue@cait.org';
    $VERSION    = '1.00.001';
    $LASTMOD    = 20060302;
    $DEBUG      = 0;

    use vars  qw(@CACHE_STORE_REFS);
}

END {
    while (my $objs = shift @CACHE_STORE_REFS)
    {
        next unless $objs->cache_file() && $objs->cache_updated();
        warn "Storing cache for object\n" if $DEBUG;
        $objs->cache_store() || warn(("Error: Could not save cache to file: ".$objs->cache_file().".\n"));
        $objs = undef;
    }
}

sub cache_init {};

# new($=>$)
# create an instance of this object
# @param DEBUG	turn debug on or off
sub new {
    my $pkg     = shift;
    my $class   = ref($pkg) || $pkg;
    my %args    = @_;
    my $self;

    $self       = bless {}, $class;
    $self->{'DEBUG'} = $args{'debug'} || $args{'DEBUG'} || $DEBUG;
    $self->cache_init(@_);

    return $self;
}

# cache_updated($)
# set a flag defining that this cache was updated, or make the call
# without parameters to retrieve the current value of that flag
# @param flag	set to 1 = updated, or 0 = non updated
sub cache_updated {
    my $self    = shift || return undef;
    my $val     = shift;
    my $ret     = 0;
    if ((! $val >= 1) && (! $val == 0)) {
        return $self->{'_flag_cache_updated'};
    }
    $ret = ($self->{'_flag_cache_updated'} = $val);
    return $ret;
}

# Cache object routines

# cache_init($=>$)
# Initialize the internal cache memory from a file. If the file
# does not exist, it is initialized as a new cache file.
# @param file	the cache file
sub cache_init {
    my $self    = shift || return undef;
    my %args    = @_;

    if ($args{'file'})
    {
        $self->cache_file($args{'file'});
        if (-f $args{'file'})
        {
            unless ($self->cache_retrieve()) {
                $self->errormsg("Cannot retrieve cache from file: ".$args{'file'}.": ".$!);
                return undef;
            }
        } else {
            unless ($self->cache_store()) {
                $self->errormsg("Cannot cache to file: ".$args{'file'}.": ".$!);
                return undef;
            }
        }
        $self->cache_updated(0);
        push(@CACHE_STORE_REFS, $self);
    }
}

# cache_file($)
# set the default cache file used by this object, or make the call without
# parameters to retrieve the currently set default cache file.
# @param cache_file	the cache file
sub cache_file ($) {
    my $self	= shift || return undef;
    my $file	= shift || return $self->{'_cache_file'} || return undef;
    $self->{'_cache_file'} = $file;
}

# cache_retrieve($)
# Read the given cache file into the memory cache.
# This function uses the object's default cahe file if one is note provided.
# @param file	the cache file
sub cache_retrieve ($) {
    my $self	= shift || return undef;
    my $file	= shift || $self->cache_file() || return undef;
    $self->cache_file($file);
    $self->{'_cache'} = undef;
    $self->{'_cache'} = lock_retrieve($file);
}

# cache_store($)
# Store the memory cache as the given cache file.
# This function uses the object's default cahe file if one is note provided.
# @param file	the cache file
sub cache_store ($) {
    my $self	= shift || return undef;
    my $file	= shift || $self->cache_file() || return undef;
    if (! exists $self->{'_cache'}) {
        $self->{'_cache'} = {};
    }
    $self->cache_file($file);
    lock_store $self->{'_cache'}, $file;
}

# Verification routines

# verify_element($=>$)
# This function is used to ensure (or validate) a given set of parameters are 
# found in the cache currently stored in memory for this object.
# @param poolname	The name of a pool
# @param server	The name of a server to be found in the given pool
# @param checkpoint	The name of a checkpoint, of a server, found in a pool
sub verify_element (@) {
    my $self        = shift;
    my %args        = @_;
    my ($poolname,$server,$checkpoint,@errormsg);

    if (exists $args{'poolname'}) {
        $poolname       = $args{'poolname'};
        if (! defined $poolname) {
            push(@errormsg, "Parameter 'poolname' not defined!\n");
        } elsif (! exists $self->{'_cache'}->{'_failover_pool_config'}->{$poolname}) {
            push(@errormsg, "Given poolname: ".$args{'poolname'}." does not exist!");
        }
    }
    if (exists $args{'server'}) {
        $server         = $args{'server'};
        if (! defined $server) {
            push(@errormsg, "Parameter 'server' not defined!");
        } elsif ((defined $poolname) && (! @errormsg > 0)) {
            unless (exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}) {
                push(@errormsg, "Given server: ".$args{'server'}." does not exist in pool: $poolname!");
            }
        }
    }
    if (exists $args{'checkpoint'}) {
        $checkpoint     = $args{'checkpoint'};
        if (! defined $checkpoint) {
            push(@errormsg, "Parameter 'checkpoint' not defined!");
        } elsif ((defined $poolname) && (defined $server) && (! @errormsg > 0)) {
            my @checkpoint  = split(":", $checkpoint);
            my $cptype      = shift @checkpoint;
            my $cpserver    = join (":", @checkpoint);
            unless (exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver}) {
                push(@errormsg, "Given server: ".$args{'server'}." does not exist in pool: $poolname!");
            }
        }
    }
    foreach my $arg ( keys %args ) {
        next if $arg eq "poolname";
        next if $arg eq "server";
        next if $arg eq "checkpoint";
        if (! defined $args{$arg}) {
            push( @errormsg, ("Parameter '".$arg."' not defined!") );
        }        
    }
    if (@errormsg >= 1) {
        $self->errormsg( join("\n",@errormsg) );
        return 0;
    } else {
        return 1;
    }
}

# POLLed server routines

# polled_servers()
# returns an array of servers found in the current cache which are to be
# polled.
sub polled_servers () {
    my $self	= shift || return undef;
    return keys %{ $self->{'_cache'}->{'_server_poll'} }
}

# polled_server_delete($=>$)
# Delete the given server from the list of polled servers. This does not
# delete the server from its pool.
# @param server	the server to delete from the poll list
sub polled_server_delete ($) {
    my $self    = shift || return undef;
    my %args    = @_;
    my $server  = $args{'server'} || undef;
    return undef unless $self->verify_element( server => $server );

    (delete $self->{'_cache'}->{'_server_poll'}->{$server}) && $self->cache_updated(1);
}

# last_status_message($=>$)
# For a server in the server poll list. If message parameter is not provided,
# the last status message is retrieved. If message parameter is provided, it is
# set as the server's last status message.
# If message parameter equals "--", "\n", "" or is undefined, the last status
# message is deleted.
# @param server	the server to retrieve or define the status message for
# @param message	the message to set as the latest status message
sub last_status_message ($) {
    my $self    = shift || return undef;
    my %args    = @_;
    my $server  = $args{'server'} || undef;
    return undef unless $self->verify_element( server => $server );

    if (! exists $args{'message'}) {
        return $self->{'_cache'}->{'_server_poll'}->{$server}->{'last_status_message'};
    }
    my $message = $args{'message'};
    if ((! defined $message) || ($message eq "") || ($message eq "\n")) {
        ($self->{'_cache'}->{'_server_poll'}->{$server}->{'last_status_message'} = "") && $self->cache_updated(1);
    } elsif ($message eq '--') {
        (delete $self->{'_cache'}->{'_server_poll'}->{$server}->{'last_status_message'}) && $self->cache_updated(1);
    } else {
        ($self->{'_cache'}->{'_server_poll'}->{$server}->{'last_status_message'} = $message) && $self->cache_updated(1);
    }
}

# number_of_requests($=>$)
# For a server in the server poll list. If number_of_requests parameter is not
# provided, the current number of requests is retrieved. If number_of_requests
# parameter is provided, it is set as the server's current number of requests.
# If number_of_requests parameter equals "++", the current number of requests is
# incremented. If the number_of_requests parameter equals "--", the current
# number of requests is decremented, but not less than 0. Otherwise, if
# number_of_requests parameter is greater than or equal to 0, that number
# is set as the current number of requests for the given server.
# @param server	the server to retrieve or define the request number for
# @param number_of_requests	the number of requests for this server
sub number_of_requests ($) {
    my $self    = shift || return undef;
    my %args    = @_;
    my $server  = $args{'server'} || undef;
    my $ret     = 0;
    return undef unless $self->verify_element( server => $server );

    my $reqnum;
    if (! exists $args{'requests'}) {
        return $self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'};
    } else {
        $reqnum  = $args{'requests'} || 0;
    }
    if ($reqnum eq '++') {
        if ($self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'} >= 0) {
            $ret = ($self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'}++) && $self->cache_updated(1);
        } else {
            $ret = ($self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'} = 1) && $self->cache_updated(1);
        }
    } elsif ($reqnum eq '--') {
        if ($self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'} >= 1) {
            $ret = ($self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'}--) && $self->cache_updated(1);
        } else {
            $ret = ($self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'} = 0) && $self->cache_updated(1);
        }
    } else {
        $ret = ($self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'} = $reqnum) && $self->cache_updated(1);
    }
    return $ret;
}

# last_request_time($=>$)
# For a server in the server poll list. If time parameter is not provided,
# the last request time is returned. If time parameter is provided, it is
# set as the server's last request time.
# @param server	the server to retrieve or define the last request time for
# @param time	the last request time as a timestamp formatted YYYYMMDDHHMMSS
sub last_request_time ($) {
    my $self    = shift || return undef;
    my %args    = @_;
    my $server  = $args{'server'} || undef;
    my $ret     = 0;
    return undef unless $self->verify_element( server => $server );

    my $reqtime = $args{'time'} || return $self->{'_cache'}->{'_server_poll'}->{$server}->{'last_request_time'};
    $ret = ($self->{'_cache'}->{'_server_poll'}->{$server}->{'last_request_time'} = $reqtime) && $self->cache_updated(1);
    return $ret;
}

# Pool of FAILOVER servers

# cached_pool_name($)
# Specify the name of the default pool for this object to handle
# @param poolname	the name of the pool
sub cached_pool_name ($) {
    my $self        = shift || return undef;
    my $poolname    = shift || return $self->{'_failover_pool_name'};
    $self->{'_failover_pool_name'} = $poolname;
}

# cached_pool_config($=>$)
# For the memory cache failover pool configuration. If config parameter is not
# provided, the currently stored configuration string is returned. If config
# parameter is provided, it is stored as the pool's configuration string.
# This does not configure the pool, but only stores and retrieves the
# configuration string for the pool.
# @param poolname	the name of the pool
# @param config		the configuration for this pool
sub cached_pool_config (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $ret         = 0;
    # return undef unless $self->verify_element( poolname => $poolname );

    if ((! exists $args{'config'}) || (! defined $args{'config'})) {
        if (! exists $self->{'_cache'}->{'_failover_pool_config'}->{$poolname}) {
            return $self->fatalerror("No cached configuration for pool $poolname.");
        } elsif (! defined $self->{'_cache'}->{'_failover_pool_config'}->{$poolname}) {
            return $self->fatalerror("The cached configuration for pool $poolname is undefined.");
        } else {
            return $self->{'_cache'}->{'_failover_pool_config'}->{$poolname};
        }
    } else {
        $ret = ($self->{'_cache'}->{'_failover_pool_config'}->{$poolname} = $args{'config'}) && $self->cache_updated(1);
    }
    return $ret;
}

# cached_pool_status($=>$)
# For the memory cache failover pool status. Set or get the status string set
# for the pool. If status parameter is not provided, the currently stored
# status string is returned. If status parameter is provided, it is stored
# as the pool's status string.
# The values of status are expected as ( status = [ OK | FAIL | UNKNOWN ] )
# @param poolname	the name of the pool
# @param status	the status string to set as the status of the given pool
sub cached_pool_status (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $ret         = 0;
    return undef unless $self->verify_element( poolname => $poolname );

    if ((! exists $args{'status'}) || (! defined $args{'status'})) {
        if (! defined $self->{'_cache'}->{'_failover_pool_status'}->{$poolname}) {
            ($self->{'_cache'}->{'_failover_pool_status'}->{$poolname} = "OK") && $self->cache_updated(1);
        }
        return $self->{'_cache'}->{'_failover_pool_status'}->{$poolname};
    } else {
        $ret = ($self->{'_cache'}->{'_failover_pool_status'}->{$poolname} = $args{'status'}) && $self->cache_updated(1);
    }
    return $ret;
}

# get_cached_pool_names()
# Get a list of pool names stored in the failover pool config memory cache.
sub get_cached_pool_names () {
    my $self        = shift || return undef;
    return [keys %{$self->{'_cache'}->{'_failover_pool_config'}}] || undef;
}

# cached_checkpoint_config($=>$)
# Set or Get the checkpoint configuration string for a server.
# @param poolname	the name of the pool
# @param server		a server in the given pool
# @param config		the checkpoint configuration string of the given server
sub cached_checkpoint_config (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'} || return $self->fatalerror("Cannot retrieve/store checkpoint config for undefined server!");
    my $ret         = 0;
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    my $checkpointconfig    = $args{'config'} || return $self->{'_cache'}->{'_server_checkpoint_config'}->{$poolname}->{$server};
    $ret = ($self->{'_cache'}->{'_server_checkpoint_config'}->{$poolname}->{$server} = $checkpointconfig) && $self->cache_updated(1);
    return $ret;
}

# pooled_servers($=>$)
# Return a list of servers in the named pool based on the given criteria
# defined as 'parsekey'=~'parseval'
# Example: pool_servers( poolname=>"pool1", status=>"OK" )
# Which returns a list of servers in "pool1" pool with a status equalling "OK"
# @param poolname	the name of the pool
# @param parsekey	the key to test, as either 'status' or 'state'
# @param parseval	the value to test on the key, compared as KeyVal=~TestVal
sub pooled_servers (@) {
    my $self    = shift || return undef;
    my %args    = @_;
    my $poolname        = $args{'poolname'} || $self->cached_pool_name();
    return undef unless $self->verify_element( poolname => $poolname );

    my $parsekey        = $args{'parsekey'} || "ALL";
    my $parseval        = $args{'parseval'} || undef;
    return keys %{ $self->{'_cache'}->{'_failover_pool'}->{$poolname} } if $parsekey =~ /ALL/i;
    my @servers = keys %{ $self->{'_cache'}->{'_failover_pool'}->{$poolname} };
    my @returnservers;
    foreach my $server (@servers)
    {
        if ($parsekey =~ /status/i)
        {
            if ($self->failover_status(server => $server) =~ $parseval) {
                push(@returnservers,$server);
            }
        }
        elsif ($parsekey =~ /state/i)
        {
            if ($self->failover_state(server => $server) =~ $parseval) {
                push(@returnservers,$server);
            }
        }
    }
    return @returnservers;
}


# pooled_server_delete($=>$)
# Delete a specified server from the failover pool
# @param poolname	the name of the pool
# @param server	the server in the given pool to delete
sub pooled_server_delete (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    my $ret         = 0;
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    $ret = (delete $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}) && $self->cache_updated(1);
    return $ret;
}


# failover_type($=>$)
# Set or Get the type of server this host is acting as in the pool
# The value of type is expected as ( type = [ primary | secondary ] )
# If type parameter is not provided, the current type of the server is returned.
# @param poolname	the name of the pool
# @param server	a server in the given pool
# @param type	the failover type string to set for the server
sub failover_type (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    if ((exists $args{'type'}) && (defined $args{'type'})) {
        return ($self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_type'} = uc $args{'type'}) && $self->cache_updated(1);
    } elsif ((exists $args{'type'}) && (! defined $args{'type'})) {
        return ($self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_type'} = undef) && $self->cache_updated(1);
    } else {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_type'};
    }
}

# failover_state($=>$)
# State of the server which this host is in, in this pool
# The value of state is expected as ( state = [ UNKNOWN | ACTIVE | STANDBY | FAILED_OFFLINE | FAILED_ONLINE ] )
# If state parameter is not provided, the current state of the server is returned.
# @param poolname	the name of the pool
# @param server	a server in the given pool
# @param state	the state to be assigned to the given server
sub failover_state (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    if ((exists $args{'state'}) && (defined $args{'state'})) {
        return ($self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_state'} = uc $args{'state'}) && $self->cache_updated(1);
    } elsif ((exists $args{'state'}) && (! defined $args{'state'})) {
        return ($self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_state'} = undef) && $self->cache_updated(1);
    } else {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_state'};
    }
}

# failover_status($=>$)
# Status of server this host is known as in its failover_state for this pool
# The value of status is expected as ( status = [ OK | OK_WARN | FAIL ] )
# If status parameter is not provided, the current status of the server is returned.
# @param poolname	the name of the pool
# @param server	a server in the given pool
# @param status	the status to be assigned to the given server
sub failover_status (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    if ((exists $args{'status'}) && (defined $args{'status'})) {
        return ($self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_status'} = uc $args{'status'}) && $self->cache_updated(1);
    } elsif ((exists $args{'status'}) && (! defined $args{'status'})) {
        return ($self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_status'} = undef) && $self->cache_updated(1);
    } else {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_status'};
    }
}

# exists_failover_pool($=>$)
# For the memory cache. Returns 1 if the pool exists, or 0 otherwise.
# @param poolname	the name of the pool
sub exists_failover_pool (@) {
    my $self        = shift;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();

    if (exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}) {
        return 1;
    } else {
        return 0;
    }
}

# exists_failover_server($=>$)
# For the memory cache. Returns 1 if server exists in the pool, or 0 otherwise.
# @param poolname	the name of the pool
# @param server	a server in the given pool
sub exists_failover_server (@) {
    my $self        = shift;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    return undef unless $self->verify_element( poolname => $poolname );

    if (exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}) {
        return 1;
    } else {
        return 0;
    }
}

# exists_failover_server_checkpoint($=>$)
# For the memory cache. Returns 1 if the server checkpoint exists, or 0 otherwise
# @param poolname	the name of the pool
# @param server	a server in the given pool
# @param checkpoint=>type	the checkpoint type [internal | edge | external]
# @param checkpoint=>server	the checkpoint server as "proto:server:port"
sub exists_failover_server_checkpoint (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    my $cptype      = $args{'checkpoint'}{'type'}   || undef;  # internal, edge, external
    my $cpserver    = $args{'checkpoint'}{'server'} || undef;  # "proto:server:port"
    return undef unless $self->verify_element( poolname => $poolname, server => $server );
    return $self->fatalerror("Parameter checkpoint->type not defined") unless defined $cptype;
    return $self->fatalerror("Parameter checkpoint->server not defined") unless defined $cpserver;
    unless ( split(':',$cpserver) == 3) {
        return $self->fatalerror("Parameter checkpoint->server must be defined as 'proto:server:port'.");
    }

    if (exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver}) {
        return 1;
    } else {
        return 0;
    }
}

# create_failover_server($=>$)
# Create a server in a pool
# @param poolname	the name of the pool
# @param server	a server to create in the pool
sub create_failover_server (@) {
    my $self        = shift;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    my $ret         = 0;
    return undef unless $self->verify_element( poolname => $poolname );

    if ($self->exists_failover_server( poolname => $poolname, server => $server)) {
        return 1;
    }
    if (! exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}) {
        $ret = ($self->{'_cache'}->{'_failover_pool'}->{$poolname} = {}) && $self->cache_updated(1);
    }
    $ret = ($self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server} = {}) && $self->cache_updated(1);
    return $ret;
}

# failover_error_message($=>$)
# Set or Get the error message from failover error.
# If message parameter equals "--" the failover error message is deleted.
# @param poolname	the name of the pool
# @param server	a server in the given pool
# @param message	the message to set for the server as a failover error message
sub failover_error_message (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    my $ret         = 0;
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    my $message = $args{'message'} || return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'error_message'};
    if ($message eq '--') {
        $ret = (delete $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'error_message'}) && $self->cache_updated(1);
    } else {
        $ret = ($self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'error_message'} = $message) && $self->cache_updated(1);
    }
    return $ret;
}

# failover_checkpoint($=>$) (failover_checkpoint_status)
# Set or Get the status for a checkpoint. If checkpoint=>status parameter is
# provided, it is set as the status for the checkpoint server. The the
# checkpoint=>status parameter is not provided, then the currently set status
# for the checkpoint server is returned.
# @param poolname	the name of a pool
# @param server	a server in the given pool
# @param checkpoint=>type	the checkpoint type where ( type = [ internal | edge | external ] )
# @param checkpoint=>server	the checkpoint server defined as "proto:server:port"
# @param checkpoint=>status	the checkpoint status where ( status = [ OK | FAIL | UNKNOWN ] )
sub failover_checkpoint (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    my $cptype      = $args{'checkpoint'}{'type'}   || undef;  # internal, edge, external
    my $cpserver    = $args{'checkpoint'}{'server'} || undef;  # "proto:server:port"
    my $cpstatus    = $args{'checkpoint'}{'status'} || undef;
    my $ret         = 0;
    return undef unless $self->verify_element( poolname => $poolname, server => $server );
    return $self->fatalerror("Parameter checkpoint->type not defined") unless defined $cptype;
    return $self->fatalerror("Parameter checkpoint->server not defined") unless defined $cpserver;
    unless ( split(':',$cpserver) == 3) {
        return $self->fatalerror("Parameter checkpoint->server must be defined as 'proto:server:port'.");
    }
    if (    (! exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype})
        ||  (! exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver})
        ) {
        return $self->fatalerror("Checkpoint server $cptype -> $cpserver does not exist for $server in pool $poolname!");
    }

    if (defined $cpstatus) {
        $ret = ($self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver} = $cpstatus) && $self->cache_updated(1);
    } else {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver};
    }
    return $ret;
}

# create_failover_server_checkpoint($=>$)
# Create a checkpoint for a given server in a given pool.
# The checkpoint server is defined as "proto:server:port", some examples are:
# "http:www.google.com:default", "simple:server1.domain.com:9392"
# @param poolname	the name of the pool
# @param server	a server in the given pool
# @param checkpoint=>type	the checkpoint type where ( type = [ internal | edge | external ] )
# @param checkpoint=>server	the checkpoint server defined as "proto:server:port"
# @param checkpoint=>status	the checkpoint status where ( status = [ OK | FAIL | UNKNOWN ] )
sub create_failover_server_checkpoint (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    my $cptype      = $args{'checkpoint'}{'type'}   || undef;  # internal, edge, external
    my $cpserver    = $args{'checkpoint'}{'server'} || undef;  # "proto:server:port"
    my $cpstatus    = $args{'checkpoint'}{'status'} || undef;
    my $ret         = 0;
    return undef unless $self->verify_element( poolname => $poolname, server => $server );
    unless ( split(':',$cpserver) == 3) {
        return $self->fatalerror("Parameter checkpoint->server must be defined as 'proto:server:port'.");
    }
    if (! exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}) {
        $ret = (($self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype} = {}) && $self->cache_updated(1));
    }
    if (exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver}) {
        return $self->fatalerror("Checkpoint creation failed, $cptype -> $cpserver already exists for $server in pool $poolname.");
    } else {
        $ret = ($self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver} = $cpstatus) && $self->cache_updated(1);
    }
    return $self->fatalerror("Checkpoint creation failed, checkpint $cptype:$cpserver could not be established in the cache.") unless $ret;
    return $ret;
}

# failover_checkpoints($=>$)
# Set a checkpoint or Get a list of checkpoints for a server in a given pool.
# To Set a checkpoint, define the checkpoint configuration in the parameters
# of internal, edge or external. To Get a list of checkpoints for a server in
# a given pool, just provide the poolname and server parameters.
# Checkpoints are created by passing checkpoint server strings to the
# create_failover_server_checkpoint() function
# A checkpoint server string has the format "proto:server:port", and the
# checkpoint server's status is set to the value "UNKNOWN"
# @param poolname	the name of the pool
# @param server	a server in the given pool
# @param internal	define the configuration to create an internal checkpoint
# @param edge	define the configuration to create an edge checkpoint
# @param external	define the configuration to create an external checkpoint
sub failover_checkpoints (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    return undef unless $self->verify_element( poolname => $poolname, server => $server );
    my @cptypes     = ("internal","edge","external");

    if (    (! exists $args{'internal'})
        &&  (! exists $args{'edge'})
        &&  (! exists $args{'external'})
       )
    {
        if (! defined $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}) {
            return $self->fatalerror("failover_checkpoints: Could not return checkpoints because none are defined for server: ".$server.".");
        } else {
            return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'};
        }
    }
    foreach my $cptype (@cptypes) {
        next unless exists $args{$cptype};
        foreach my $cpserver (@{$args{$cptype}}) {
            my $exists = $self->exists_failover_server_checkpoint(
                                        poolname    => $poolname,
                                        server      => $server,
                                        checkpoint  => {    type    => $cptype,
                                                            server  => $cpserver }
                                        );
            if (! defined $exists) {
                $self->errormsg("server checkpoints could not be set or do not exist for ".$poolname.":".$server.":".$cptype.":".$cpserver.".");
                return undef;
            }
            next if $exists;
            warn "failover_checkpoints: Creating checkpoint $cptype -> $cpserver with setting UNKNOWN for $server\n";
            $self->create_failover_server_checkpoint(
                                        poolname    => $poolname,
                                        server      => $server,
                                        checkpoint  => {    type    => $cptype,
                                                            server  => $cpserver,
                                                            status  => "UNKNOWN" }
                                        )
                                        || return undef;
        }
    }
    return 1;
}

# checkpoint_servers($=>$)
# Get a list of all checkpoint servers of a given server in a given pool.
# If the optional parameter type is defined, a list of checkpoint server
# matching that type will be returned.
# @param poolname	the name of the pool
# @param server	a server in the given pool
# @param type	the checkpoint type used to filter what type of checkpoints are returned
sub checkpoint_servers (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    my $cptype      = $args{'type'}   || undef;  # internal, edge, external
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    my @cpservers;
    my $focpservers = $self->failover_checkpoints( poolname => $poolname, server => $server );

    if (! defined $cptype) {
        foreach my $focptype (keys %$focpservers) {
            next unless defined $focpservers->{$focptype};
            foreach my $cpserver (keys %{ $focpservers->{$focptype} }) {
                push ( @cpservers, ($focptype.":".$cpserver) );
            }
        }
    } else {
        if (defined $focpservers->{$cptype}) {
            foreach my $cpserver (keys %{ $focpservers->{$cptype} }) {
                push ( @cpservers, ($cptype.":".$cpserver) );
            }
        }
    }

    return @cpservers;
}

# checkpoint_status($=>$)
# Set or Get the status of a checkpoint server of a given server in a given pool
# @param poolname	the name of the pool
# @param server	a server in the given pool
# @param cpserver	the checkpoint server defined as "type:proto:server:port"
# @param cpstatus	the status of the checkpoint server
sub checkpoint_status (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    my $cpserver    = $args{'cpserver'};
    my $cpstatus    = $args{'cpstatus'} || undef;
    return undef unless $self->verify_element( poolname => $poolname, server => $server );
    return $self->fatalerror("Parameter checkpoint server not defined") unless defined $cpserver;
    unless ( split(':',$cpserver) == 4) {
        return $self->fatalerror("Parameter checkpoint server must be defined as 'type:proto:server:port'.");
    }
    my @checkpoint  = split(':',$cpserver);
    my $cp_type     = shift @checkpoint;
    my $cp_server   = join(':',@checkpoint);
    if (defined $cpstatus) {
        return $self->failover_checkpoint(  poolname => $poolname, server => $server,
                                            checkpoint => { type => $cp_type, server => $cp_server }
                                        );
    } else {
        return $self->failover_checkpoint(  poolname => $poolname, server => $server,
                                            checkpoint => { type => $cp_type, server => $cp_server, status => $cpstatus }
                                        );
    }
}

# checkpoint_server_delete($=>$)
# Delete a checkpoint server of a given server from a given pool
# @param poolname	the name of the pool
# @param server	a server in the given pool
# @param checkpoint=>type	the type of the checkpoint to delete
# @param checkpoint=>server	the server of the checkpoint to delete
sub checkpoint_server_delete (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'};
    my $server      = $args{'server'};
    my $cptype      = $args{'checkpoint'}{'type'}   || undef;  # internal, edge, external
    my $cpserver    = $args{'checkpoint'}{'server'} || undef;
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    if ((! defined $cptype) && (defined $cpserver)) {
        # idealy, in this case we may want to search for the server to delete.
        $self->errormsg("Could not delete checkpoint server $cpserver with undefined checkpoint type.");
        return undef;
    }
    my ($polled_res, $chkpnt_res);
    if ((defined $cptype) && (defined $cpserver)) {
        $chkpnt_res = 1;
        $polled_res = $self->polled_server_delete( server => $cpserver )
                        || $self->adderror("Could not delete checkpoint server $cpserver from poll cache.");
        if (exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver}) {
            unless (delete $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver}) {
                $chkpnt_res = 0;
                $self->adderror("Could not delete checkpoint server $cpserver from cached pooled server $server.");
            }
        }
    } elsif ((defined $cptype) && (! defined $cpserver)) {
        $polled_res = 1;
        $chkpnt_res = 1;
        foreach my $cpserver (keys %{$self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}}) {
            unless ( $self->polled_server_delete( server => $cpserver ) ) {
                $polled_res = 0;
                $self->adderror("Could not delete checkpoint server $cpserver from poll cache.");
            }
            unless (delete $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver}) {
                $chkpnt_res = 0;
                $self->adderror("Could not delete checkpoint server $cpserver from cached pooled server $server.");
            }
        }
    } else {
        $polled_res = 1;
        $chkpnt_res = 1;
        foreach my $cptype (keys %{$self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}}) {
            foreach my $cpserver (keys %{$self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}}) {
                unless ( $self->polled_server_delete( server => $cpserver ) ) {
                    $polled_res = 0;
                    $self->adderror("Could not delete checkpoint server $cpserver from poll cache.");
                }
                unless (delete $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver}) {
                    $chkpnt_res = 0;
                    $self->adderror("Could not delete checkpoint server $cpserver from cached pooled server $server.");
                }
            }
        }
    }
    unless (($polled_res == 1) && ($chkpnt_res == 1)) {
        return 0;
    } else {
        return 1;
    }
}

# Miscellaneous

# server_delete($=>$)
# Delete from both the polled list as well as the failover pool
# @param poolname	the name of the pool
# @param server	a server in the given pool
sub server_delete ($) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    my $polled_res  = $self->polled_server_delete(server => $server)
                        || adderror($self,"Polled server $server could not be deleted.");
    my $chkpnt_res  = $self->checkpoint_server_delete(server => $server, poolname => $poolname)
                        || adderror($self,"Checkpoints for server $server from pool $poolname could not be deleted.");
    my $pooled_res  = $self->pooled_server_delete(server => $server, poolname => $poolname)
                        || adderror($self,"Pooled server $server from pool $poolname could not be deleted.");

    unless (($polled_res) && ($pooled_res)) {
        return 0;
    } else {
        return 1;
    }
}

# failover_pool_delete($=>$)
# @param poolname	the name of the pool
sub failover_pool_delete {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();

    foreach my $pooled_server ($self->pooled_servers(poolname => $poolname)) {
        $self->server_delete(poolname => $poolname, server => $pooled_server)
            || $self->errormsg("While deleting pool $poolname, could not delete pooled server $pooled_server.");
        delete $self->{'_server_checkpoint_config'}->{$pooled_server};
    }
    delete $self->{'_failover_pool_config'}->{$poolname};
    delete $self->{'_failover_pool_status'}->{$poolname};
    delete $self->{'_failover_pool'}->{$poolname};
}

# cache_dump()
# Dump the cache currently in memory.
sub cache_dump () {
    my $self    = shift;
    use Data::Dumper;
    # local $Data::Dumper::Purity = 1;
    $Data::Dumper::Indent = 1;
    return Data::Dumper->Dumper($self->{'_cache'});
}

# fataladderror($)
# Combine a message with the errormsg message stack and return the results
# of passing this combined message to fatalerror()
# @param msg	the message to add
sub fataladderror ($) {
    my $self    = shift;
    my $msg     = shift;
       $msg    .= "\n";
       $msg    .= $self->errormsg();
    return $self->fatalerror($msg);
}

# fatalerror(@)
# Set a list of messages as the errormsg message stack and return undef.
# @param [messages]	one or more messages
sub fatalerror (@) {
    my $self    = shift;
    $self->errormsg(@_);
    return undef;
}

# warnerror(@)
# Set a list of messages as the errormsg message stack and return undef.
# @param [messages]	one or more messages
sub warnerror (@) {
    my $self    = shift;
    $self->errormsg(@_);
    return undef;
}

# adderror($)
# Combine a message with the errormsg message stack and return the results
# of passing this combined message to errormsg()
# @param msg	the message to add
sub adderror ($) {
    my $self    = shift;
    my $msg = shift;
       $msg .= "\n";
       $msg .= $self->errormsg();
    $self->errormsg($msg);
}

# errormsg($)
# Set or Get the errormmsg message stack
# @param msg	the message to add
sub errormsg () {
    my $self    = shift;
    if (@_ >= 1) {
        return $self->{'_ERRORMSG'} = join("\n",@_);
    } else {
        return $self->{'_ERRORMSG'} || undef;
    }
}

# debugmsg($)
# Set or Get the current debug level
# @param DEBUG_LEVEL	the debug level
sub debugmsg () {
    my $DEBUG_LEVEL;
    if (ref $_[0]) {
        my $self        = shift;
        $DEBUG_LEVEL    = $self->{'DEBUG'};
    } else {
        $DEBUG_LEVEL    = $DEBUG;
    }
    return 1 unless $DEBUG_LEVEL > 0;
    $DEBUGMSG   = join("\n",@_) || return $DEBUGMSG || return undef;
    warn $DEBUGMSG,"\n";
}


1;
__END__
