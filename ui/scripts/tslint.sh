#!/bin/bash

tslint -t verbose --project "`dirname "$0"`"/../app/ts ${1+"$@"}
