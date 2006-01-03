package mysqlpool::host::mysql;

##
# mysqlpool::host::mysql        ver1.00.000/REG     20060103
# object to manage a mysql host
##

use strict;
use DBI;

use mysqlpool::host::generic;

BEGIN {
    use vars    qw(@ISA);
    @ISA        = qw(mysqlpool::host::generic);

    use vars    qw($NAME $AUTHOR $VERSION $LASTMOD $DEBUG $DEBUGMSG $ERRORMSG);
    $NAME       = 'mysqlpool::host::mysql';
    $AUTHOR     = 'rglaue@cait.org';
    $VERSION    = '1.00.000';
    $LASTMOD    = 20051214;
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
    $rhash->cache_database      ("test");
    $rhash->cache_master_table  ("cache_master_status");
    $rhash->cache_slave_table   ("cache_slave_status");

    $rhash->host                ($args{'host'})                 if exists $args{'host'};
    $rhash->port                ($args{'port'})                 if exists $args{'port'};
    $rhash->username            ($args{'username'})             if exists $args{'username'};
    $rhash->password            ($args{'password'})             if exists $args{'password'};
    $rhash->cache_database      ($args{'cache_database'})       if exists $args{'cache_database'};
    $rhash->cache_master_table  ($args{'cache_master_table'})   if exists $args{'cache_master_table'};
    $rhash->cache_slave_table   ($args{'cache_slave_table'})    if exists $args{'cache_slave_table'};

    return $rhash;
}

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

sub dsn {
    my $self	= shift;
    my $timeout = $self->timeout();
    return ( "DBI:mysql:database=".$self->cache_database().";host=".$self->host().";port=".$self->port().";mysql_connect_timeout=".$timeout );
}

sub close () {
    my $self	= shift;
    if (! defined $self->{'_dbh'}) {
        return 1;
    } else {
        return $self->{'_dbh'}->disconnect();
    }
}

sub disconnect () {
    my $self    = shift;
    $self->close(@_);
}

sub username {
    my $self	= shift || return undef;
    my $username	= shift || undef;
    if (!defined $username) {
        return $self->{'_username'} || undef;
    }
    $self->{'_username'} = $username || undef;
}

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
        my $code    = sub { DBI->connect($dsn, $username, $password, {'RaiseError' => 0}) };
        $dbh        =
            $self->eval_exe_timeout ( $code, ($timeout + 1) )
            || return $self->fatalerror( DBI::errstr() );
    } else {
        my $code    = sub { DBI->connect($dsn, {'RaiseError' => 0}) };
        $dbh        =
            $self->eval_exe_timeout ( $code, ($timeout + 1) )
            || return $self->fatalerror( DBI::errstr() );
    }
    if (! defined $dbh) {
        $self->errormsg($dbh->errstr);
        return undef;
    }
    return $self->dbhandle($dbh);
}

sub dbhandle ($) {
    my $self	= shift;
    my $dbh;
    if (defined $self->{'_dbh'}) {
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

sub isUp ($) {
    my $self    = shift || return undef;
    my $dbh     = $self->dbhandle(@_) || return 0;
    my $ping    = $dbh->ping() || return 0;
    return $ping;
}

sub cache_database {
    my $self		= shift || return undef;
    my $database	= shift || undef;
    if (!defined $database) {
        return $self->{'_cache_database'} || undef;
    }
    $self->{'_cache_database'} = $database || undef;
}

sub database {
    my $self	= shift;
    return $self->cache_database(@_);
}

sub cache_master_table {
    my $self	= shift || return undef;
    my $table	= shift || undef;
    if (!defined $table) {
        return $self->{'_cache_master_table'} || undef;
    }
    $self->{'_cache_master_table'} = $table || undef;
}

sub cache_slave_table {
    my $self	= shift || return undef;
    my $table	= shift || undef;
    if (!defined $table) {
        return $self->{'_cache_slave_table'} || undef;
    }
    $self->{'_cache_slave_table'} = $table || undef;
}

sub get_master_status () {
    my $self	= shift || return undef;
    my $sql	= "SHOW MASTER STATUS";

    my $dbh	= $self->dbhandle() || return $self->fatalerror("Could not connect to mysql; ".$self->dsn()."\n");
    my $sth	= $dbh->prepare($sql);
    $sth->execute();
    my $status	= $sth->fetchrow_hashref();
    $sth->finish();

    return $status;
}

sub get_slave_status () {
    my $self	= shift || return undef;
    my $sql	= "SHOW SLAVE STATUS";

    my $dbh	= $self->dbhandle() || return $self->fatalerror("Could not connect to mysql; ".$self->dsn()."\n");
    my $sth	= $dbh->prepare($sql);
    $sth->execute();
    my $status	= $sth->fetchrow_hashref();
    $sth->finish();

    return $status;
}

sub slaveReplicationOK ($) {
    my $self	= shift;
    my $status	= $self->get_slave_status();
    my $io	= $status->{'Slave_IO_Running'};
    my $sql	= $status->{'Slave_SQL_Running'};

    if (($io eq 'Yes') && ($sql eq 'Yes')) {
	return 1;
    } else {
	return 0;
    }
}

# Caching subroutines

sub get_cache_master_status ($) {
    my $self	= shift || return undef;
    my $mysqlhost	= shift || $self;  # MySQL database host to read from.
    my $master_table	= $self->cache_master_table();
    my $MySQL_Host	= $self->host();
    my $dbh	= $mysqlhost->dbhandle() || return $self->fatalerror("Could not connect to mysql; ".$mysqlhost->dsn()."\n");
    return _get_cache_status($dbh,$master_table,$MySQL_Host);
}

sub get_cache_slave_status ($) {
    my $self	= shift || return undef;
    my $mysqlhost	= shift || $self;  # MySQL database host to read from.
    my $slave_table	= $self->cache_slave_table();
    my $MySQL_Host	= $self->host();
    my $dbh	= $mysqlhost->dbhandle() || return $self->fatalerror("Could not connect to mysql; ".$mysqlhost->dsn()."\n");
    return _get_cache_status($dbh,$slave_table,$MySQL_Host);
}

sub set_cache_master_status ($) {
    my $self	= shift || return undef;
    my $mysqlhost	= shift || $self;  # MySQL database host to write to.
    my $master_status	= $self->get_master_status();
    my $master_table	= $self->cache_master_table();
    my $MySQL_Host	= $self->host();
    my $sqltype		= "UPDATE";
       $sqltype		= "INSERT" unless $self->get_cache_master_status();
    my $dbh	= $mysqlhost->dbhandle() || return $self->fatalerror("Could not connect to mysql; ".$mysqlhost->dsn()."\n");
    return _set_cache_status($dbh,$master_status,$master_table,$MySQL_Host,$sqltype);
}

sub set_cache_slave_status ($) {
    my $self	= shift || return undef;
    my $mysqlhost	= shift || $self;  # MySQL database host to write to.
    my $slave_status	= $self->get_slave_status() || undef;
    my $slave_table	= $self->cache_slave_table();
    my $MySQL_Host	= $self->host();
    my $sqltype		= "UPDATE";
       $sqltype		= "INSERT" unless $self->get_cache_slave_status();
    my $dbh	= $mysqlhost->dbhandle() || return $self->fatalerror("Could not connect to mysql; ".$mysqlhost->dsn()."\n");
    return _set_cache_status($dbh,$slave_status,$slave_table,$MySQL_Host,$sqltype);
}

sub _set_cache_status ($$$$$) {
    my $dbh	= shift || return undef;
    my $status	= shift || return undef;
    my $table	= shift || return undef;
    my $host	= shift || return undef;
    my $sqltype	= shift || "UPDATE";

    my (@fields,@placeholders,@values);
    my ($sql,$sth,$ret);
    if ($sqltype eq "INSERT") {
        push(@fields,'MySQL_Host');
        push(@placeholders,"?");
        push(@values,$host);
        foreach my $key (keys %{$status}) {
            push(@fields,$key);
            push(@placeholders,"?");
            push(@values,$status->{$key});
        }
        $sql	= ("INSERT INTO ".$table." (".join("\,",@fields).") VALUES (".join("\,",@placeholders).")");
    } else {
        push(@fields,"MySQL_Host=?");
        push(@values,$host);
        foreach my $key (keys %{$status}) {
            push(@fields,($key."=?"));
            push(@values,$status->{$key});
        }
        $sql	= ("UPDATE ".$table." SET ".join("\,",@fields)." WHERE MySQL_Host='".$host."'");
    }

	# DEBUG # print "\n----------\n--$sqltype--\n",$sql,"\n--$sqltype--\n----------\n";
    $sth	= $dbh->prepare($sql);
    $ret	= $sth->execute(@values);
    $sth->finish();
    # $dbh->disconnect();

    return $ret;
}

sub _get_cache_status ($$$) {
    my $dbh	= shift || return undef;
    my $table	= shift || return undef;
    my $host	= shift || return undef;

    my $sql	= ("SELECT * FROM ".$table." WHERE MySQL_Host='".$host."'");

    my $sth	= $dbh->prepare($sql);
    $sth->execute();
    my $status	= $sth->fetchrow_hashref() || undef;
    $sth->finish();
    # $dbh->disconnect();

    return $status;
}

sub poll_connect () {
    my $self	= shift;

    my @server_failures;
    my $dbh	= $self->dbhandle() || undef;

    if (! defined $dbh) {
        push(@server_failures,("Could not connect to mysql host ".$self->hostport.": " . DBI::errstr()));
        return @server_failures;
    }

    unless ( defined $dbh )
        {
        push( @server_failures, "Connect Error: Could not connect to mysql server ".$self->dsn().": " . DBI::errstr() );
        }

    my @tables = $dbh->tables();
    if( $#tables < 0 )
        {
        push( @server_failures, ("Query Error: No tables found for database ".$self->database()." on server ".$self->hostport() ) );
        }

    # $dbh->disconnect();
    return @server_failures;
}

sub poll_request () {
    my $self	= shift;

    my @server_failures;
    my $dbh	= $self->dbhandle() || undef;

    if (! defined $dbh) {
        push(@server_failures,("Could not connect to mysql host to get slave status".$self->hostport.": " . DBI::errstr()));
        return @server_failures;
    }

    my $slave_stat = $self->get_slave_status() || undef;

    if (!defined $slave_stat) {
        push(@server_failures,("Could not get slave status for mysql host ".$self->hostport."."));
        return @server_failures;
    }

    if ($slave_stat->{'Slave_SQL_Running'} !~ /YES/i)
    {
        push(@server_failures,("Slave Error: Slave SQL is not running, Slave_SQL_Running=".$slave_stat->{'Slave_SQL_Running'}."."));
    }
    elsif ($slave_stat->{'Slave_IO_Running'} !~ /YES/i)
    {
        push(@server_failures,("Slave Error: Slave IO is not running, Slave_IO_Running=".$slave_stat->{'Slave_IO_Running'}."."));
    }

    if ($slave_stat->{'Read_Master_Log_Pos'} != $slave_stat->{'Exec_Master_Log_Pos'}) {
        my $pos_out = ($slave_stat->{'Read_Master_Log_Pos'} - $slave_stat->{'Exec_Master_Log_Pos'});
        push(@server_failures,("Slave Error: Replication out of sync by ".$pos_out." positions, Read=".$slave_stat->{'Read_Master_Log_Pos'}.", Execute=".$slave_stat->{'Exec_Master_Log_Pos'}."."));
         # ewh.. this should be defined via a variable, and not specifically set to 0 - REG 20051004
        if ($slave_stat->{'Seconds_Behind_Master'} > 0) {
            push(@server_failures,("Slave Error: Seconds Behind Master: ".$slave_stat->{'Seconds_Behind_Master'}))
        }
    }

    if (   (defined $slave_stat->{'Last_Error'})
        && ($slave_stat->{'Last_Error'} =~ /\w/))
    {
        push(@server_failures,("Last_Error: ".$slave_stat->{'Last_Error'}));
    }

    return @server_failures;
}


1;
__END__
