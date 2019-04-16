#!/bin/bash

version="$1"

if [ "$version" = "" ]; then
    version="v`date '+%Y%m%d%H%M%S'`"
fi

set -eou pipefail

cd "`dirname "$0"`/../"

if [ "`git status --porcelain`" != "" ] || [ "`git status --ignored --porcelain`" != "" ]; then
    echo "Your working directory isn't clean.  Clean with 'git clean -fdx' before running this script."
    exit
fi

for module in api ui; do
    echo "================================================================================"
    echo "== Preparing $module"
    echo "================================================================================"
    (
        cd "$module"
        ./bootstrap.sh
    )

    # Bundle our shared library with each app
    cp -a maplib $module/app

    # Write the version file
    echo "$version" > "$module/VERSION"

    tar czf "$module.tgz" "$module"
    (
        cd "$module"
        git clean -fdx
    )

    echo "================================================================================"
    echo "== Release written to $module.tgz"
    echo "================================================================================"
done
