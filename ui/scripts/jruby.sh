#!/bin/bash

export JVM_HEAP_SIZE="512m"

cd "`dirname "$0"`/../"

export GEM_HOME=$PWD/distlibs/gems

java -Dapp=MAPUI -Dfile.encoding=UTF-8 -Djava.security.egd=file:/dev/./urandom ${JAVA_OPTS} -Xmx${JVM_HEAP_SIZE} -cp 'distlibs/*' org.jruby.Main ${1+"$@"}
