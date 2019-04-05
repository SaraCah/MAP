#!/bin/bash

function fail() {
    echo "ERROR: $*"
    exit 1
}

set -eou pipefail

cd "`dirname "$0"`/../"

trap "exit" INT TERM
trap "kill 0" EXIT

scripts/start.sh
