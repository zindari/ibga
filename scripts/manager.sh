#!/bin/bash

# Use TZ env var for timezone instead of sudo ln -fs
if [ ! -z "$IB_TIMEZONE" ]; then
    export TZ="${IB_TIMEZONE// /_}"
fi

source $(dirname "$BASH_SOURCE")/_env.sh
source $(dirname "$BASH_SOURCE")/_utils.sh
source $(dirname "$BASH_SOURCE")/_run_xv.sh
source $(dirname "$BASH_SOURCE")/_run_socat.sh
source $(dirname "$BASH_SOURCE")/_install_ibg.sh
source $(dirname "$BASH_SOURCE")/_run_ibg.sh

# Directories are owned by ibg at build time, no chown needed

MSG="------------------------------------------------
 Manager Startup / $(date)
------------------------------------------------
"
_info "$MSG"

_run_xvfb
_run_vnc
_run_novnc
_run_socat

SC_PATH="$(dirname $(readlink -f $0))"
INSTALLED=''

# Try installation 10 times
trial=0
while [ $trial -lt 10 ] ; do
    trial=$[$trial+1]
    _install_ibg "$trial"
    install_status=$?
    if [ $install_status -eq 0 ]; then
        INSTALLED=true
        break
    fi
    _info "• manager will retry installation in 60s ($[$trial+1] of 10) ...\n"
    for (( i=10; i>0; i--)); do sleep 1 & wait; done
done

if [ "$INSTALLED" = true ] ; then
    _run_ibg
else
    _info "• manager is shutting down due to installation failure.\n"
fi
