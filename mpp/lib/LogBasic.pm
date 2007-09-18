package LogBasic;


##
# ver	0.00.003	20040630
# Added in code for 'auto reconnect' of the mysql connection
# SQL connection could be lost if download process takes too long.
##
# ver	0.00.002	20040628
# Changed format of message that is logged to the log file.
##
# ver	0.00.001	20040621
# LogBasic module adopted from attorney general project log module.
# This module should be used as the log module for that project.
# The log module will currently allow basic info/warn/error logging
# to file and/or database. Pass in a config object hash, or
# Config_info configuration file to configure the settings.
# DBI::mysql required for SQL Logging
# IO::File required for disk based file logging
##


use strict;
use Config_info;
use Net::SMTP;


BEGIN {
    use vars	qw($NAME $VERSION $MODIFIED $AUTHOR $COPYRIGHT);
    $NAME	= 'LogBasic';
    $VERSION	= '0.00.003';
    $MODIFIED	= 20040630;
    $AUTHOR	= 'rglaue@cait.org';
    $COPYRIGHT	= 'Copyright (c) 2004, Center for the Application of Information Technologies';

    use vars	qw($DEBUG);
    $DEBUG	= 0;
}


sub new {
    my $pkg     = shift;
    my $class   = ref($pkg) || $pkg;
    my $pid     = shift || undef;
    my $cfgobj	= shift || undef;
    my $rhash;

    $rhash = bless {}, $class;
    $rhash->{'_conn'}      = undef;
    $rhash->{'_log_file'}  = undef;
    $rhash->{'_lf_handle'} = undef;
    $rhash->process_id($pid) if defined $pid;
    $rhash->load_config($cfgobj) if defined $cfgobj;

    return $rhash;
}

sub load_config {
    my $self	= shift;
    my $cfgobj	= shift;
    if (ref $cfgobj eq "HASH") {
        $self->{'_cfg'} = new Config_info("temp.cfg");
        foreach my $key1 (keys %{$cfgobj}) {
            foreach my $key2 (keys %{$cfgobj->{$key1}}) {
                $self->{'_cfg'}->create($key1,$key2,"=",$cfgobj->{$key1}->{$key2});
            }
        }
    } elsif ($cfgobj =~ /\w/) {
        $self->{'_cfg'} = new Config_info($cfgobj);
        $self->error_message("");
        $self->{'_cfg'}->load() || ($self->error_message("Cannot load Config_info file: $cfgobj") && return 0);
    } else {
        $self->error_message("Config object ($cfgobj) is not recognized. It must be HASH of values or Config_info file.");
        return 0;
    }
    return 1;
}

sub process_id ($) {
    my $self    = shift;
    my $pid     = shift || undef;
    if (! defined $pid) {
        return $self->{'_pid'} || undef;
    }
    $self->{'_pid'} = $pid;
}

sub log_file ($) {
    my $self    = shift;
    my $logfile = shift || undef;
    if (! defined $logfile) {
        return $self->{'_log_file'} || undef;
    }
    $self->{'_log_file'} = $logfile;
}

sub connect {
    my $self	= shift;

    $self->_mysql_connect();

    if ($self->{'_cfg'}->handle_exists("DISK")) {
        require IO::File;
        $self->log_file($self->{'_cfg'}->get('DISK','LOGFILE'));
        my $logfile	= $self->log_file();
        # close existing && open new log file;
        if ((ref $self->{'_lf_handle'} eq "IO::File") && ($self->{'_lf_handle'}->opened())) {
            $self->{'_lf_handle'}->close();
        }
        $self->{'_lf_handle'} = new IO::File(">>$logfile")
            || ($self->error_message("Could not open file handle for $logfile: $!") && return undef);
        if ($self->{'_lf_handle'}->error()) {
            $self->error_message("Cannot Initilaize IO::File[$logfile]: $!");
            return undef;
        }
        $self->{'_lf_handle'}->autoflush(1);
    }

    if ((! defined $self->{'_conn'}) && (! defined $self->{'_lf_handle'})) {
        $self->error_message("No defined logging sources!");
        return 0;
    }
    return 1;
}

sub _mysql_connect {
    my $self	= shift;
    if ($self->{'_cfg'}->handle_exists("MYSQL")) {
        require DBI;
        my $database	= $self->{'_cfg'}->get('MYSQL','DATABASE');
        my $hostname	= $self->{'_cfg'}->get('MYSQL','HOSTNAME');
        my $port	= $self->{'_cfg'}->get('MYSQL','PORT');
        my $username	= $self->{'_cfg'}->get('MYSQL','USERNAME');
        my $password	= $self->{'_cfg'}->get('MYSQL','PASSWORD');
        my $data_source	= "DBI:mysql:database=$database;host=$hostname;port=$port";
        return $self->{'_conn'} = DBI->connect(
            $data_source,
            $username,
            $password,
            {
                RaiseError => 0,
                AutoCommit => 0
            }
        ) || ($self->error_message("Cannot connect to datasource: $data_source; $DBI::errstr") && return 0);
    }
}

sub _mysql_isconnected () {
    my $self    = shift;
    return $self->{'_conn'}->ping();
}

# Crude way of implementing autoconnect
# Not true qutoconnect since this must be executed
sub _mysql_autoconnect () {
    my $self    = shift;
    if ($self->_mysql_isconnected()) {
        return $self->_mysql_isconnected();
    } else {
        return $self->_mysql_connect();
    }
}

sub log_info ($$) {
    my $self    = shift;
    my $verbose = pop if @_ == 3;
    my $process = shift;
    my $message = shift;
    $self->_log_dispatch('info',$process,$message,$verbose);
    if (defined $self->{'_lf_handle'}) {
        return undef if !defined $self->_log_file('info',$process,$message,$verbose);
        # return undef if !defined $self->_log_file('info',$process,$message);
    }
    if (defined $self->{'_conn'}) {
        return undef if !defined $self->_log_sql('info',$process,$message);
    }
    return 1;
}

sub log_warn ($$) {
    my $self    = shift;
    my $verbose = pop if @_ == 3;
    my $process = shift;
    my $message = shift;
    $self->_log_dispatch('warn',$process,$message,$verbose);
    if (defined $self->{'_lf_handle'}) {
        return undef if !defined $self->_log_file('warn',$process,$message,$verbose);
        # return undef if !defined $self->_log_file('warn',$process,$message);
    }
    if (defined $self->{'_conn'}) {
        return undef if !defined $self->_log_sql('warn',$process,$message);
    }
    return 1;
}

sub log_error ($$) {
    my $self    = shift;
    my $verbose = pop if @_ == 3;
    my $process = shift;
    my $message = shift;
    $self->_log_dispatch('error',$process,$message,$verbose);
    if (defined $self->{'_lf_handle'}) {
        return undef if !defined $self->_log_file('error',$process,$message,$verbose);
        # return undef if !defined $self->_log_file('error',$process,$message);
    }
    if (defined $self->{'_conn'}) {
        return undef if !defined $self->_log_sql('error',$process,$message);
    }
    return 1;
}

# Send a log we have been collecting thus far to someone via e-mail
# We need better error checking/communication here.
# This is crappy! Net::SMTP is giving an error of "Not a GLOB Reference at" errors all over the place
#   So for the time being... /bin/mail ! Argh!!
sub log_mailnotify_send () {
    my $self	= shift;
    my %arg	= @_;

    return undef unless $self->{'_cfg'}->handle_exists("MAILNOTIFY");

    my $maillog	= $self->_log_collect_get() || undef;
    return undef unless defined $maillog;

    my $SMTPSERVER	= $self->{'_cfg'}->get('MAILNOTIFY','SMTPSERVER');	# Scallar
    my $MailSender	= $self->{'_cfg'}->get('MAILNOTIFY','MAILSENDER');      # Scallar
    my $MailRecipients	= $self->{'_cfg'}->get('MAILNOTIFY','MAILRECIPIENTS');	# array reference

    my $message		= ("To: ".(join(',',@{$MailRecipients})."\n"));
    if (defined $arg{Subject}) {
        $message	.= ("Subject: ".$arg{Subject}."\n\n");
    } else {
        $message	.= ("Subject: Log Output\n\n");
    }
    $message	.= $arg{Message};


    my $smtp	= Net::SMTP->new($SMTPSERVER) || warn "not connected to smtp\n";
    $smtp->mail($MailSender);
    $smtp->to(@{$MailRecipients});

    $message .= ("\n" . "-"x60 . "\n" . $maillog . "\n" . "-"x60 . "\n");

    $smtp->data();
    $smtp->datasend($message);
    $smtp->dataend();
    $smtp->quit();

    warn "I supposedly e-mailed this:\n$message\n" if $DEBUG;
    return 1;
}

sub _log_dispatch (@) {
    my $self	= shift;

    # Get log info
    my ($timestamp, $pid, $level, $process, $message, $verbose, $verbose_formatted, $mesg_formatted);
    if ($_[0] =~ /^\d*$/)
        { $timestamp = shift } else { $timestamp = timestamp_now(2) }
    if ($_[0] =~ /^\d*$/) {
                 $pid       = shift || $self->process_id();
               } else {
                 $pid       = $self->process_id() || ($self->error_message("Process ID not defined") && return undef);
               }
    $level      = shift || $self->error_message("File Log level not defined") && return undef;
    $process    = shift || $self->error_message("File Log process not defined") && return undef;
    $message    = shift || $self->error_message("File Log message not defined") && return undef;
    $verbose	= shift || undef;

    # Format log info
    if (defined $verbose) {
        chomp $verbose;
        $verbose_formatted = $verbose;
        $verbose_formatted =~ s/^/\t/;
        $verbose_formatted =~ s/\n/\n\t/g;
        $verbose_formatted .= "\n";
    }
    $mesg_formatted = ("[".$timestamp."] ".$level." (".$pid."): ".$process." - ".$message."\n".$verbose_formatted);

    # Send info to log file
# This needs to be integrated - everything calls dispatch, and dispatch calls the physical loggers
# Physical loggers are: SQL, FILE, and EMAIL
#    if (defined $self->{'_lf_handle'}) {
#        return undef if !defined $self->_log_file('error',$process,$message,$verbose);
#        # return undef if !defined $self->_log_file('error',$process,$message);
#    }
#    if (defined $self->{'_conn'}) {
#        return undef if !defined $self->_log_sql('error',$process,$message);
#    }
    if ($self->{'_cfg'}->handle_exists("MAILNOTIFY")) {
        $self->_log_collect_set($mesg_formatted);
    }
}

sub _log_file ($$$$$) {
    my $self    = shift;
    unless ((ref $self->{'_lf_handle'} eq "IO::File") && ($self->{'_lf_handle'}->opened())) {
        $self->error_message("File Handle not defined or not opened. Did you connect before using?");
        return undef;
    }
    my $FH      = $self->{'_lf_handle'};
    my ($timestamp, $pid, $level, $process, $message, $verbose);
    if ($_[0] =~ /^\d*$/)
        { $timestamp = shift } else { $timestamp = timestamp_now(2) }
    if ($_[0] =~ /^\d*$/) {
                 $pid       = shift || $self->process_id();
               } else {
                 $pid       = $self->process_id() || ($self->error_message("Process ID not defined") && return undef);
               }
    $level      = shift || $self->error_message("File Log level not defined") && return undef;
    $process    = shift || $self->error_message("File Log process not defined") && return undef;
    $message    = shift || $self->error_message("File Log message not defined") && return undef;
    $verbose	= shift || undef;
    if (defined $verbose) {
        chomp $verbose;
        $verbose	=~ s/^/\t/;
        $verbose	=~ s/\n/\n\t/g;
        $verbose	= ($verbose."\n");
    }

    print $FH ("[".$timestamp."] ".$level." (".$pid."): ".$process." - ".$message."\n".$verbose);
}

sub _log_sql ($$$$$) {
    my $self    = shift;
    unless (ref $self->{'_conn'} eq "DBI::db") {
        $self->error_message("DBI::db/MySQL connection not defined. Did you connect before using?");
        return undef;
    }
    my ($timestamp, $pid, $level, $process, $message);
    if ($_[0] =~ /^\d*$/)
        { $timestamp = shift } else { $timestamp = timestamp_now(2) }
    if ($_[0] =~ /^\d*$/) {
                 $pid       = shift || $self->process_id();
               } else {
                 $pid       = $self->process_id() || ($self->error_message("Process ID not defined") && return undef);
               }
    $level      = shift || $self->error_message("SQL Log level not defined") && return undef;
    $process    = shift || $self->error_message("SQL Log process not defined") && return undef;
    $message    = shift || $self->error_message("SQL Log message not defined") && return undef;
    my $sql     = $self->{'_cfg'}->get('SQL','DATALOG');

       $self->_mysql_autoconnect() || return undef;
    my $dbh	= $self->{'_conn'};
    my $sth	= $dbh->prepare( $sql )
        || ($self->error_message("Cannot prepare statement: $sql; $DBI::errstr") && return 0);
    my $rch	= $sth->execute($timestamp,$pid,$level,$process,$message)
        || ($self->error_message("Cannot execute statement: $sql; $DBI::errstr") && return 0);
    return $dbh->commit;
}

sub _log_collect_set ($) {
    my $self	= shift;
    my $mesg	= shift || return undef;
    chomp $mesg;
    push(@{$self->{'_log_collect'}},$mesg);
}
sub _log_collect_get ($) {
    my $self	= shift;
    return undef unless exists $self->{'_log_collect'};
    return join("\n",@{$self->{'_log_collect'}});
}

sub disconnect {
    my $self	= shift;
    my $disconnect_error = undef;
    if ((ref $self->{'_lf_handle'} eq "IO::File")
        && ($self->{'_lf_handle'}->opened())) {
        $self->{'_lf_handle'}->close() || ($disconnect_error .= "Could not close log file handle.");
        chmod( $self->log_file() ,"777");
    }
    if (defined $self->{'_conn'}) {
        $self->{'_conn'}->disconnect() || ($disconnect_error .= "Could not close database connection handle.");
    }
    $self->error_message($disconnect_error) && return 0 if defined $disconnect_error;
    return 1;
}

sub timestamp_now ($) {
    my $type    = shift || 1;
    # get local time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
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
    if ($type == 2) {
        $timestamp = ($year."-".$month."-".$mday." ".$hour.":".$min.":".$sec);
    } else {
        $timestamp = ($year.$month.$mday.$hour.$min.$sec);
    }

    return $timestamp;
}
                                                                                                                        
sub error_message {
    my $self	= shift;
    my $mesg	= shift || undef;
    if (defined $mesg) {
        $self->{'_error_message'} = $mesg;
        return 1;
    } else {
        return $self->{'_error_message'};
    }
}

1;
__END__
