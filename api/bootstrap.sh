#!/bin/bash

JRUBY_VERSION="https://repo1.maven.org/maven2/org/jruby/jruby-complete/9.2.7.0/jruby-complete-9.2.7.0.jar"
JRUBY_SHA256="a43125f921e707eef861713028d79f60d2f4b024ea6af71a992395ee9e697c22"

SOLR_VERSION="https://archive.apache.org/dist/lucene/solr/8.2.0/solr-8.2.0.tgz"
SOLR_SHA256="bfa4b39b236e5d714f4233138b8b5cb7e1996ddc0aad60052ce83c4b7bf33449"

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
scripts/jruby.sh distlibs/gems/bin/bundle update --all

# Remove BUNDLED WITH if it appears
if grep 'BUNDLED WITH' Gemfile.lock; then
    echo -e '/BUNDLED WITH\nd\nd\nw' | ed Gemfile.lock
fi

if [ ! -d "solr_dist" ]; then
    echo
    echo "Downloading Solr distribution"

    rm -rf solr_dist.tmp
    mkdir solr_dist.tmp

    (
        cd solr_dist.tmp
        curl -L -s "$SOLR_VERSION" > solr.tgz

        tar xzf solr.tgz
        rm -f solr.tgz
        mv solr-*/* .
        rmdir * 2>/dev/null || true
    )

    mv solr_dist.tmp solr_dist
fi
