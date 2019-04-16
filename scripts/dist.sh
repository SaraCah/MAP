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

MODULES="api ui"

for module in $MODULES; do
    echo "================================================================================"
    echo "== Preparing $module"
    echo "================================================================================"
    (
        cd "$module"

        if [ "$module" != "api" ]; then
            # Save ourselves a bit of download time by pulling over the JRuby &
            # gems we fetched previously
            cp -a ../api/distlibs .
        fi


        ./bootstrap.sh
    )

    # Bundle our shared library with each app
    cp -a maplib $module/app

    # Write the version file
    echo "$version" > "$module/VERSION"

    tar czf "$module.tgz" "$module"
done

for module in $MODULES; do
    (
        cd "$module"
        git clean -fdx
    )

    echo "================================================================================"
    echo "== Release written to $module.tgz"
    echo "================================================================================"
done
