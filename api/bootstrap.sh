#!/bin/bash

JRUBY_VERSION="https://repo1.maven.org/maven2/org/jruby/jruby-complete/9.2.6.0/jruby-complete-9.2.6.0.jar"
JRUBY_SHA256="602e6b2ace6cd18e33b02a41b3a2e188fcdcacc35856df2c76afea6908b8c8c5"

function fail() {
    echo "ERROR: $*"
    echo "Aborting"
    exit 1
}


set -eou pipefail

echo "Checking dependencies..."
which java || fail "Need Java runtime installed"
which curl || fail "Need curl installed"
which openssl || fail "Need openssl installed"
echo

cd "`dirname "$0"`"

mkdir -p distlibs

have_jruby=0

if [ -e distlibs/jruby-complete.jar ]; then
    checksum="`openssl dgst -sha256 -r distlibs/jruby-complete.jar | awk '{print $1}'`"
    if [ "$checksum" = $JRUBY_SHA256 ]; then
        have_jruby=1
    fi
fi

if [ "$have_jruby" != "1" ]; then
    echo "Fetching JRuby..."
    curl -L -s "$JRUBY_VERSION" > distlibs/jruby-complete.jar
    checksum="`openssl dgst -sha256 -r distlibs/jruby-complete.jar | awk '{print $1}'`"

    if [ "$checksum" != $JRUBY_SHA256 ]; then
        fail "JRuby checksum mismatch.  Freaking out."
        exit 1
    fi
fi

if [ ! -e "distlibs/gems/bin/bundle" ]; then
    echo "Installing bundler"
    scripts/jruby.sh -S gem install bundler
fi

echo "Installing gems"
scripts/jruby.sh distlibs/gems/bin/bundle install
