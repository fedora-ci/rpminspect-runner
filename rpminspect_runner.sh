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
# OUTPUT_FILE - redirect the standard output into a file
# CONFIG_BRANCH - branch where to look for the package-specific config file
# RPMINSPECT_WORKDIR - workdir where to cache downloaded builds
# KOJI_BIN - path where to find "koji" binary

set -e

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
    if [ ${retval} -gt 2 ]; then
        # something unexpected happened — treat it as an infra error
        exit 2
    fi
    exit $retval
}

config=${RPMINSPECT_CONFIG:-/usr/share/rpminspect/fedora.yaml}
koji_bin=${KOJI_BIN:-/usr/bin/koji}

task_id=${1}
previous_tag=${2}
test_name=${3}

# In case there is no dist tag (like ".fc34") in the package name,
# rpminspect doesn't know which test configuration to use
default_release_string=${DEFAULT_RELEASE_STRING}

output_format=${OUTPUT_FORMAT:-text}

get_name_from_nvr() {
    # Extract package name (N) from NVR.
    # Params:
    # $1: NVR
    local nvr=$1
    # Pfff... close your eyes here...
    name=$(echo $nvr | sed 's/^\(.*\)-\([^-]\{1,\}\)-\([^-]\{1,\}\)$/\1/')
    echo -n ${name}
}

get_after_build() {
    # Convert task id to NVR.
    # Params:
    # $1: task id
    local task_id=$1
    after_build=$(${koji_bin} taskinfo $task_id | grep Build | awk -F' ' '{ print $2 }')
    echo -n ${after_build}
}

get_before_build() {
    # Find previous build for given NVR.
    # The assumption is that the given NVR is not tagged in the "previous_tag".
    # If the NVR is tagger in the "previous_tag", then it has to be the latest NVR
    # for that packages in that tag.
    # Params:
    # $1: NVR
    # $2: Koji tag where to look for older builds
    local after_build=$1
    local previous_tag=$2
    local package_name=$(get_name_from_nvr $after_build)
    before_build=$(${koji_bin} list-tagged --latest --inherit --quiet ${previous_tag} ${package_name} | awk -F' ' '{ print $1 }')
    if [ "${before_build}" == "${after_build}" ]; then
        latest_two=$(${koji_bin} list-tagged --latest-n 2 --inherit --quiet ${previous_tag} ${package_name} | awk -F' ' '{ print $1 }')
        for nvr in $latest_two; do
            if [ "${nvr}" != "${after_build}" ]; then
                before_build=${nvr}
                break
            fi
        done
    fi
    echo -n ${before_build}
}

after_build=$(get_after_build $task_id)
before_build=$(get_before_build $after_build $previous_tag)


# obtain package-specific config
(
    repo_ref=$(${koji_bin} buildinfo ${after_build} | grep "^Source: " | awk '{ print $2 }' | sed 's|^git+||')
    repo_url=$(echo ${repo_ref} | awk -F'#' '{ print $1 }')
    commit_ref=$(echo ${repo_ref} | awk -F'#' '{ print $2 }')

    tmp_dir=$(mktemp -d -t rpminspect-XXXXXXXXXX)

    pushd ${tmp_dir}
        git init
        git remote add origin ${repo_url}

        if [ -n "$CONFIG_BRANCH" ]; then
            # we take the config from the HEAD of the given branch
            git fetch origin "refs/heads/${CONFIG_BRANCH}" --depth 1
            git checkout ${CONFIG_BRANCH}
        else
            # we take the config from the build commit
            git fetch origin
            git checkout ${commit_ref}
        fi
    popd

    # and finally, copy the config to the current directory
    cp ${tmp_dir}/rpminspect.yaml . || :
) > clone.log 2>&1


rpminspect -c ${config} \
           ${output_format:+--format=$output_format} \
           --arches x86_64,noarch,src \
           ${default_release_string:+--release=$default_release_string} \
           ${test_name:+--tests=$test_name} \
           ${before_build} \
           ${after_build} \
           > ${OUTPUT_FILE:-/dev/stdout}
