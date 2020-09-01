#!/bin/bash

# Usage:
# ./rpminspect_runner.sh $TASK_ID $ARCH $RELEASE_ID

set -e

task_id=$1
release_id=$2
test=$3

after_nvr=$(koji taskinfo $task_id | grep Build | awk -F' ' '{ print $2 }')

name=$(echo $after_nvr | sed 's/^\(.*\)-\([^-]\{1,\}\)-\([^-]\{1,\}\)$/\1/')

before_nvr=$(koji list-tagged --latest --inherit --quiet ${release_id}-updates $name | awk -F' ' '{ print $1 }')

rpminspect --keep --arches x86_64,noarch --tests=${test} ${before_nvr} ${after_nvr}

