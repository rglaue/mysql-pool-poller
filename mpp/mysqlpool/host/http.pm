package mysqlpool::host::http;

##
# mysqlpool::host::http         ver1.00.000/REG     20060103
# Object to manage interfacing an HTTP host.
##

use strict;
use Net::HTTP;

use mysqlpool::host::generic;

BEGIN {
    use vars    qw(@ISA);
    @ISA        = qw(mysqlpool::host::generic);

    use vars    qw($NAME $AUTHOR $VERSION $LASTMOD $DEBUG $DEBUGMSG $ERRORMSG);
    $NAME       = 'mysqlpool::host::http';
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

sub DEFAULT_PORT { "80" }

sub new {
    my $pkg         = shift;
    my $class       = ref($pkg) || $pkg;
    my %args        = @_;
    $args{'port'}   = DEFAULT_PORT if $args{'port'} =~ /default/i;

    my $self    = bless mysqlpool::host::generic->new(%args), $class;

    return $self;
}

sub connect (@) {
    my $self        = shift;
    my %args        = @_;
    my $timeout     = $args{'timeout'} || 4;

    my $hostport    = $self->hostport() || return $self->fatalerror("Attributes hostname and/or portnumber are not set for this host.");
    my $code        = sub { Net::HTTP->new( Host => $hostport, Timeout => $timeout ) };
    my $sock        = 
        $self->eval_exe_timeout ( $code, ($timeout + 1) )
        || return $self->fatalerror( join(" ", $@) );

    return $sock;
}

# disconnect
# Not used
sub disconnect (@) {
    return 1;
}

# request_uri
# Set or retrieve the default request uri
# @param    uri     The default URI to use on GET requests (default is "/")
sub request_uri ($) {
    my $self        = shift;
    my $uri         = shift || undef;

    if (! defined $uri) {
        return $self->{'_request_uri'} || "/";
    }
    $self->{'_request_uri'} = $uri;
}

# http_get
# returns a set of response variables based on a HTTP GET request
# @param    uri         (optional) The URI to request from the HTTP server
# returns   ( code, message, { headers } )
# returns   undef       error; Error message in &errormsg()
sub http_get (@) {
    my $self        = shift;
    my %args        = @_;
    my $uri         = $args{'uri'} || $self->request_uri();

    my $sock        = $self->connect(@_) || return undef;
    $sock->write_request( GET => $uri, 'User-Agent' => "Mozilla/5.0" );
    my ($code, $mess, %h) = $sock->read_response_headers;

    return $code, $mess, %h;
}

# http_get_ok
# return true/false if GET is okay.
# @param    max_status  (optional) The maximum allowed HTTP status the HTTP request can result as and still be considered OK
# returns   1           success, HTTP request is <= max_status
# returns   0           failure, HTTP request is > max_status
# returns   undef       error; Error message in &errormsg()
sub http_get_ok (@) {
    my $self        = shift;
    my %args        = @_;

    my ($code, $mess, %h) = $self->http_get(@_) || return undef;
    if (defined $code) {
        if ((exists $args{'max_status'}) && (! defined $args{'max_status'})) {
            $self->errormsg("Parameter 'max_status' given, but not defined!");
            return undef;
        } elsif ((defined $args{'max_status'}) && ($code <= $args{'max_status'})) {
            return 1;
        } elsif ((defined $args{'max_status'}) && ($code > $args{'max_status'})) {
            return 0;
        } else {
            return 1;
        }
    } else {
        return 0;
    }
}

sub poll_connect () {
    my $self        = shift;
    my (@server_failures);

    my $sock        = $self->connect() || undef;
    if (! defined $sock) {
        push ( @server_failures, ("Could not connect to http host ".$self->hostport.": ".$self->errormsg) );
    } else {
        $sock->close();
    }

    return @server_failures;
}

sub poll_request () {
    my $self        = shift;
    my %args        = @_;
    my (@server_failures);

    my $sock        = $self->connect() || undef;
    if (! defined $sock) {
        push ( @server_failures, ("Could not connect to http host to perform HTTP GET request ".$self->hostport.": ".$self->errormsg) );
    }

    my $http_get_ok;
    if (exists $args{'uri'}) {
        $http_get_ok    = $self->http_get_ok( uri => $args{'uri'} );
    } else {
        $http_get_ok    = $self->http_get_ok( uri => $self->default_uri() );
    }
    if ($http_get_ok != 1) {
        if ($http_get_ok == 0) {
            push ( @server_failures, ("HTTP GET request from server ".$self->hostport." failed.") );
        } else {
            push ( @server_failures, ("HTTP GET request from server ".$self->hostport." failed: ".$self->errormsg) );
        }
    }

    $sock->disconnect();
    return @server_failures;
}


1;

__END__
