#!/bin/bash

set -e

script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
workdir=${RPMINSPECT_WORKDIR:-${PWD}}
cache_dir="${workdir}/cache"

component_name=$(cat "${cache_dir}/component_name")

set -x

git clone --depth 1 --branch "${RPMINSPECT_YAML_BRANCH_NAME}" "${DIST_GIT_RPMS_URL}/${component_name}.git" repo
if [ -f "repo/rpminspect.yaml" ]; then
    cp "repo/rpminspect.yaml" "${PWD}/rpminspect.yaml"
fi
rm -Rf repo/
