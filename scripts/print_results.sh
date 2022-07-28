#!/bin/bash

set -e

test_name="${1}"
script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
results_cache_dir="${RPMINSPECT_WORKDIR:-${PWD}}/results_cache"


trap fix_rc EXIT SIGINT SIGSEGV
fix_rc() {
    retval=$?
    # rpminspect status codes:
    # RI_INSPECTION_SUCCESS = 0,   /* inspections passed */
    # RI_INSPECTION_FAILURE = 1,   /* inspections failed */
    # RI_PROGRAM_ERROR = 2         /* program errored in some way */
    #
    # These status codes need to be translated to the TMT status codes,
    # so TMT can correctly recognize failures, errors, and successes.
    if [ ${retval} -gt 3 ]; then
        # something unexpected happened — treat it as infra error
        exit 2
    fi
    exit $retval
}


if [ -f "${results_cache_dir}/${test_name}_result" ]; then
    cat "${results_cache_dir}/${test_name}_result"
    rc=$(cat "${results_cache_dir}/${test_name}_status")
else
    # This inspection did not run (modularity inspection?)
    cat "${results_cache_dir}/skipped_result"
    rc=0  # success
fi

exit $((rc))
