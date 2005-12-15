package mysqlpool::host::checkpoint;

##
# mysqlpool::host::http         ver1.00.000/REG     20051214
# Object to instantiate a checkpoint host using a checkpoint host string.
#   checkpoint host string:  type:proto:server:port
##

use strict;
use mysqlpool::host::mysql;
use mysqlpool::host::simple;
use mysqlpool::host::http;

BEGIN {
    use vars    qw($NAME $AUTHOR $VERSION $LASTMOD $DEBUG $DEBUGMSG $ERRORMSG);
    $NAME       = 'mysqlpool::host::checkpoint';
    $AUTHOR     = 'rglaue@cait.org';
    $VERSION    = '1.00.000';
    $LASTMOD    = 20051214;
    $DEBUG      = 0;
}

sub new () {
    my $pkg         = shift;
    my $class       = ref($pkg) || $pkg;

    my $name        = shift;
    unless (split(':',$name) == 4) {
        return undef;
    } else {
        my ($type,$proto,$hostname,$portnumber) = split(':',$name);
        my $cphost;
        if ($proto =~ /http/i) {
            $cphost = mysqlpool::host::http->new    ( host => $hostname, port => $portnumber);
            $cphost->checkpoint_id($name);
        } elsif ($proto =~ /simple/i) {
            $cphost = mysqlpool::host::simple->new  ( host => $hostname, port => $portnumber);
            $cphost->checkpoint_id($name);
        } elsif ($proto =~ /mysql/i) {
            $cphost = mysqlpool::host::mysql->new   ( host => $hostname, port => $portnumber);
            $cphost->checkpoint_id($name);
        }
        return $cphost;
    }
}

1;

__END__
