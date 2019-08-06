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

if [ -z "$(command -v ruby)" ]; then
    # No ruby installed
    echo "Ruby isn't available.  Any TypeScript errors will appear in this console."
    tsc --build --watch app/ts/tsconfig.json &
else
    # Ruby is available
    (tsc --build --watch app/ts/tsconfig.json | scripts/tsc_filter.rb) &
fi

export MAP_ENV=development
scripts/start.sh
