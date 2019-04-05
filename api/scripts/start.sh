#!/bin/bash

set -eou pipefail

cd "`dirname "$0"`/../"

scripts/jruby.sh distlibs/gems/bin/fishwife app/config.ru --host 0.0.0.0 --port 5678
