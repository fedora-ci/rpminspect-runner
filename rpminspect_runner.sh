#!/bin/bash

# Usage:
# ./rpminspect_runner.sh $TASK_ID $PREVIOUS_TAG [ $TEST_NAME ]
#
# The script recognizes following environment variables:
# RPMINSPECT_CONFIG - path to the rpminspect config file
# RPMINSPECT_PROFILE_NAME - rpminspect profile to use
# PREVIOUS_TAG - koji tag where to look for previous builds
# DEFAULT_RELEASE_STRING - release string to use in case builds
#                          don't have them (e.g.: missing ".fc34")
# OUTPUT_FORMAT - rpminspect output format (text, json, xunit)
# OUTPUT_FILE - redirect the standard output into a file
# CONFIG_BRANCH - branch where to look for the package-specific config file
# RPMINSPECT_WORKDIR - workdir where to cache downloaded builds
# KOJI_BIN - path where to find "koji" binary
# ARCHES - a comma-separated list of architectures to test (e.g.: x86_64,noarch,src)
# DEBUG - enable more verbose output (on/off)

if [ "$DEBUG" == "on" ]; then
    debug=on
fi

set -e
${debug:+set -x} \

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

profile_name=${RPMINSPECT_PROFILE_NAME}

arches=${ARCHES}

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


repo_ref=$(${koji_bin} buildinfo ${after_build} | grep "^Source: " | awk '{ print $2 }' | sed 's|^git+||')
repo_url=$(echo ${repo_ref} | awk -F'#' '{ print $1 }')
commit_ref=$(echo ${repo_ref} | awk -F'#' '{ print $2 }')
# obtain a package-specific config file
if [ ! -f "rpminspect.yaml" ]; then
    (
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

        # and finally, copy the config to the current directory;
        # or create an empty one if missing in the repository
        cp ${tmp_dir}/rpminspect.yaml . || echo "inspections: {}" > rpminspect.yaml
        rm -Rf "${tmp_dir}"
    ) >> clone.log 2>&1
fi

if [ -n "$test_name" ]; then
    # get the effective config file
    # https://github.com/rpminspect/rpminspect/issues/306
    rpminspect ${debug:+-v} -c ${config} ${profile_name:+--profile=$profile_name} -D > effective_rpminspect.yaml || :

    is_enabled=$(python3 -c "\
import yaml; \
import sys; \
is_enabled = yaml.safe_load(open(sys.argv[1])).get('inspections', {}).get(sys.argv[2], True); \
print('yes', end='') if is_enabled else print('no', end='')" "effective_rpminspect.yaml" "${test_name}")
    if [ "${is_enabled}" == "no" ]; then
        echo "\"${test_name}\" inspection is disabled in the package-specific configuration file: ${repo_url} branch/ref: ${CONFIG_BRANCH:-$commit_ref}"
        echo "Skipping..."
        exit 0
    fi
fi

workdir="${RPMINSPECT_WORKDIR:-/var/tmp/rpminspect/}${task_id}-${before_build}"
downloaded_file=${workdir}/downloaded

mkdir -p ${workdir}

rpminspect_tmp_dir="/var/tmp/rpminspect/"
# Print information about disk space
if [ "$debug" == "on" ]; then
    df -h "${workdir}"
    du -h -s "${workdir}" "${rpminspect_tmp_dir}" || :
fi

# Download and cache packages, if not downloaded already
if [ ! -f ${downloaded_file} ]; then
    rpminspect ${debug:+-v} -c ${config} ${arches:+--arches=$arches} -w ${workdir} -f ${after_build}
    # Download also the before build, if it exists and is not the same as the after build
    if [ -n "${before_build}" ] && [ "${before_build}" != "${after_build}" ]; then
        rpminspect ${debug:+-v} -c ${config} ${arches:+--arches=$arches} -w ${workdir} -f ${before_build}
    fi
    touch ${downloaded_file}
fi

# Print information about disk space
if [ "$debug" == "on" ]; then
    df -h "${workdir}"
    du -h -s "${workdir}" "${rpminspect_tmp_dir}" || :
fi

# Print nicer output if the output format is "text"
if [ "${output_format}" == "text" ]; then
    if [ -z "${before_build}" ]; then
        echo "Running rpminspect on ${after_build}. No older builds were found in the \"${previous_tag}\" $(basename ${koji_bin}) tag."
    else
        echo "Comparing ${after_build} with the older ${before_build} found in the \"${previous_tag}\" $(basename ${koji_bin}) tag."
    fi
    echo
    echo "Test description:"

    test_description=$(rpminspect -l -v | awk -v RS= -v ORS='\n\n' "/    ${test_name}\n/")

    echo "${test_description}"
    echo
    echo "======================================== Test Output ========================================"
fi

rpminspect -c ${config} \
           ${debug:+-v} \
           ${output_format:+--format=$output_format} \
           ${arches:+--arches=$arches} \
           ${default_release_string:+--release=$default_release_string} \
           ${profile_name:+--profile=$profile_name} \
           ${test_name:+--tests=$test_name} \
           ${workdir}/${before_build} \
           ${workdir}/${after_build} \
           > ${OUTPUT_FILE:-/dev/stdout}
