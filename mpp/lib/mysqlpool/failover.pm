package mysqlpool::failover;

##
# mysqlpool::failover           ver1.00.001/REG     20060302
# added function parseFailoverpoolConfigString
# added function parseCheckpointConfigString
# added function joinFailoverpoolConfigHash
# added function joinCheckpointConfigHash
##
# mysqlpool::failover           ver1.00.000/REG     20051216
# object to manage a pool of failover mysql server and
# their state/status in regards to their activity in
# the failover pool
# Extends: mysqlpool::failover::cache
##
#
# Internal object variables
#   $self->{'_cache'}	# The cache file hash
#   $self->{'_file'}	# The cache file on the system
#

use strict;
use Storable;
use mysqlpool::failover::cache;
use mysqlpool::failover::logic;
use mysqlpool::host::mysql;
use mysqlpool::host::checkpoint;

BEGIN {
    use vars    qw( @ISA );
    @ISA        = qw(mysqlpool::failover::cache mysqlpool::failover::logic);

    use vars    qw($NAME $AUTHOR $VERSION $LASTMOD $DEBUG $DEBUGMSG $ERRORMSG);
    $NAME       = 'mysqlpool::failover';
    $AUTHOR     = 'rglaue@cait.org';
    $VERSION    = '1.00.001';
    $LASTMOD    = 20060302;
    $DEBUG      = 0;
}

sub new {
    my $pkg     = shift;
    my $class   = ref($pkg) || $pkg;
    my %args    = @_;
    my $self;

    $self       = bless mysqlpool::failover::cache->new, $class;
    $self->{'DEBUG'} = $args{'debug'} || $args{'DEBUG'} || $DEBUG;

    if (ref $args{'cache'} eq "HASH")
    {
        $self->cache_init(%{$args{'cache'}});
        my $cache_file	= $self->cache_file();
        if (-f $cache_file) {
            $self->cache_retrieve();
        }
    } else {
        $self->cache_init();
        warn "Pool failover cache not initialized!\n";
    }

    $self;
}

#
# This is a method to parse a specific type of configuration string which
# identifies a failover pool, or rather a list of servers that make up a
# failover pool.
# The format is as follows:
#   name:myPool;primary:host1.example.org:3306;secondary:host2.example.org;secondary:host3.example.org:3307
# Where each SET consists of the following:
#  identifier:hostdomain[:port][;identifier:hostdomain[:port][;etc..]]
# And where the following is required:
#  identifier "name" = single declaration, name of this failover pool
#  identifier "primary" = single declaration, name of the primary host in this failover pool
#  identifier "secondary" = many declarations, name of a secondary host in this failover pool
# And the order the secondary hosts appearing in the configuration string is the order of
# their priority in the failover pool.
#
# Returning hash configuration:
#  my $poolcfg = _parseParameterString($user_cli_input_string);
#  $poolcfg{'_name'} == "{Server Pool Name}";
#  $poolcfg{'_servers'}{'host#.example.org:{port}'} == (primary|secondary)
#  $poolcfg{'_types'}{'primary'} == [host1.example.org:3306]
#  $poolcfg{'_types'}{'secondary'} == [host2.example.org:3306, host3.example.org:3307]
#
sub _parseParameterString (@) {
    my $self        = shift;
    my $string      = shift;
    my %failoverpool;

    foreach my $failoverserver (split(';',$string)) {
        my ($type,$host,$port,$hostport);
        ($type,$host,$port) = split(":",$failoverserver);

        if ($type eq "name") {
            $failoverpool{'_name'} = $host;
            next;
        }

        $port		||= "3306";
        $hostport	= ($host.":".$port);

        # Do a check here for right 'type' designation
        if (($type ne "primary") && ($type ne "secondary")) {
            return $self->fatalerror("Type of $type is not recognized for host $hostport.");
        }
        $failoverpool{'_servers'}{$hostport} = $type;
        if (($type eq "primary") && (defined $failoverpool{'_types'}{'primary'})) {
            my $curprimary = $failoverpool{'primary'}->[0];
            return $self->fatalerror("Cannot designate host \"$hostport\" as primary, because host \"$curprimary\" is already defined as primary!");
        }
        push ( @{ $failoverpool{'_types'}{$type} }, $hostport );
    }

    return \%failoverpool;
}

sub parseFailoverpoolConfigString {
    my $self        = shift;
    return $self->_parseParameterString(@_);
}
sub joinFailoverpoolConfigHash {
    my $self        = shift;
    my $fohash      = shift;
    my $fostring    = "";

    if (! defined $fohash->{'_name'}) {
        return $self->fatalerror("Failover pool name not defined for failover pool config hash.");
    } else {
        $fostring   .= ("name:".$fohash->{'_name'});
    }
    foreach my $foserver ($fohash->{'_types'}{'primary'}) {
        $fostring   .= (";primary:".$foserver);
    }
    foreach my $foserver ($fohash->{'_types'}{'secondary'}) {
        $fostring   .= (";secondary:".$foserver);
    }

    return $fostring;
}

sub _parseCheckpointString (@) {
    my $self        = shift;
    my $string      = shift;
    my %checkpoints;

    foreach my $checkpoint ( split(';',$string) ) {
        my @checkpoint  = split(':',$checkpoint);
        my $cptype      = shift @checkpoint;
        if ($cptype =~ /server/i) {
            $checkpoints{'server'} = join(':',@checkpoint);
            next;
        }

        my $cpserver    = join(':',@checkpoint);
        push (@{ $checkpoints{'cpservers'}{$cptype} }, $cpserver);
    }

    return \%checkpoints;
}

# parseCheckpointConfigString
# $checkpoint_config_string = "server:servername:port;internal:http:server:port;edge:http:server:port;external:http:server:port"
# \%checkpoint_config_hash = failover->parseCheckpointConfigString($checkpoint_config_string)
sub parseCheckpointConfigString {
    my $self        = shift;
    return $self->_parseCheckpointString(@_);
}
# joinCheckpointConfigHash
# %checkpoint_config_hash = ( server => server:port, checkpoints => { internal => , edge => , external => } )
# $checkpoint_config_string = failover->joinCheckpointConfigHash(\%checkpoint_config_hash)
sub joinCheckpointConfigHash {
    my $self        = shift;
    my $cphash      = shift;
    my $cpstring;

    if (! defined $cphash->{'server'}) {
        return $self->fatalerror("Server not defined for checkpoint config hash");
    } else {
        $cpstring   .= ("server:".$cphash->{'server'});
    }
    foreach my $cptype (keys %{$cphash->{'cpservers'}}) {
        foreach my $cpserver (@{$cphash->{'cpservers'}{$cptype}}) {
            $cpstring   .= (";".$cptype.":".$cpserver);
        }
    }
    return $cpstring;
}

# Assign unknown state to newly defined servers in failover pool
sub init_new_servers () {
    my $self	= shift;

    foreach my $server ( keys %{$self->{'cfg'}->{'_servers'}} ) {
        $self->create_failover_server( server => $server );
        my $server_type     = $self->failover_type(server => $server);
        my $server_state    = $self->failover_state(server => $server);
        my $server_status   = $self->failover_status(server => $server);
        if ((! defined $server_type) || (! defined $server_state) || (! defined $server_status)) {
            warn "INIT SERVER: ",$server,"\n" if $DEBUG;
        }
        if (! defined $server_type) {
            $self->failover_type(server => $server, type => $self->{'cfg'}->{'_servers'}{$server});
        }
        if (! defined $server_state) {
            $self->failover_state(server => $server, state => "UNKNOWN");
        }
        if (! defined $server_status) {
            $self->failover_status(server => $server, status => "OK");
        }
        if ($self->failover_type(server => $server) ne uc $self->{'cfg'}->{'_servers'}{$server}) {
            warn ("CHANGING SERVER TYPE: ".$server." from " .
                $self->failover_type(server => $server)     .
                " to "                                      .
                $self->{'cfg'}->{'_servers'}{$server}       .
                "\n"
                ) if $DEBUG;
        }
    }
    return 1;
}

#
# Setup the configuration of this failover pool
# Pass in either a string (see _parseParameterString), or a hash of
# parameters as follows:
#   name	= SCALAR
#   primary	= [ARRAY]
#   secondary	= [ARRAY]
#
sub config ($) {
    my $self	= shift;
    my (%args, $cfg);
    if ( @_ > 1 ) {
        %args	= @_;
    } else {
        $args{'string'} = shift || return $self->{'cfg'} || return undef;
    }

    if (! defined $args{'string'}) {
        my @config_strings;
        if (defined $args{'servers'}) {
            if (defined $args{'name'}) {
                push ( @config_strings, ("name:".$args{'name'}) );
            }
            if (defined $args{'servers'}{'primary'}) {
                push ( @config_strings, ("primary:".join(";primary:", @{ $args{'servers'}{'primary'} })) );
            }
            if (defined $args{'servers'}{'secondary'}) {
                push ( @config_strings, ("secondary:".join(";secondary:", @{ $args{'servers'}{'secondary'} })) );
            }
        }
        $args{'string'} = join(";".@config_strings);
    }
    $cfg	= _parseParameterString($self, $args{'string'}) || return undef;

    $self->{'cfg'} = $cfg;

    $self->cached_pool_name($self->{'cfg'}->{'_name'});
    $self->cached_pool_config(config => $args{'string'})
                || return $self->fatalerror("Could not set pool configuration(".$args{'string'}.").",$self->errormsg);
    $self->init_new_servers();  # Add new servers into the pool cache

    return $self->{'cfg'};
}

# config_checkpoint
# ( server => server:port, checkpoints => { internal => , edge => , external => } )
# ( string => server:servername:port;internal:http:server:port;edge:http:server:port;external:http:server:port )
sub config_checkpoint ($) {
    my $self    = shift;
    my (%args, $cfg);
    if ( @_ > 1 ) {
        %args   = @_;
    } else {
        $args{'string'} = shift || return $self->{'checkpoints'} || return undef;
    }

    if (! defined $args{'string'}) {
        my @config_strings;
        if (defined $args{'checkpoints'}) {
            if (defined $args{'server'}) {
                push ( @config_strings, ("name:".$args{'server'}) );
            }
            if (defined $args{'checkpoints'}{'external'}) {
                push ( @config_strings, ("external:".join(";external:", @{ $args{'checkpoints'}{'external'} })) );
            }
            if (defined $args{'checkpoints'}{'edge'}) {
                push ( @config_strings, ("edge:".join(";edge:", @{ $args{'checkpoints'}{'edge'} })) );
            }
            if (defined $args{'checkpoints'}{'internal'}) {
                push ( @config_strings, ("internal:".join(";internal:", @{ $args{'checkpoints'}{'internal'} })) );
            }
        }
        $args{'string'} = join(";".@config_strings);
    }
    $cfg	= _parseCheckpointString($self, $args{'string'}) || return undef;
    if (! defined $cfg->{'server'}) {
        return $self->fatalerror("Cannot configure checkpoints for undefined server.");
    }

    $self->{'checkpoints'}{$cfg->{'server'}} = $cfg->{'cpservers'};

    $self->failover_checkpoints( server => $cfg->{'server'}, %{ $cfg->{'cpservers'} } )
        || return $self->fatalerror("Checkpoint initialization failed for server ".$cfg->{'server'}.": ".$self->errormsg());
    $self->cached_checkpoint_config( server => $cfg->{'server'}, config => $args{'string'} )
        || return $self->fatalerror("Checkpoint configuration for server ".$cfg->{'server'}." could not be saved (".$args{'string'}.")");

    return $self->{'checkpoints'};
}

## some utility routines
#
# The "hostport" name must be in format "hostname.example.org:portnumber"
# And this routine make sure of that, using the default mysql port of
# 3306 if a port is not in the provided mysql hostname string.
sub _mysqlHostPortNameSanity ($) {
    my $server	= shift || return undef;
    if ($server !~ /[^\:]*\:[^\:]*/) {
       warn "Server $server is not sane (with port number).\n" if $DEBUG >= 2;
       $server	.= ":3306"
    }
    return $server;
}

# format = human | number | seconds
sub timestamp ($) {
    my $self    = shift;
    my %args	= @_;
    my $format  = $args{'format'} || "human";
    my $time    = $args{'time'} || time;

    return $time if $format eq "seconds";

    # get local time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
    if ($sec < 10)  {  $sec = "0$sec";    }
    if ($min < 10)  {  $min = "0$min";    }
    if ($hour < 10) {  $hour = "0$hour";  }
    if ($mon < 10)  {  $mon = "0$mon";    }
    if ($mday < 10) {  $mday = "0$mday";  }
    my $month = (++$mon);
    $year = $year + 1900;

    my @months     = ("January",   "February", "March",    "April",
                      "May",       "June",     "July",     "August",
                      "September", "October",  "November", "December");

    my $time_date  = "$hour\:$min\:$sec $month/$mday/$year";
    my $short_date = "$month/$mday/$year";
    # fix this Y2K problem better...
    my $long_date  = "$months[$mon] $mday, $year at $hour\:$min\:$sec";
    my $timestamp;
    if ($format eq "human") {
        $timestamp = ($year."-".$month."-".$mday." ".$hour.":".$min.":".$sec);
    } else { # Default timestamp format  eq "number"
        $timestamp = ($year.$month.$mday.$hour.$min.$sec);
    }

    return $timestamp;
}


## Getting information from the pool configuration
#
# get the name of this failover pool
sub pool_name () {
    my $self	= shift;
    return $self->{'cfg'}->{'_name'};
}

# get an array of the primary servers in this failover pool
sub primary_servers () {
    my $self	= shift;
    if ( (defined $self->{'cfg'}->{'_types'}{'primary'})
         && (@{$self->{'cfg'}->{'_types'}{'primary'}} > 0) ) {
        return [@{$self->{'cfg'}->{'_types'}{'primary'}}];
    } else {
        return [];
    }
}

# get an array of the secondary servers in this failover pool
sub secondary_servers () {
    my $self	= shift;
    if ( (defined $self->{'cfg'}->{'_types'}{'secondary'})
          && (@{$self->{'cfg'}->{'_types'}{'secondary'}} > 0) ) {
        return [@{$self->{'cfg'}->{'_types'}{'secondary'}}];
    } else {
        return [];
    }
}

# get an array of the servers with higher priority than the one passed in
# optionally get this list, but only ones matching given status or state
# status = [ OK | OK_WARN | FAIL ]
# state = [ unkown | active | standby | failed_offline | failed_online ]
# @param   server	string, required
# @param   status	string, optional
# @param   state	string, optional
sub higher_priority_servers ($) {
    my $self	= shift;
    my %args	= @_;
    my $server	= _mysqlHostPortNameSanity( $args{'server'} );
    return undef unless $self->verify_element( server => $server );

    my $servers	= [];
    foreach my $hostport (@{ $self->primary_servers() }, @{ $self->secondary_servers() }) {
        last if $hostport eq $server;
        if (defined $args{'status'}) {
            next if $self->failover_status(server => $hostport) ne $args{'status'};
        }
        if (defined $args{'state'}) {
            next if $self->failover_state(server => $hostport) ne $args{'state'};
        }
        push (@$servers,$hostport);
    }
    return $servers;
}

# get an array of the servers with lower priority than the one passed in
# optionally get this list, but only ones matching given status or state
# status = [ OK | OK_WARN | FAIL ]
# state = [ unkown | active | standby | failed_offline | failed_online ]
# @param   server	string, required
# @param   status	string, optional
# @param   state	string, optional
sub lower_priority_servers ($) {
    my $self	= shift;
    my %args	= @_;
    my $server	= _mysqlHostPortNameSanity( $args{'server'} );
    return undef unless $self->verify_element( server => $server );

    my $servers	= [];
    foreach my $hostport (reverse (@{ $self->primary_servers() }, @{ $self->secondary_servers() }) ) {
        last if $hostport eq $server;
        if (defined $args{'status'}) {
            next if $self->failover_status(server => $hostport) ne $args{'status'};
        }
        if (defined $args{'state'}) {
            next if $self->failover_state(server => $hostport) ne $args{'state'};
        }
        push (@$servers,$hostport);
    }
    return $servers;
}

sub get_failover_host (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    my $options     = $args{'options'};
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    my ($serverhost,$serverport)= split(':',$server);
    my $host        = mysqlpool::host::mysql->new( host => $serverhost, port => $serverport, %$options );
    my $cp_hosts    = {};
    my $checkpoints = $self->failover_checkpoints( poolname => $poolname, server => $server );
    foreach my $cptype (keys %{$checkpoints}) {
        foreach my $cpserver (keys %{$checkpoints->{$cptype}}) {
            my ($proto,$hostname,$portnumber) = split(':',$cpserver);
            unless ((defined $proto) && (defined $hostname) && (defined $portnumber)) {
                return $self->fatalerror("Checkpoint server not correctly identified as '$cpserver'.");
            }
            my $cphost  = mysqlpool::host::checkpoint->new( ($cptype.":".$cpserver) );
            push (@{$cp_hosts->{$cptype}}, $cphost);
        }
    }
    $host->checkpoints(%$cp_hosts);
    return $host;
}

sub host_checkpoint() {}
sub host_checkpoint_ok() {}

sub host_type (@) {
    my $self	= shift;
    my %args	= @_;
    my $server	= _mysqlHostPortNameSanity( $args{'server'} );
    return undef unless $self->verify_element( server => $server );

    my $fotype	= $self->failover_type(server => $server);
    if (defined $args{'type'}) {
        if ($fotype =~ /^$args{'type'}$/i) {
            return 1;
        } else {
            return 0;
        }
    } else {
        return $fotype || undef;
    }
}

#
# host_state ( @ )
#
# @param    server      the servername:port identifier
# @param    state       the state to check
#
# example: host_status( server => server1:3306, state => "ACTIVE" );
#    returns 1 or 0  (true/false)
# example: host_status( server => server1:3306 );
#    returns "ACTIVE"
# example: host_status( status => "ACTIVE" );
#    returns [ qw (server1:3306) ]
#
sub host_state (@) {
    my $self	= shift;
    my %args	= @_;

    # type = [ unkown | active | standby | failed_offline | failed_online ]
    if (exists $args{'server'}) {
        my $server  = _mysqlHostPortNameSanity( $args{'server'} );
        return undef unless $self->verify_element( server => $server );

        my $fostate = $self->failover_state(server => $server);
        if (defined $args{'state'}) {
            if ($fostate =~ /^$args{'state'}$/i) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return $fostate || undef;
        }
    } elsif (exists $args{'state'}) {
        my $servers = [];
        foreach my $server ($self->pooled_servers( parsekey => "state", parseval => $args{'state'} )) {
            push (@$servers, $server);
        }
        return $servers;
    }

    $self->errormsg("Invalid call to &mysqlpool::failover::host_state()");
    return undef;
}

sub host_state_ok ($) {
    my $self	= shift;
    my $server	= _mysqlHostPortNameSanity( shift ) || undef;
    return undef unless $self->verify_element( server => $server );

    if ($self->host_state( server => $server, state => "standby")) {
        return 1;
    } elsif ($self->host_state( server => $server, state => "active")) {
        return 1;
    } else {
        return 0;
    }
}

#
# host_status ( @ )
#
# @param    server      the servername:port identifier
# @param    status      the status to check
#
# example: host_status( server => server2:3306, status => "OK" );
#    returns 1 or 0  (true/false)
# example: host_status( server => server2:3306 );
#    returns "OK"
# example: host_status( status => "OK" );
#    returns [ qw (server3:3306 server1:3306 server2:3306) ]
#
sub host_status (@) {
    my $self	= shift;
    my %args	= @_;

    # type = [ OK | OK_WARN | FAIL ]
    if (exists $args{'server'}) {
        my $server      = _mysqlHostPortNameSanity( $args{'server'} );
        return undef unless $self->verify_element( server => $server );

        my $fostatus    = $self->failover_status(server => $server);
        if (defined $args{'status'}) {
            if ($fostatus =~ /^$args{'status'}$/i) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return $fostatus || undef;
        }
    } elsif (exists $args{'status'}) {
        my $servers = [];
        foreach my $server ($self->pooled_servers( parsekey => "status", parseval => $args{'status'} )) {
            push (@$servers, $server);
        }
        return $servers;
    }

    $self->errormsg("Invalid call to &mysqlpool::failover::host_status()");
    return undef;
}

sub host_status_ok ($) {
    my $self	= shift;
    my $server	= _mysqlHostPortNameSanity( shift );
    return undef unless $self->verify_element( server => $server );

    if ($self->host_status( server => $server, status => "OK")) {
        return 1;
    } elsif ($self->host_status( server => $server, status => "OK_WARN")) {
        return 1;
    } else {
        return 0;
    }
}

sub primary_state ($) {
    my $self	= shift;
    my $state	= shift || undef;

    if (defined $state) {
        return $self->host_state( server => ${$self->primary_servers()}[0], state => $state);
    } else {
        return $self->host_state( server => ${$self->primary_servers()}[0]);
    }
}

sub primary_state_ok {
    my $self	= shift;
    return $self->host_state_ok(${$self->primary_servers()}->[0]);
}

sub primary_status ($) {
    my $self	= shift;
    my $status	= shift || undef;

    if (defined $status) {
        return $self->host_status( server => ${$self->primary_servers()}[0], status => $status);
    } else {
        return $self->host_status( server => ${$self->primary_servers()}[0]);
    }
}

sub primary_status_ok {
    my $self	= shift;
    return $self->host_status_ok(${$self->primary_servers()}->[0]);
}

sub higher_priority_server_state ($) {
    my $self	= shift;
    my %args    = @_;
    my $server	= _mysqlHostPortNameSanity( $args{'server'} ) || undef;
    my $state   = $args{'state'} || undef;
    return undef unless $self->verify_element( server => $server, state => $state );

    my $result  = 0;
    foreach my $h_server (@{ $self->higher_priority_servers(server => $server) }) {
        $result = $self->host_state( server => $h_server, state => $state);
        last if $result == 1;
    }
    return $result;
}

sub higher_priority_server_state_ok {
    my $self	= shift;
    my %args    = @_;
    my $server	= _mysqlHostPortNameSanity( $args{'server'} ) || undef;
    return undef unless $self->verify_element( server => $server );

    my $result  = 0;
    foreach my $h_server (@{ $self->higher_priority_servers(server => $server) }) {
        $result = $self->host_state_ok( server => $h_server);
        last if $result == 1;
    }
    return $result;
}

sub higher_priority_server_status ($) {
    my $self	= shift;
    my %args    = @_;
    my $server	= _mysqlHostPortNameSanity( $args{'server'} ) || undef;
    my $status  = $args{'status'} || undef;
    return undef unless $self->verify_element( server => $server, status => $status );

    my $result  = 0;
    foreach my $h_server (@{ $self->higher_priority_servers(server => $server) }) {
        $result = $self->host_status( server => $h_server, status => $status);
        last if $result == 1;
    }
    return $result;
}

sub higher_priority_server_status_ok {
    my $self	= shift;
    my %args    = @_;
    my $server	= _mysqlHostPortNameSanity( $args{'server'} ) || undef;
    return undef unless $self->verify_element( server => $server );

    my $result  = 0;
    foreach my $h_server (@{ $self->higher_priority_servers(server => $server) }) {
        $result = $self->host_status_ok($h_server);
        last if $result == 1;
    }
    return $result;
}

sub lower_priority_server_state ($) {
    my $self	= shift;
    my %args    = @_;
    my $server	= _mysqlHostPortNameSanity( $args{'server'} ) || undef;
    my $state   = $args{'state'} || undef;
    return undef unless $self->verify_element( server => $server, state => $state );

    my $result  = 0;
    foreach my $l_server (@{ $self->lower_priority_servers(server => $server) }) {
        $result = $self->host_state( server => $l_server, state => $state);
        last if $result == 1;
    }
    return $result;
}

sub lower_priority_server_state_ok {
    my $self	= shift;
    my %args    = @_;
    my $server	= _mysqlHostPortNameSanity( $args{'server'} ) || undef;
    return undef unless $self->verify_element( server => $server );

    my $result  = 0;
    foreach my $l_server (@{ $self->lower_priority_servers(server => $server) }) {
        $result = $self->host_state_ok($l_server);
        last if $result == 1;
    }
    return $result;
}

sub lower_priority_server_status ($) {
    my $self	= shift;
    my %args    = @_;
    my $server	= _mysqlHostPortNameSanity( $args{'server'} ) || undef;
    my $status  = $args{'status'} || undef;
    return undef unless $self->verify_element( server => $server, status => $status );

    my $result  = 0;
    foreach my $l_server (@{ $self->lower_priority_servers(server => $server) }) {
        $result = $self->host_status( server => $l_server, status => $status);
        last if $result == 1;
    }
    return $result;
}

sub lower_priority_server_status_ok {
    my $self	= shift;
    my %args    = @_;
    my $server	= _mysqlHostPortNameSanity( $args{'server'} ) || undef;
    return undef unless $self->verify_element( server => $server );

    my $result  = 0;
    foreach my $l_server (@{ $self->lower_priority_servers(server => $server) }) {
        $result = $self->host_status_ok( server => $l_server);
        last if $result == 1;
    }
    return $result;
}





sub fatalerror ($) {
    my $self    = shift;
    $self->errormsg(@_);
    return undef;
}

sub errormsg () {
    my $self    = shift;
    $ERRORMSG   = shift || return $ERRORMSG || return undef;
    warn "\n--ERRORMSG: ",$ERRORMSG,"--\n" if $DEBUG;
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
