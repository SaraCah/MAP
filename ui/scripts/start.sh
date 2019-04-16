#!/bin/bash

set -eou pipefail

cd "`dirname "$0"`/../"

listen_address="0.0.0.0"
listen_port=3456

while [ "$#" -gt 0 ]; do
    param="$1"; shift
    value="${1:-}"

    case "$param" in
        --listen-address)
            listen_address="$value"
            ;;
        --listen-port)
            listen_port="$value"
            ;;
        --help|-h)
            echo "Usage: $0 [--listen-address $listen_address] [--listen-port $listen_port]"
            exit 0
            ;;
        *)
            echo "Unknown parameter: $param"
            exit 1
            ;;
    esac

    if [ "$value" = "" ]; then
        echo "Value for $param can't be empty"
        exit 1
    fi

    shift
done

function fail() {
    echo "ERROR: $*"
    exit 1
}

lsof -i ":${listen_port}" && fail "Port $listen_port already in use"

scripts/jruby.sh distlibs/gems/bin/fishwife app/config.ru --host $listen_address --port $listen_port
