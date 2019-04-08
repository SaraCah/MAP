#!/bin/bash

SOLR_PORT=8984

function fail() {
    echo "ERROR: $*"
    exit 1
}

function shutdown() {
    solr_dist/bin/solr stop -p $SOLR_PORT

    exit
    kill 0
}


lsof -i ":$SOLR_PORT" && fail "Solr already running"

set -eou pipefail

cd "`dirname "$0"`/../"

trap "shutdown" INT TERM
trap "shutdown" EXIT

mkdir -p data/solr
solr_dist/bin/solr start -p $SOLR_PORT -s solr -a "-Dsolr.data.home=$PWD/data/solr"

scripts/start.sh
