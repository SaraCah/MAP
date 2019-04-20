#!/bin/bash

export JVM_HEAP_SIZE="512m"

cd "`dirname "$0"`/../"

export GEM_HOME=$PWD/distlibs/gems

java -Dapp=MAPAPI ${JAVA_OPTS} -Xmx${JVM_HEAP_SIZE} -cp 'distlibs/*' org.jruby.Main ${1+"$@"}
