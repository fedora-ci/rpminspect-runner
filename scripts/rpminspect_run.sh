#!/bin/bash

set -e
set -x

profile_name="$1"

here_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
workdir=${RPMINSPECT_WORKDIR:-${here_dir}}
cache_dir="${workdir}/cache"
results_cache_dir="${RPMINSPECT_WORKDIR:-${here_dir}}/results_cache"

mkdir -p "${results_cache_dir}"

/usr/bin/rpminspect-centos \
    --format=json \
    --output=results.json \
    --verbose \
    ${profile_name:+--profile=$profile_name} \
    "${cache_dir}/before" \
    "${cache_dir}/after" || :

# Convert JSON to text and store results of each inspection to a separate file
python3 "${here_dir}/rpminspect_json2text.py" "${results_cache_dir}" results.json
