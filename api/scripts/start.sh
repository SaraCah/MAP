#!/bin/bash

if [ "$MAP_ENV" = "" ]; then
    MAP_ENV=production
fi

set -eou pipefail

cd "`dirname "$0"`/../"

listen_address="0.0.0.0"
listen_port=5678
solr_port=8984

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
        --solr-port)
            solr_port="$value"
            ;;
        --help|-h)
            echo "Usage: $0 [--listen-address $listen_address] [--listen-port $listen_port] [--solr-port $solr_port]"
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

function stop_solr() {
    solr_dist/bin/solr stop -p $solr_port
    kill 0
}

function fail() {
    echo "ERROR: $*"
    exit 1
}

lsof -i ":${listen_port}" && fail "Port $listen_port already in use"
lsof -i ":${solr_port}" && fail "Port $solr_port already in use"

trap "stop_solr" INT TERM EXIT

mkdir -p data/solr
solr_dist/bin/solr start -p $solr_port -s solr -a "-Dsolr.data.home=$PWD/data/solr"
scripts/jruby.sh distlibs/gems/bin/fishwife app/config.ru --host $listen_address --port $listen_port -E "$MAP_ENV"
