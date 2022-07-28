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

script_dir=$(cd -- "$( dirname -- "$( readlink -f "${BASH_SOURCE[0]}")" )" &> /dev/null && pwd)
scripts_dir="${script_dir}/scripts"
configs_dir="${script_dir}/configs"
workdir=${RPMINSPECT_WORKDIR:-${PWD}}
cache_dir="${workdir}/cache"
logs_dir="${PWD}/logs"

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
        echo "Missing required param.\n\n"
        print_usage
        exit 1
    fi
fi

# Read configuration and export variables
set -o allexport
. "${configs_dir}/centos-9.conf"
set +o allexport

if [ "${cached}" == "false" ]; then
    rm -Rf "${logs_dir}"
    mkdir -p "${logs_dir}"
    # Prepare cache
    "${scripts_dir}/prepare_cache.sh" "${repo_url}" > "${logs_dir}/1_prepare_cache.log" 2>&1
    # Obtain component-specific rpminspect.yaml
    "${scripts_dir}/fetch_rpminspect_yaml.sh" "${repo_url}" > "${logs_dir}/2_fetch_rpminspect_yaml.log" 2>&1
    # Update environment
    "${scripts_dir}/update_env.sh" > "${logs_dir}/3_update_env.log" 2>&1
    # Run rpminspect
    "${scripts_dir}/run_rpminspect.sh" > "${logs_dir}/4_run_rpminspect.log" 2>&1
fi
if [ "${cache_cleanup}" == "true" ]; then
    rm -Rf "${cache_dir}"
fi

# Print results
"${scripts_dir}/print_results.sh" "${test_name}"
