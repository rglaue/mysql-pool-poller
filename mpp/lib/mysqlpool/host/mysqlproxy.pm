package mysqlpool::host::mysqlproxy;

##
# mysqlpool::host::mysqlproxy        ver1.00.000/REG     20071110
# object to manage a mysql proxy host
##

use strict;
use DBI;

use mysqlpool::host::generic;

BEGIN {
    use vars    qw(@ISA);
    @ISA        = qw(mysqlpool::host::generic);

    use vars    qw($NAME $AUTHOR $VERSION $LASTMOD $DEBUG $DEBUGMSG $ERRORMSG);
    $NAME       = 'mysqlpool::host::mysqlproxy';
    $AUTHOR     = 'rglaue@cait.org';
    $VERSION    = '1.00.000';
    $LASTMOD    = 20071110;
    $DEBUG      = 0;
}

# Inherited functions: host, port, postport, ping, connect, disconnect, isUp,
#   checkpoints, has_checkpoints, poll_checkpoints,
#   fatalerror, errormsg, debugmsg
#   Requiring overwritting: connect, disconnect
#   Actually overwritten: connect, disconnect, isUp

sub DEFAULT_PORT { "3306" };

sub new {
    my $pkg         = shift;
    my $class       = ref($pkg) || $pkg;
    my %args        = @_;
    $args{'port'}   = DEFAULT_PORT if $args{'port'} =~ /default/i;

    my $rhash   = bless mysqlpool::host::generic->new(%args), $class;

    unless ((exists $args{'host'}) && (exists $args{'port'}) && (exists $args{'username'}) && (exists $args{'password'})) {
        return $rhash->fatalerror("arguments host,port,username,password must be defined for new host.");
    }

    # SET DEFAULT VALUES
    $rhash->port                ("3306");

    $rhash->host                ($args{'host'})                 if exists $args{'host'};
    $rhash->port                ($args{'port'})                 if exists $args{'port'};
    $rhash->username            ($args{'username'})             if exists $args{'username'};
    $rhash->password            ($args{'password'})             if exists $args{'password'};

    return $rhash;
}

# Set/Get the timeout for host evaluations
sub timeout ($) {
    my $self    = shift;
    my $timeout = shift || undef;
    if (! defined $timeout) {
        if ((! defined $self->{'_connect_timeout'}) && (! $self->{'_connect_timeout'} >= 0)) {
            $self->{'_connect_timeout'} = 5;
            return 5;  # default timeout
        } else {
            return $self->{'_connect_timeout'};
        }
    } else {
        return $self->{'_connect_timeout'} = $timeout;
    }
}

# Get/construct/auto-generate the MySQL DSN for connections 
sub dsn {
    my $self	= shift;
    my $timeout = $self->timeout();
    # return ( "DBI:mysql:database=".$self->cache_database().";host=".$self->host().";port=".$self->port().";mysql_connect_timeout=".$timeout );
    return ( "DBI:mysql:host=".$self->host().";port=".$self->port().";mysql_connect_timeout=".$timeout );
}

# Close the MySQL connection
sub close () {
    my $self	= shift;
    if (! defined $self->{'_dbh'}) {
        return 1;
    } else {
        return $self->{'_dbh'}->disconnect();
    }
}

# Disconnect the MySQL connection
# Alias for close()
sub disconnect () {
    my $self    = shift;
    $self->close(@_);
}

# Set/Get The MySQL username used for connection authorization
sub username {
    my $self	= shift || return undef;
    my $username	= shift || undef;
    if (!defined $username) {
        return $self->{'_username'} || undef;
    }
    $self->{'_username'} = $username || undef;
}

# Set/Get The MySQL password used for connection authorization
sub password {
    my $self	= shift || return undef;
    my $password	= shift || undef;
    if (!defined $password) {
        return $self->{'_password'} || undef;
    }
    $self->{'_password'} = $password || undef;
}

# Simple/Generic connect using this modules auto dsn generator.
sub connect ($$) {
    my $self	= shift;
    print "CONNECT: ",$self->dsn(),"\n" if $DEBUG;
    my $username	= shift || $self->username() || undef;
    my $password	= shift || $self->password() || undef;
    my %args        = @_;
    my $timeout     = $args{'timeout'} || 4;
    my $dsn         = $self->dsn();
    my $dbh;
    print ("MySQL Connect called for ".$self->hostport()." host.\n") if $DEBUG;
    if (defined $username) {
        my $code    = sub { DBI->connect($dsn, $username, $password, {'RaiseError' => 0, AutoCommit => 0}) };
        $dbh        =
            $self->eval_exe_timeout ( $code, ($timeout + 1) )
            || return $self->fatalerror( DBI::errstr() );
        # an attempt to deal with mysql bug #32464 for DBD::mysql
        # if ((DBI::errstr()) && (DBI::errstr() !~ /AutoCommit failed/)) {
        #     return $self->fatalerror( DBI::errstr() );
        # }
    } else {
        my $code    = sub { DBI->connect($dsn, {'RaiseError' => 0}) };
        $dbh        =
            $self->eval_exe_timeout ( $code, ($timeout + 1) )
            || return $self->fatalerror( DBI::errstr() );
    }
    if (! defined $dbh) {
        $self->errormsg(DBI::errstr());
        return undef;
    }
    return $self->dbhandle($dbh);
}

# Set/Get the dbh database handle
sub dbhandle ($) {
    my $self	= shift;
    my $dbh;
    if ((defined $self->{'_dbh'}) && ($self->{'_dbh'}->ping())) {
        $dbh	= shift || return $self->{'_dbh'};
    } else {
        if (($DEBUG) && (! defined $_[0])) {
            print ("MySQL dbhhandle() called for ".$self->hostport()." host.");
            print (" -- creating new handle with connect()\n");
        }
        $dbh	= shift || $self->connect();
    }
    if (! defined $dbh) {
        $self->errormsg(DBI::errstr);
        return undef;
    }
    $self->{'_dbh'} = $dbh;
    return $self->{'_dbh'};
}

# Is the MySQL host up?
sub isUp ($) {
    my $self    = shift || return undef;
    my $dbh     = $self->dbhandle(@_) || return 0;
    my $ping    = $dbh->ping() || return 0;
    return $ping;
}


# Proxy Loading routines

sub send_mpp_command ($) {
    my $self	= shift || return undef;
    my $command	= shift || return undef;

    my $mql	= ("MPP ".$command); # hard coded beginning of mql string

    my $dbh     = $self->dbhandle() || return $self->fatalerror("Could not connect to mysql; ".$self->dsn()."\n");
    my $sth	= $dbh->prepare($mql);
    $sth->execute() || return $self->fatalerror("Query Error ".$DBI::errstr."\n");
    my $result	= $sth->fetchrow_hashref() || undef;
    $sth->finish();
    # $dbh->disconnect();

    if ($DEBUG) {
        foreach my $k (keys %$result) {
            print ("($mql) RESULT: ".$result->{$k}."\n");
        }
    }

    return $result;
}
sub send_mpp_command_multi ($) {
    my $self	= shift || return undef;
    my $command	= shift || return undef;

    my $mql     = ("MPP ".$command);

    my $dbh     = $self->dbhandle() || return $self->fatalerror("Could not connect to mysql; ".$self->dsn()."\n");
    my $sth     = $dbh->prepare($mql);
    $sth->execute() || return $self->fatalerror("Query Error ".$DBI::errstr."\n");
    my @results;
    while (my $result	= $sth->fetchrow_hashref()) {
        push(@results,$result);
    }
    $sth->finish();
    # $dbh->disconnect();

    if ($DEBUG) {
        foreach my $result (@results) {
            foreach my $k (keys %$result) {
                print ("($mql) RESULT: ".$result->{$k}."\n");
            }
        }
    }

    return \@results;
}

sub initialize_node (@) {
    my $self    = shift || return undef;
    # my %args    = @_;
    my $node	= shift || return undef;
    my $element	= shift || return undef;
    my $value	= shift || return undef;
    my $cmd     = ("INITIALIZE $node $element $value");

    return $self->send_mpp_command($cmd);
}

sub set_node (@) {
    my $self	= shift || return undef;
    my %args    = @_;
    my $node    = $args{'node'}    || return undef;
    my $type    = $args{'type'}    || undef;
    my $state   = $args{'state'}   || undef;
    my $status  = $args{'status'}  || undef;
    my $weight  = $args{'weight'}  || undef;
    unless ((defined $type) || (defined $state) || (defined $status) || (defined $weight)) {
        return $self->fatalerror("Error setting node, type, state or status not defined.");
    }
    my $ret = {};

    # MPP-as-Lua will return the string "SUCCESS" or an ERROR message, in a query table, for each successful execution
    # It is up to the caller to read the response to determine SUCCESS or FAILURE
    if (defined $type) {
        $ret->{'type'} = $self->send_mpp_command("SET $node TYPE $type") || return $self->fatalerror("Could not set $node type to $type");
    }
    if (defined $state) {
        $ret->{'state'} = $self->send_mpp_command("SET $node STATE $state") || return $self->fatalerror("Could not set $node state to $state");
    }
    if (defined $status) {
        $ret->{'status'} = $self->send_mpp_command("SET $node STATUS $status") || return $self->fatalerror("Could not set $node status to $status");
    }
    if (defined $weight) {
        $ret->{'weight'} = $self->send_mpp_command("SET $node WEIGHT $weight") || return $self->fatalerror("Could not set $node weight to $weight");
    }
    return $ret;
}

sub set_node_type ($$) {
    my $self	= shift || return undef;
    my $node	= shift || return undef;
    my $value	= shift || return undef;

    my $ret     = $self->set_node(node => $node, type => $value) || return undef;
    return $ret->{'type'};
}

sub set_node_state ($$) {
    my $self	= shift || return undef;
    my $node	= shift || return undef;
    my $value	= shift || return undef;

    my $ret     = $self->set_node(node => $node, state => $value) || return undef;
    return $ret->{'state'};
}

sub set_node_status ($$) {
    my $self	= shift || return undef;
    my $node	= shift || return undef;
    my $value	= shift || return undef;

    my $ret     = $self->set_node(node => $node, status => $value) || return undef;
    return $ret->{'status'};
}

sub set_node_weight ($$) {
    my $self	= shift || return undef;
    my $node	= shift || return undef;
    my $value	= shift || return undef;

    my $ret     = $self->set_node(node => $node, weight => $value) || return undef;
    return $ret->{'weight'};
}

sub show ($) {
    my $self	= shift || return undef;
    my $node	= shift || "ALL";

    return $self->send_mpp_command_multi("SHOW ALL");
}

1;
__END__
