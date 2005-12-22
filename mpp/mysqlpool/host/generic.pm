package mysqlpool::host::generic;

##
# mysqlpool::host::generic      ver1.00.000/REG     20051222
# Generic host Object to manage interfacing a host, and manage its checkpoints.
# This object is intended to be subclassed by mysqlpool::host::* modules.
# (See mysqlpool::host::simple for an example on how to subclass this class)
#   The managed checkpoints are:
#       internal    - An internal host on the same network
#       edge        - An edge server which operates between the local network
#                       and the internet, or other network (router/firewall/bridge)
#       external    - An external host on the internet
##

use strict;


BEGIN {
    use vars    qw($NAME $AUTHOR $VERSION $LASTMOD $DEBUG $DEBUGMSG $ERRORMSG);
    $NAME       = 'mysqlpool::host::generic';
    $AUTHOR     = 'rglaue@cait.org';
    $VERSION    = '1.00.000';
    $LASTMOD    = 20051222;
    $DEBUG      = 0;
}

#
# Use this function for code that makes calls to some networking
# library functions like gethostbyname() are known to have their
# own implementations of timeouts which may conflict with your 
# timeouts.
# This function forces a process that makes one of these calls
# to timeout, by force, whether they want to or not.
# POSIX::sigaction bypasses the Perl safe signals (note that this
# means subjecting yourself to possible memory corruption).
#
# Ping Example:
# my $ping = Net::Ping->new();
# my $ping_value = eval_exe_timeout( sub{ $ping->($host, $timeout) }, ($timeout + 1) );
#
# HTTP Example:
# my $httpconn = eval_exe_timeout( sub{ Net::HTTP->new( Host => $host, Timeout => $timeout ) }, ($timeout + 1) );
#
sub eval_exe_timeout ($$) {
    my $code    = shift; # a reference subroutine
    my $timeout = shift; # Value to force a time out; suggested at {code_timeout}+1
                         # so if you do $ping->($host, 8), this timeout might be 9

    return
        eval {
            use POSIX qw(SIGALRM);
            POSIX::sigaction(SIGALRM,
                             POSIX::SigAction->new(sub { die "eval_exe_timeout: alarm at $timeout seconds." }))
                             or die "Error setting POSIX SIGALRM handler: $!\n";
            POSIX::alarm($timeout);
            my $ret = &$code;
            POSIX::alarm(0);
            return $ret;
        };
}

sub new {
    my $pkg     = shift;
    my $class   = ref($pkg) || $pkg;
    my %args    = @_;

    my $host    = $args{'host'} || undef;
    my $port    = $args{'port'} || undef;
    my $self    = bless {}, $class;
    $self->{'DEBUG'} = $args{'debug'} || $args{'DEBUG'} || $DEBUG;

    $self->host($host) if defined $host;
    $self->port($port) if defined $port;

    return $self;
}

# host
# get a string of the host name value for this object
# returns   <hostname> or undef if not set
# set the host name for this object.
# @param    <hostname>
# returns   1       successful
sub host ($) {
    my $self            = shift;
    my $host            = shift || undef;

    if (! defined $host) {
        return $self->{'_host'} || undef;
    }
    $self->{'_host'} = $host || undef;
}

sub DEFAULT_PORT { "7" }

# port
# get a string of the port number value for this object
# returns   <portnumber> or undef if not set
# set the port number for this object.
# @param    <portnumber>
# returns   1       successful
sub port ($) {
    my $self            = shift;
    my $port            = shift || undef;
    $port               = $self->DEFAULT_PORT if $port =~ /default/i;

    if (! defined $port) {
        return $self->{'_port'} || $self->DEFAULT_PORT;
    }
    $self->{'_port'} = $port;
}

# hostport
# get a string of the host:port value for this object
# returns   <hostname:portnumber> or undef if host->host or host->port not set
# set the host name and port number for this object.
# @param    <hostname:portnumber>
# returns   1       successful
sub hostport ($) {
    my $self            = shift;
    my $hostport        = shift || undef;

    if (! defined $hostport) {
        my $host    = $self->host() || return undef;
        my $port    = $self->port() || return undef;
        return ( $host .":". $port );
    } else {
        my ($host,$port) = split(':',$hostport);
        $self->host($host) if defined $host;
        $self->port($port) if defined $port;
        return 1;
    }
}

# Checkpoint Identification String
sub checkpoint_id ($) {
    my $self            = shift;
    my $id              = shift || undef;
    if (! defined $id) {
        return $self->{'_id'};
    } else {
        $self->{'_id'}  = $id;
    }
}

# ping
# ping the host
# returns   1       successful
# returns   0       unsuccessful
# returns   undef   error; error message in &errormsg()
sub ping () {
    my $self            = shift;
    my %args            = @_;
    my $port            = $args{'port'} || "object";
    my $timeout         = $args{'timeout'} || 4;

    use Net::Ping;
    my $ping        = Net::Ping->new();
    if ($port eq "default") {
        $self->debugmsg("Using default server echo port for ping.");
    } elsif ($port eq "object") {
        $self->debugmsg("Using host object port ".$self->port." for ping.");
        $ping->{'port_num'} = $self->port;
    }
    my $host    = $self->host;
    if (! defined $host) {
        return fatalerror("Cannot ping. Host name not defined for this host object.");
    }
    if ( $self->eval_exe_timout ( sub { $self->ping($self->host, $timeout) }, ($timeout + 1) ) ) {
        $ping->close();
        return 1;
    } else {
        $ping->close();
        return 0;
    }
}

# connect to host
# returns   <connect object>
# returns   undef   error; error message in &errormsg()
sub connect (@) {
    my $self            = shift;
    my %args            = @_;
    return $self->fatalerror("Function host::generic::connect called by object ".ref($self).", which should have been overwritten by the subclass.");
}

# disconnect from host
# returns   1       successful
# returns   0       unsuccessful
# returns   undef   error; error message in &errormsg()
sub disconnect (@) {
    my $self            = shift;
    my %args            = @_;
    return $self->fatalerror("Function host::generic::disconnect called by object ".ref($self).", which should have been overwritten by the subclass.");
}

# isUp
# Is the host "UP"
# returns   1       successful
# returns   0       unsuccessful
# returns   undef   error; error message in &errormsg()
sub isUp ($) {
    my $self            = shift || return undef;
    my $conn            = $self->connect(@_);
    if (! defined $conn) {
        return 0;
    }
    my $ping            = $self->ping(@_);
    if (! defined $ping) {
        $self->errormsg("Could not establish a ping to host ".$self->hostport);
        return undef;
    }
    return $ping;
}

# poll_connect
# poll a host for connectability
# returns   ()      array of error message in polling host connect if any
sub poll_connect (@) {
    my $self            = shift;
    my %args            = @_;
    my $message         = ("Function host::generic::poll_connect called by object ".ref($self).", which should have been overwritten by the subclass.");
    $self->errormsg($message);
    return ($message);
}

# poll_request
# poll a host for requestability
# returns   ()      array of error message in polling host request if any
sub poll_request (@) {
    my $self            = shift;
    my %args            = @_;
    my $message         = ("Function host::generic::poll_request called by object ".ref($self).", which should have been overwritten by the subclass.");
    $self->errormsg($message);
    return ($message);
}


# checkpoints
# Set the checkpoint or retrieve a HASH of the checkpoints
# @param    internal => []  set an array of internal mysqlpool::host::<object> checkpoints
# @param    edge     => []  set an array of edge mysqlpool::host::<object> checkpoints
# @param    external => []  set an array of external mysqlpool::host::<object> checkpoints
sub checkpoints (@) {
    my $self    = shift;
    my %args    = @_;

    if (    (! exists $args{'internal'})
        ||  (! exists $args{'edge'})
        ||  (! exists $args{'external'})
       )
    {
        return $self->{'_checkpoint'};
    }
    if (exists $args{'internal'}) {
        $self->{'_checkpoint'}->{'_internal'} = $args{'internal'};
    }
    if (exists $args{'edge'}) {
        $self->{'_checkpoint'}->{'_edge'} = $args{'edge'};
    }
    if (exists $args{'external'}) {
        $self->{'_checkpoint'}->{'_external'} = $args{'external'};
    }
}

# has_checkpoints
# Determine if this object has checkpoints
# returns   1       true
# returns   0       false
sub has_checkpoints () {
    my $self        = shift;
    if (exists $self->{'_checkpoint'}) {
        return 1;
    } else {
        return 0;
    }
}

# poll_checkpoints
# Poll all the checkpoints and return a HASH of the servers polled, plus an array of any error messages
# returns   {HASH}  A hash of checkpoints->server->[error messages] after polling the checkpoints
sub poll_checkpoints () {
    my $self        = shift;
    my %args        = @_;
    my $failures    = {};

    if (    (! exists $args{'external'})
        ||  ((exists $args{'external'}) && ($args{'external'} == 1))
       )
    {
        foreach my $host (@{ $self->{'_checkpoint'}->{'_external'} }) {
            $failures->{$host->checkpoint_id} = [];
            my @host_failures = $host->poll_connect();
            unless (@host_failures == 0) {
                my @errors;
                push ( @errors, ("Could not reach external checkpoint host ".$host->hostport.".") );
                push ( @errors, @host_failures );
                # push ( @errors, $host->errormsg() );
                push ( @{ $failures->{$host->checkpoint_id} }, join(" ",@errors) )
            }
        }
    }
    if (    (! exists $args{'edge'})
        ||  ((exists $args{'edge'}) && ($args{'edge'} == 1))
        )
    {
        foreach my $host (@{ $self->{'_checkpoint'}->{'_edge'} }) {
            $failures->{$host->checkpoint_id} = [];
            my @host_failures = $host->poll_connect();
            unless (@host_failures == 0) {
                my @errors;
                push ( @errors, ("Could not reach edge checkpoint host ".$host->hostport.".") );
                push ( @errors, @host_failures );
                # push ( @errors, $host->errormsg() );
                push ( @{ $failures->{$host->checkpoint_id} }, join(" ",@errors) )
            }
        }
    }
    if (    (! exists $args{'internal'})
        ||  ((exists $args{'internal'}) && ($args{'internal'} == 1))
        )
    {
        foreach my $host (@{ $self->{'_checkpoint'}->{'_internal'} }) {
            $failures->{$host->checkpoint_id} = [];
            my @host_failures = $host->poll_connect();
            unless (@host_failures == 0) {
                my @errors;
                push ( @errors, ("Could not reach internal checkpoint host ".$host->hostport.".") );
                push ( @errors, @host_failures );
                # push ( @errors, $host->errormsg() );
                push ( @{ $failures->{$host->checkpoint_id} }, join(" ",@errors) )
            }
        }
    }

    return $failures;
}


sub fatalerror ($) {
    my $self            = shift;
    $self->errormsg(@_);
    return undef;
}

sub errormsg () {
    my $self            = shift;
    $self->debugmsg(@_);
    if (@_ >= 1) {
        $ERRORMSG   = join("\n",@_);
    } else {
        return $ERRORMSG || return undef;
    }
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
