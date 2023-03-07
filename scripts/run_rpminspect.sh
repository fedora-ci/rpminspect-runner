#!/bin/bash

set -e

script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
workdir=${RPMINSPECT_WORKDIR:-${PWD}}
cache_dir="${workdir}/cache"
results_cache_dir="${workdir}/results_cache"
exts="yaml json dson"

mkdir -p "${results_cache_dir}"

before_build=$(cat "${cache_dir}/before_build")
after_build=$(cat "${cache_dir}/after_build")

before_build_dir="${cache_dir}/${before_build}"
after_build_dir="${cache_dir}/${after_build}"

set -x

for ext in ${exts} ; do
    if [ -f "rpminspect.${ext}" ]; then
        echo "=> rpminspect.${ext} contents:"
        cat "rpminspect.${ext}"
    fi
done

"${RPMINSPECT_BIN}" \
    --format=json \
    --output=result.json \
    --verbose \
    ${RPMINSPECT_PROFILE:+--profile=$RPMINSPECT_PROFILE} \
    ${RPMINSPECT_DEFAULT_RELEASE_STRING:+--release=$RPMINSPECT_DEFAULT_RELEASE_STRING} \
    "${before_build_dir}" \
    "${after_build_dir}"
