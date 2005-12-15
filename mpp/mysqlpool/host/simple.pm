package mysqlpool::host::simple;

##
# mysqlpool::host::http         ver1.00.000/REG     20051214
# Object to manage interfacing a simple host.
##

use strict;

use mysqlpool::host::generic;

BEGIN {
    use vars    qw(@ISA);
    @ISA        = qw(mysqlpool::host::generic);

    use vars    qw($NAME $AUTHOR $VERSION $LASTMOD $DEBUG $DEBUGMSG $ERRORMSG);
    $NAME       = 'mysqlpool::host::simple';
    $AUTHOR     = 'rglaue@cait.org';
    $VERSION    = '1.00.000';
    $LASTMOD    = 20051214;
    $DEBUG      = 0;
}

# Inherited functions: host, port, postport, ping, connect, disconnect, isUp,
#   checkpoints, has_checkpoints, poll_checkpoints,
#   fatalerror, errormsg, debugmsg
#   Requiring overwritting: connect, disconnect
#   Actually overwritten: connect, disconnect

sub DEFAULT_PORT { "7" }

sub new {
    my $pkg     = shift;
    my $class   = ref($pkg) || $pkg;
    my %args    = @_;
    $args{'port'} = DEFAULT_PORT if $args{'port'} =~ /default/i;

    my $self    = bless mysqlpool::host::generic->new(%args), $class;

    return $self;
}

# connect
sub connect (@) {
    my $self    = shift;
    return $self->ping();
}

# disconnect
sub disconnect (@) {
    return 1;
}

sub poll_connect () {
    my $self        = shift;
    my (@server_failures);

    my $ping        = $self->ping();
    push ( @server_failures, ("Could not reach host ".$self->hostport.".") ) unless $ping;

    return @server_failures;
}

sub poll_request () {
    my $self        = shift;
    my (@server_failures);

    my $ping        = $self->ping();
    push ( @server_failures, ("Could not reach host ".$self->hostport.".") ) unless $ping;

    return @server_failures;
}


1;

__END__
