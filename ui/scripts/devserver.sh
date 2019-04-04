#!/bin/bash

function fail() {
    echo "ERROR: $*"
    exit 1
}

which tsc >/dev/null || fail "Need Typescript installed"

set -eou pipefail

cd "`dirname "$0"`/../"

trap "exit" INT TERM
trap "kill 0" EXIT
(tsc --watch app/ts/main.ts --outDir app/buildjs | strings) &

scripts/start.sh
