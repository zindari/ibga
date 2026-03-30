source $(dirname "$BASH_SOURCE")/_env.sh
source $(dirname "$BASH_SOURCE")/_utils.sh

function _run_socat {
    CMD=/usr/bin/socat
    ARGS="TCP-LISTEN:$IBG_PORT,fork,reuseaddr TCP:localhost:$IBG_PORT_INTERNAL,forever,shut-down"
    _info "• starting socat ($CMD $ARGS) ...\n"
    $CMD $ARGS &
    SOCAT_PID=$!
    _info "  pid: $SOCAT_PID\n"
}
