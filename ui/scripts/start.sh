#!/bin/bash

if [ "$MAP_ENV" = "" ]; then
    MAP_ENV=production
fi

set -eou pipefail

cd "`dirname "$0"`/../"

listen_address="0.0.0.0"
listen_port=3456
logging=0

if [ "$MAP_ENV" = "" ]; then
    MAP_ENV=production
fi

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
        --logging)
            logging="$value"
            ;;
        --help|-h)
            echo "Usage: $0 [--listen-address $listen_address] [--listen-port $listen_port] [--logging 0/1]"
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

lsof -i ":${listen_port}" -sTCP:LISTEN && fail "Port $listen_port already in use"

function run() {
    scripts/jruby.sh distlibs/gems/bin/fishwife app/config.ru --host $listen_address --port $listen_port -E "$MAP_ENV" -O request_body_max=134217728
}

if [ "$logging" = "0" ]; then
    run
else
    mkdir -p "$PWD/logs"
    run 2>&1 | scripts/log-rotater.pl "$PWD/logs/%a.log" "$PWD/logs/map.log"
fi
