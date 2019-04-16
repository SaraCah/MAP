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
(tsc --build --watch app/ts/tsconfig.json --preserveWatchOutput) &

export MAP_ENV=development
scripts/start.sh
