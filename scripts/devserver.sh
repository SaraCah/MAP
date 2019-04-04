#!/bin/bash

set -eou pipefail

which tsc >/dev/null

cd "`dirname "$0"`/../"

trap "exit" INT TERM
trap "kill 0" EXIT
(tsc --watch app/ts/main.ts --outDir app/js | strings) &

scripts/start.sh
