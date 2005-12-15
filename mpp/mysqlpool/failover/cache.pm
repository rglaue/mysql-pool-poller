package mysqlpool::failover::cache;

##
# mysqlpool::failover::cache    ver1.00.000/REG     20051214
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
    $VERSION    = '1.00.000';
    $LASTMOD    = 20051214;
    $DEBUG      = 0;

    use vars  qw(@CACHE_STORE_REFS);
}

END {
    while (my $objs = shift @CACHE_STORE_REFS)
    {
        next unless $objs->cache_file();
        warn "Storing cache for object\n" if $DEBUG;
        $objs->cache_store() || warn(("Error: Could not save cache to file: ".$objs->cache_file().".\n"));
        $objs = undef;
    }
}

sub cache_init {};

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


# Cache object routines

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
        push(@CACHE_STORE_REFS, $self);
    }
}

sub cache_file ($) {
    my $self	= shift || return undef;
    my $file	= shift || return $self->{'_cache_file'} || return undef;
    $self->{'_cache_file'} = $file;
}

sub cache_retrieve ($) {
    my $self	= shift || return undef;
    my $file	= shift || $self->cache_file() || return undef;
    $self->cache_file($file);
    $self->{'_cache'} = undef;
    $self->{'_cache'} = lock_retrieve($file);
}

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

sub polled_servers () {
    my $self	= shift || return undef;
    return keys %{ $self->{'_cache'}->{'_server_poll'} }
}

# @param    server      server to delete from poll list
sub polled_server_delete ($) {
    my $self    = shift || return undef;
    my %args    = @_;
    my $server  = $args{'server'} || undef;
    return undef unless $self->verify_element( server => $server );

    delete $self->{'_cache'}->{'_server_poll'}->{$server};
}

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
        $self->{'_cache'}->{'_server_poll'}->{$server}->{'last_status_message'} = "";
    } elsif ($message eq '--') {
        delete $self->{'_cache'}->{'_server_poll'}->{$server}->{'last_status_message'};
    } else {
        $self->{'_cache'}->{'_server_poll'}->{$server}->{'last_status_message'} = $message;
    }
}

sub number_of_requests ($) {
    my $self    = shift || return undef;
    my %args    = @_;
    my $server  = $args{'server'} || undef;
    return undef unless $self->verify_element( server => $server );

    my $reqnum;
    if (! exists $args{'requests'}) {
        return $self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'};
    } else {
        $reqnum  = $args{'requests'} || 0;
    }
    if ($reqnum eq '++') {
        if ($self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'} >= 0) {
            $self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'}++;
        } else {
            $self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'} = 1;
        }
    } elsif ($reqnum eq '--') {
        if ($self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'} >= 1) {
            $self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'}--;
        } else {
            $self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'} = 0;
        }
    } else {
        $self->{'_cache'}->{'_server_poll'}->{$server}->{'number_of_requests'} = $reqnum;
    }
}

sub last_request_time ($) {
    my $self    = shift || return undef;
    my %args    = @_;
    my $server  = $args{'server'} || undef;
    return undef unless $self->verify_element( server => $server );

    my $reqtime = $args{'time'} || return $self->{'_cache'}->{'_server_poll'}->{$server}->{'last_request_time'};
    $self->{'_cache'}->{'_server_poll'}->{$server}->{'last_request_time'} = $reqtime;
}

# Pool of FAILOVER servers

# Specify the name of the failover pool this object instance will handle
sub cached_pool_name ($) {
    my $self        = shift || return undef;
    my $poolname    = shift || return $self->{'_failover_pool_name'};
    $self->{'_failover_pool_name'} = $poolname;
}

sub cached_pool_config (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
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
        $self->{'_cache'}->{'_failover_pool_config'}->{$poolname} = $args{'config'};
    }
}

sub get_cached_pool_names () {
    my $self        = shift || return undef;
    return [keys %{$self->{'_cache'}->{'_failover_pool_config'}}] || undef;
}

sub cached_checkpoint_config (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'} || return $self->fatalerror("Cannot retrieve/store checkpoint config for undefined server!");
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    my $checkpointconfig    = $args{'config'} || return $self->{'_cache'}->{'_server_checkpoint_config'}->{$poolname}->{$server};
    $self->{'_cache'}->{'_server_checkpoint_config'}->{$poolname}->{$server} = $checkpointconfig;
}

# Return a list of servers in the named failover pool
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


# Delete a specified server from the failover pool
sub pooled_server_delete (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    delete $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server};
}


# Type of server this host is acting as in the cluster
# type = [ primary | secondary ]
sub failover_type (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    if ((exists $args{'type'}) && (defined $args{'type'})) {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_type'} = uc $args{'type'};
    } elsif ((exists $args{'type'}) && (! defined $args{'type'})) {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_type'} = undef;
    } else {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_type'};
    }
}

# State of server this host is in for this cluster
# state = [ UNKNOWN | ACTIVE | STANDBY | FAILED_OFFLINE | FAILED_ONLINE ]
sub failover_state (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    if ((exists $args{'state'}) && (defined $args{'state'})) {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_state'} = uc $args{'state'};
    } elsif ((exists $args{'state'}) && (! defined $args{'state'})) {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_state'} = undef;
    } else {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_state'};
    }
}

# Status of server this host is known as in its failover_state for this cluster
# status = [ OK | OK_WARN | FAIL ]
sub failover_status (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    if ((exists $args{'status'}) && (defined $args{'status'})) {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_status'} = uc $args{'status'};
    } elsif ((exists $args{'status'}) && (! defined $args{'status'})) {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_status'} = undef;
    } else {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'failover_status'};
    }
}

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

sub create_failover_server (@) {
    my $self        = shift;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    return undef unless $self->verify_element( poolname => $poolname );

    if ($self->exists_failover_server( poolname => $poolname, server => $server)) {
        return 1;
    }
    if (! exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}) {
        $self->{'_cache'}->{'_failover_pool'}->{$poolname} = {};
    }
    $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server} = {};
}

# Error Message from failover error
sub failover_error_message (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    return undef unless $self->verify_element( poolname => $poolname, server => $server );

    my $message = $args{'message'} || return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'error_message'};
    if ($message eq '--') {
        delete $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'error_message'};
    } else {
        $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'error_message'} = $message;
    }
}

sub failover_checkpoint (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    my $cptype      = $args{'checkpoint'}{'type'}   || undef;  # internal, edge, external
    my $cpserver    = $args{'checkpoint'}{'server'} || undef;  # "proto:server:port"
    my $cpstatus    = $args{'checkpoint'}{'status'} || undef;
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
        $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver} = $cpstatus;
    } else {
        return $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver};
    }
}

sub create_failover_server_checkpoint (@) {
    my $self        = shift || return undef;
    my %args        = @_;
    my $poolname    = $args{'poolname'} || $self->cached_pool_name();
    my $server      = $args{'server'};
    my $cptype      = $args{'checkpoint'}{'type'}   || undef;  # internal, edge, external
    my $cpserver    = $args{'checkpoint'}{'server'} || undef;  # "proto:server:port"
    my $cpstatus    = $args{'checkpoint'}{'status'} || undef;
    return undef unless $self->verify_element( poolname => $poolname, server => $server );
    unless ( split(':',$cpserver) == 3) {
        return $self->fatalerror("Parameter checkpoint->server must be defined as 'proto:server:port'.");
    }
    if (! exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}) {
        $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype} = {};
    }
    if (exists $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver}) {
        return $self->fatalerror("Checkpoint creation failed, $cptype -> $cpserver already exists for $server in pool $poolname.");
    } else {
        $self->{'_cache'}->{'_failover_pool'}->{$poolname}->{$server}->{'checkpoints'}->{$cptype}->{$cpserver} = $cpstatus;
    }
}

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
            return undef if ! defined $exists;
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

# Delete from both the polled list as well as the failover pool
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

sub cache_dump () {
    my $self    = shift;
    use Data::Dumper;
    # local $Data::Dumper::Purity = 1;
    $Data::Dumper::Indent = 1;
    return Data::Dumper->Dumper($self->{'_cache'});
}


sub fataladderror ($) {
    my $self    = shift;
    my $msg     = shift;
       $msg    .= "\n";
       $msg    .= $self->errormsg();
    return $self->fatalerror($msg);
}

sub fatalerror ($) {
    my $self    = shift;
    $self->errormsg(@_);
    return undef;
}

sub warnerror ($) {
    my $self    = shift;
    $self->errormsg(@_);
    return undef;
}

sub adderror ($) {
    my $self    = shift;
    my $msg = shift;
       $msg .= "\n";
       $msg .= $self->errormsg();
    $self->errormsg($msg);
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
