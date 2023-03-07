#!/bin/bash

set -e

workdir=${RPMINSPECT_WORKDIR:-${PWD}}
cache_dir="${workdir}/cache"
exts="yaml json dson"

component_name=$(cat "${cache_dir}/component_name")

set -x

git clone --depth 1 --branch "${RPMINSPECT_CONF_BRANCH_NAME}" "${DIST_GIT_RPMS_URL}/${component_name}.git" repo
for ext in ${exts} ; do
    cfgfile="rpminspect.${ext}"
    if [ -f "repo/${cfgfile}" ]; then
        cp "repo/${cfgfile}" "${PWD}/${cfgfile}"
    fi
done
rm -Rf repo/
