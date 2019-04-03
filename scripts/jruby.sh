#!/bin/bash

export JVM_HEAP_SIZE="1024m"

cd "`dirname "$0"`/../"

export GEM_HOME=$PWD/distlibs/gems

java -Xmx${JVM_HEAP_SIZE} -cp 'distlibs/*' org.jruby.Main ${1+"$@"}
