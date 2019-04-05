#!/bin/bash

cd "`dirname "$0"`/../"

scripts/jruby.sh app/util/migration_runner.rb
