POLLHOME=/usr/local/mpp
perl -I$POLLHOME/lib $POLLHOME/mysql-poller.pl --poll-cached-pools >/dev/null 2>&1
