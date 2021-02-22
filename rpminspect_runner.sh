#!/bin/bash

# Usage:
# ./rpminspect_runner.sh $TASK_ID $PREVIOUS_TAG [ $TEST_NAME ]
#
# The script recognizes following environment variables:
# RPMINSPECT_CONFIG - path to the rpminspect config file
# PREVIOUS_TAG - koji tag where to look for previous builds
# DEFAULT_RELEASE_STRING - release string to use in case builds
#                          don't have them (e.g.: missing ".fc34")
# OUTPUT_FORMAT - rpminspect output format (text, json, xunit)
# RPMINSPECT_WORKDIR - workdir where to cache downloaded builds
# KOJI_BIN - path where to find "koji" binary

set -e
PATH=/usr/bin:/usr/sbin

trap fix_rc EXIT SIGINT SIGSEGV
fix_rc() {
    retval=$?
    # rpminspect status codes:
    # RI_INSPECTION_SUCCESS = 0,   /* inspections passed */
    # RI_INSPECTION_FAILURE = 1,   /* inspections failed */
    # RI_PROGRAM_ERROR = 2         /* program errored in some way */
    #
    # These status codes need to be translated into tmt status codes,
    # so tmt can correctly recognize failures, errors, and successes.
    if [ ${retval} -gt 2 ]; then
        # something unexpected happened — treat it as an infra error
        exit 2
    fi
    exit ${retval}
}

config=${RPMINSPECT_CONFIG:-/usr/share/rpminspect/fedora.yaml}
koji_bin=${KOJI_BIN:-/usr/bin/koji}
koji_brand="$(basename "${koji_bin}")"
koji_hub="https://koji.fedoraproject.org/kojihub"

task_id=${1}
previous_tag=${2}
test_name=${3}

# In case there is no dist tag (like ".fc34") in the package name,
# rpminspect doesn't know which test configuration to use
default_release_string=${DEFAULT_RELEASE_STRING}

output_format=${OUTPUT_FORMAT}

get_name_from_nvr() {
    # Extract package name (N) from NVR.
    # Params:
    # $1: NVR
    nvr=$1
    hubout="$(xmlrpc "${koji_hub}" getBuild "${nvr}")"
    mark="$(echo "${hubout}" | grep -n ": 'name'$" | cut -d ':' -f 1)"
    name="$(echo "${hubout}" | head -n $((mark + 1)) | tail -n 1 | cut -d "'" -f 2)"
    echo -n "${name}"
}

get_after_build() {
    # Convert task id to NVR.
    # Params:
    # $1: task id
    task_id=$1
    after_build="$(${koji_bin} taskinfo "${task_id}" | grep Build | awk -F' ' '{ print $2 }')"
    echo -n "${after_build}"
}

get_before_build() {
    # Find previous build for given NVR.
    # The assumption is that the given NVR is not tagged in the "previous_tag".
    # If the NVR is tagger in the "previous_tag", then it has to be the latest NVR
    # for that packages in that tag.
    # Params:
    # $1: NVR
    # $2: Koji tag where to look for older builds
    after_build=$1
    updates_tag=$2
    package_name=$(get_name_from_nvr "${after_build}")
    before_build=$(${koji_bin} list-tagged --latest --inherit --quiet "${updates_tag}" "${package_name}" | awk -F' ' '{ print $1 }')
    if [ "${before_build}" == "${after_build}" ]; then
        latest_two=$(${koji_bin} list-tagged --latest-n 2 --inherit --quiet "${updates_tag}" "${package_name}" | awk -F' ' '{ print $1 }')
        for nvr in $latest_two; do
            if [ "${nvr}" != "${after_build}" ]; then
                before_build=${nvr}
                break
            fi
        done
    fi
    echo -n "${before_build}"
}

after_build=$(get_after_build $task_id)
before_build=$(get_before_build $after_build $previous_tag)

rpminspect -c ${config} ${output_format:+--format=$output_format} --arches x86_64,noarch,src ${default_release_string:+--release=$default_release_string} ${test_name:+--tests=$test_name} ${before_build} ${after_build} > rpminspect_stdout
