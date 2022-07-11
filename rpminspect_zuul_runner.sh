#!/bin/bash

set -e

print_usage() {
    cat << EOF
Usage:
${0} --repo-url <URL> --test-name <test-name> [options]

Options:
-r, --repo-url=REPO_URL     YUM repository URL
-t, --test-name=TEST_NAME   inspection name
-c, --cached                just print cached results
-e, --cache-cleanup         delete cache at the end
-h, --help                  show this help and quit
EOF
}

here_dir=$(cd -- "$( dirname -- "$( readlink -f "${BASH_SOURCE[0]}")" )" &> /dev/null && pwd)
scripts_dir="${here_dir}/scripts"
workdir=${RPMINSPECT_WORKDIR:-${here_dir}}
cache_dir="${workdir}/cache"

repo_url=
test_name=
cached="false"
cache_cleanup="false"

short_opts="hcr:t:e"
long_opts="help,cached,repo-url:,test-name:,cache-cleanup"
opt=$(getopt -n "$0" --options "${short_opts}"  --longoptions "${long_opts}"  -- "$@")
eval set -- "$opt"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--repo-url)
            repo_url="${2}"
            shift 2
            ;;
        -t|--test-name)
            test_name="${2}"
            shift 2
            ;;
        -e|--cache-cleanup)
            cache_cleanup="true"
            shift
            ;;
        -c|--cached)
            cached="true"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        --)
            shift
            ;;
        *)
            print_usage
            exit 1
    esac
done
if [ "${cached}" == "false" ]; then
    if [ -z "${repo_url}" ] || [ -z "${test_name}" ]; then
        echo "Missing required param. See \"${0} -h\" for help."
        exit 1
    fi
fi

if [ "${cached}" == "false" ]; then
    rm -f ./*.log
    # Prepare cache
    "${scripts_dir}/prepare_cache.sh" "${repo_url}" > prepare_cache.log 2>&1
    # Update environment
    "${scripts_dir}/update_env.sh" > update_env.log 2>&1
    # Run rpminspect
    "${scripts_dir}/rpminspect_run.sh" > rpminspect_run.log 2>&1
    # Print results
fi
if [ "${cache_cleanup}" == "true" ]; then
    rm -Rf "${cache_dir}"
fi

"${scripts_dir}/print_results.sh" "${test_name}"
