#!/usr/bin/perl
#
##
# mpp-monitor.pl                20080527/REG
# Script to monitor MPP status, and send out e-mail alerts and reports.
##

use strict;
use Getopt::Long;
use MIME::Lite;

use lib '/usr/local/mpp/lib';
use mysqlpool::failover;

BEGIN {
    use vars            qw($NAME $AUTHOR $VERSION $LASTMOD);
    $NAME               = 'MPP Monitor for Status Alerting and Reporting';
    $AUTHOR             = 'rglaue@cait.org';
    $VERSION            = '1';
    $LASTMOD            = 20080527;

    use vars            qw($DEBUG $SMTP_SERVER $HOSTNAME $HOSTNAME_SHORT $DATESTAMP $TIMESTAMP $ERRORMSG);
    $DEBUG              = 0;
    $SMTP_SERVER        = 'smtp.example.com';
    $HOSTNAME           = `/bin/hostname`;
    $HOSTNAME_SHORT     = `/bin/hostname -s`;
    $DATESTAMP          = `/bin/date '+%G%m%d'`;
    $TIMESTAMP          = `/bin/date '+%G-%m-%d %H:%M:%S'`;
    chomp $HOSTNAME;
    chomp $HOSTNAME_SHORT;
    chomp $DATESTAMP;

    use vars            qw(%options $failover_cachefile $failover);
    $failover_cachefile = "/usr/local/mpp/cache/mpp-3dns";  # set a default
}

sub usage (@) {
    my $mesg    = shift || undef;
    my $help    =<<HELP_EOF;
    $NAME ver $VERSION / $AUTHOR

    # For Command-line Operation
        usage: $0 [options]

    OPTIONS:
    --cache-file=/path/to/cachefile
                        # The cache file the poller is manipulating the
                        # information for
    --email=recipient\@maildomain
                        # send alert or report this these e-mail addresses
    --console           # print alert or report to the console
    --report-all        # Send a full report to the email recipients
    --report-error      # Send a report of only pools with hosts in an error state to the email recipients
    --time-drift-alert=NNN
                        # Include an error alert if the last poll time exceeds NNN seconds; default is 300 seconds (5 minutes)

HELP_EOF
    $help   .= ("\n".$mesg."\n") if defined $mesg;
    return $help;
}


#
# Process the Options list
#
GetOptions( \%options,
        "cache-file=s", "pool=s",       "email=s@",
        "console",      "report-all",   "report-error",
        "time-drift-alert:i",
        "verbose",      "help"
        );
# Some defaults;
$options{'cache-file'} ||= $failover_cachefile;

if (! defined $options{'cache-file'}) {
    die usage("Cache file not provided!");
} elsif (! -e $options{'cache-file'}) {
    die usage("Cache file does not exist!");
} elsif (   ((!defined $options{'report-all'}) && (!defined $options{'report-error'}))
         && ((!defined $options{'console'})    && (!defined $options{'email'}))        ) {
    die usage("options email or console with either report-all or report-error is required.\n");
} elsif ((defined $options{'help'}) && ($options{'help'})) {
    die usage();
}

if ((exists $options{'time-drift-alert'}) && ($options{'time-drift-alert'}) < 1) {
    $options{'time-drift-alert'} = 300;
}

if (defined $options{'verbose'}) {
    $DEBUG = 1 if $DEBUG == 0;
}


#
# Initialize some globally used items
#
$failover   = mysqlpool::failover->new(cache => {file => $options{'cache-file'}} );


# store up and pront out application error messages
sub errormsg (@) {
    debugmsg(@_);
    if (@_ >= 1) {
        $ERRORMSG   = join("\n",@_);
    } else {
        
        $ERRORMSG || return undef;
    }
}

# fataly exit from code routines, concating error messages and passing to errormsg()
sub fatalerror (@) {
    my @msg = (errormsg(),@_);
    errormsg(@msg);
    return undef;
}

# Initialize a failover object
sub init_failover_config ($$) {
    my $failover    = shift;
    my $poolname    = shift || undef;

    if (defined $poolname) {
        my $config      = $failover->cached_pool_config(poolname => $poolname);
        $failover->config($config); # || (warn ("Failure configuring pool: ".$failover->errormsg().".") && return undef );
    } else {
            my $mesg =<<ERROR_EOF;
        ERROR: You need to choose a failover pool to use. Available from the cache:
ERROR_EOF
            my $mesg2 = undef;
            foreach my $pn ( @{$failover->get_cached_pool_names()} ) {
                next if ! defined $pn;
                $mesg2 .= ("\t\to ".$pn."\n");
            }
            if ((! defined $mesg2) || ($mesg2 eq "")) {
                $mesg2 .= ("\t\tNone Available\n");
            }
            $mesg .= $mesg2;
            die usage($mesg);
    }
    return $failover;
}

sub list_failover_pool (@) {
    my %args            = @_;
    my $failover        = $args{'failover'};
    my $show_header     = $args{'show_header'};
    $show_header        = 1 unless defined $show_header;
    my $show_poolname   = $args{'show_poolname'} || 0;
    my $show_servers    = $args{'show_servers'};
    $show_servers       = 1 unless defined $show_servers;
    my $space_tab       = $args{'space_tab'} || 0;
    my $space_indent    = $args{'space_indent'};
    $space_indent       = 2 unless defined $space_indent;

    my $RET;

    my %column      = (
        indent_space    => $space_indent,
        col_number      => 7,
        space           => [
            qw(1 30 3 20 7 14 19)
            ],
        title           => [
            "T",
            "Server Name",
            "req",
            "Time of Last Request",
            "Status",
            "State",
            "Last Status Message",
            ]
        );

    if ($show_header == 1) {
        my $colnum      = 0;
        $RET .= " "x$space_tab;
        foreach my $space (@{$column{'space'}}) {
            last if $colnum == $column{'col_number'};
            $RET .= $column{'title'}->[$colnum];
            my $indent      = ($column{'space'}->[$colnum] - length($column{'title'}->[$colnum]));
            $RET .= " "x$indent;
            $RET .= " "x$column{'indent_space'};
            $colnum++;
        }
        $RET .= "\n";
        $RET .= "-"x$space_tab;
        foreach my $space (@{$column{'space'}}) {
            $RET .= "-"x$space;
            $RET .= " "x$column{'indent_space'};
        }
        $RET .= "\n";
    }
    if ($show_poolname == 1) {
        $RET .= ( " "x$space_tab                      .
                "*"                                 .
                " "x$column{'indent_space'}         .
                "[ ".$failover->pool_name()." ]"    .
                " status=".$failover->cached_pool_status()
                );
        $RET .= "\n";
    }
    if ($show_servers == 1) {
        foreach my $server ( sort $failover->pooled_servers() ) {
            my $failover_type;
            my $request_num     = $failover->number_of_requests(server => $server);
            my $request_time    = $failover->timestamp( time => $failover->last_request_time(server => $server), format => "human" );
            my $failover_status = $failover->failover_status(server => $server);
            my $failover_state  = $failover->failover_state(server => $server);
            my $status_message  = $failover->last_status_message(server => $server);
            unless ((defined $status_message) && ($status_message ne "") && ($status_message ne "\n")) {
                $status_message = undef;
            }
            if ($failover->host_type(server => $server, type => "PRIMARY")) {
                $failover_type  = "P";
            } elsif ($failover->host_type(server => $server, type => "SECONDARY")) {
                $failover_type  = "S";
            } else {
                $failover_type  = "U";
            }
            $RET .= ( " "x$space_tab .
                    $failover_type      ." "x($column{'space'}->[0] - length($failover_type))   ." "x$column{'indent_space'} .
                    $server             ." "x($column{'space'}->[1] - length($server))          ." "x$column{'indent_space'} .
                    $request_num        ." "x($column{'space'}->[2] - length($request_num))     ." "x$column{'indent_space'} .
                    $request_time       ." "x($column{'space'}->[3] - length($request_time))    ." "x$column{'indent_space'} .
                    $failover_status    ." "x($column{'space'}->[4] - length($failover_status)) ." "x$column{'indent_space'} .
                    $failover_state     ." "x($column{'space'}->[5] - length($failover_state))  ." "x$column{'indent_space'} .
                    $status_message     );
            $RET .= "\n";
            # list_failover_server_checkpoints(failover => $failover, server => $server);
        }
    }
    return $RET;
}


# generate a report for hosts/pools
# @param  report_type       'all' or 'error'
# @param  time_drift_alert
sub report_error (@) {
    my %args            = @_;
    my $report_type     = $args{'report_type'} || 'all';  # 'all' or 'error'
    my $time_drift_alert;
    if (exists $args{'time_drift_alert'}) {
        $time_drift_alert = $args{'time_drift_alert'} || 0;
    }

    my $report;
    my $header;
    my $cached_pools_errors = 0;
    my $time_drift_errors = 0;
    $report .= list_failover_pool      (
                            failover        => undef,
                            show_header     => 1,
                            show_poolname   => 0,
                            show_servers    => 0,
                            space_tab       => 0,
                            space_indent    => 2
                            );
    foreach my $pn ( @{$failover->get_cached_pool_names()} ) {
        $failover = init_failover_config($failover,$pn)
            || die ("Could not initialize failover pool with pool named (".$pn.").");
        my $this_pool_errors = 0;

        foreach my $server ( sort $failover->pooled_servers() ) {
            my $request_num     = $failover->number_of_requests(server => $server);
            my $failover_state  = $failover->failover_state(server => $server);
            my $request_time    = $failover->last_request_time(server => $server);
            my $this_time       = time();
            if (   ($request_num >= 2)
                || ($failover_state =~ /^FAIL.*/)
               ) {
                $this_pool_errors++;
                $cached_pools_errors++;
            }
            if ( (defined $time_drift_alert) && ($request_time < ($this_time - $time_drift_alert)) ) {
                $this_pool_errors++;
                $time_drift_errors++;
                if ( (defined $time_drift_alert) && ($request_time < ($this_time - $time_drift_alert)) ) {
                    $header = ("  ALERT: Last poll cycle is older than ".$time_drift_alert." seconds.\n");
                }
            }
        }
        if (($this_pool_errors == 0) && ($report_type eq 'error')) {
            next;
        }

        $report .= list_failover_pool  (
                            failover        => $failover,
                            show_header     => 0,
                            show_poolname   => 1,
                            show_servers    => 1,
                            space_tab       => 0,
                            space_indent    => 2
                            );
    }

    if ($time_drift_errors >= 1) {
        $header .= ("  ALERT: Total Hosts not polled up to date: ".$time_drift_errors." (need to fix/restart polling mechanism)\n");
    }
    if ($cached_pools_errors >= 1) {
        $header .= ("  ALERT: Total Current Hosts with Errors: ".$cached_pools_errors." (needs fixing and/or recovery)\n");
    }
    if (defined $header) {
        chomp $header;
        $report = ("-"x60 . "\n" . $header . "\n" . "-"x60 . "\n\n" . $report);
    }

    my $title;
    $title .= ("      Hostname: ".$HOSTNAME."\n");
    $title .= ("    Cache File: ".$options{'cache-file'}."\n");
    $title .= ("     Date/Time: ".$TIMESTAMP."\n");
    $report = ( $title . $report );

    if (($cached_pools_errors == 0) && ($time_drift_errors == 0) && ($report_type eq 'error')) {
        return undef;
    } else {
        return $report;
    }
}

# send_email
# send a electronic mail message
#
# @param  from
# @param  to
# @param  subject
# @param  body
sub send_email (@) {
    my %args    = @_;

    MIME::Lite->send('smtp', $SMTP_SERVER, Timeout=>60);

    my $msg = new MIME::Lite(
        From    => $args{'from'},
        To      => $args{'to'},
        Subject => $args{'subject'},
        Type    => "multipart/mixed",
    );
    if (exists $args{'body'}) {
        $msg->attach(
            Type    => 'TEXT',
            Data    => $args{'body'}
        );
    }
    $msg->send('smtp', $SMTP_SERVER);
}


# Get a report and send it to console or e-mail
my $report;

if ($options{'report-error'}) {
    if (exists $options{'time-drift-alert'}) {
        $report = report_error( report_type => "error", time_drift_alert => $options{'time-drift-alert'});
    } else {
        $report = report_error( report_type => "error");
    }
} elsif ($options{'report-all'}) {
    if (exists $options{'time-drift-alert'}) {
        $report = report_error( report_type => "all", time_drift_alert => $options{'time-drift-alert'} );
    } else {
        $report = report_error( report_type => "all");
    }
}

if ($options{'console'}) {
    if (defined $report) {
        print $report,"\n";
    }
    exit 0;
} elsif ($options{'email'}) {
    if (defined $report) {
        my $subject;
        if ($options{'report-error'}) {
            $subject = ("MPP Errors - ".$HOSTNAME_SHORT." ".$DATESTAMP);
        } elsif ($options{'report-all'}) {
            $subject = ("MPP Report - ".$HOSTNAME_SHORT." ".$DATESTAMP);
        }
        foreach my $recipient (@{$options{'email'}}) {
            send_email(
                from    => ('mysql@'.$HOSTNAME),
                to      => $recipient,
                subject => $subject,
                body    => $report
            );
        }
    }
    exit 0;
}

exit 1;

__END__
