#!/bin/bash

set -e

script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
workdir=${RPMINSPECT_WORKDIR:-${PWD}}
cache_dir="${workdir}/cache"
results_cache_dir="${workdir}/results_cache"

mkdir -p "${results_cache_dir}"

before_build=$(cat "${cache_dir}/before_build")
after_build=$(cat "${cache_dir}/after_build")

before_build_dir="${cache_dir}/${before_build}"
after_build_dir="${cache_dir}/${after_build}"

set -x

cat rpminspect.yaml || :

"${RPMINSPECT_BIN}" \
    --format=json \
    --output=results.json \
    --verbose \
    ${RPMINSPECT_PROFILE:+--profile=$RPMINSPECT_PROFILE} \
    ${RPMINSPECT_DEFAULT_RELEASE_STRING:+--release=$RPMINSPECT_DEFAULT_RELEASE_STRING} \
    "${before_build_dir}" \
    "${after_build_dir}" || :

# Convert JSON to text and store results of each inspection to a separate file
if [ -f "results.json" ]; then
    python3 "${script_dir}/rpminspect_json2text.py" "${results_cache_dir}" results.json
fi
