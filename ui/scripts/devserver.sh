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

rm -f app/buildjs/*
(tsc --build --watch app/ts/tsconfig.json | scripts/tsc_filter.rb) &

export MAP_ENV=development
scripts/start.sh
