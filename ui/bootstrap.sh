#!/bin/bash

JRUBY_VERSION="https://repo1.maven.org/maven2/org/jruby/jruby-complete/9.2.7.0/jruby-complete-9.2.7.0.jar"
JRUBY_SHA256="a43125f921e707eef861713028d79f60d2f4b024ea6af71a992395ee9e697c22"

function fail() {
    echo "ERROR: $*"
    echo "Aborting"
    exit 1
}


set -eou pipefail

echo
echo "Checking dependencies..."
which java || fail "Need Java runtime installed"
which curl || fail "Need curl installed"
which openssl || fail "Need openssl installed"
echo

cd "`dirname "$0"`"

mkdir -p distlibs

have_jruby=0

if [ -e distlibs/jruby-complete.jar ]; then
    checksum="`openssl dgst -sha256 distlibs/jruby-complete.jar | awk '{print $2}'`"
    if [ "$checksum" = $JRUBY_SHA256 ]; then
        have_jruby=1
    fi
fi

if [ "$have_jruby" != "1" ]; then
    echo
    echo "Fetching JRuby..."
    curl -L -s "$JRUBY_VERSION" > distlibs/jruby-complete.jar
    checksum="`openssl dgst -sha256 distlibs/jruby-complete.jar | awk '{print $2}'`"

    if [ "$checksum" != $JRUBY_SHA256 ]; then
        fail "JRuby checksum mismatch.  Freaking out."
        exit 1
    fi
fi

if [ ! -e "distlibs/gems/bin/bundle" ]; then
    echo
    echo "Installing bundler"
    scripts/jruby.sh -S gem install bundler
fi

echo
echo "Installing gems"
scripts/jruby.sh distlibs/gems/bin/bundle install

echo
echo "Installing JS libs"
(
    cd "app/ts"
    npm install
)

echo
echo "Building UI TypeScript code"
tsc --build app/ts/tsconfig.json
