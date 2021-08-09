#!/bin/bash

# Usage:
# ./rpminspect_runner.sh $TASK_ID $PREVIOUS_TAG $TEST_NAME
#
# The script recognizes following environment variables:
# RPMINSPECT_CONFIG - path to the rpminspect config file
# RPMINSPECT_PROFILE_NAME - rpminspect profile to use
# PREVIOUS_TAG - koji tag where to look for previous builds
# DEFAULT_RELEASE_STRING - release string to use in case builds
#                          don't have them (e.g.: missing ".fc34")
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

quit_if_disabled() {
    # Quit the script if the inspection is disabled in config/profile file.
    # Params:
    # $1: inspection name
    local inspection_name=$1

    is_enabled=$(python3 -c "\
import yaml; \
import sys; \
is_enabled = yaml.safe_load(open(sys.argv[1])).get('inspections', {}).get(sys.argv[2], True); \
print('yes', end='') if is_enabled else print('no', end='')" "effective_rpminspect.yaml" "${inspection_name}")
    if [ "${is_enabled}" == "no" ]; then
        echo
        echo "This inspection is disabled."
        exit 0
    fi
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

workdir="${RPMINSPECT_WORKDIR:-/var/tmp/rpminspect/}${task_id}-${before_build}"
results_cache_dir="${RPMINSPECT_WORKDIR:-/var/tmp/rpminspect/}results_cache"
results_cached_file="${RPMINSPECT_WORKDIR:-/var/tmp/rpminspect/}cached"

mkdir -p ${workdir}
mkdir -p "${results_cache_dir}"


# cache results — the following section should run in CI only once
if [ ! -f "${results_cached_file}" ]; then
    after_build=$(get_after_build $task_id)
    before_build=$(get_before_build $after_build $previous_tag)

    echo -n "${after_build}" > "${results_cache_dir}/after_build"
    echo -n "${before_build}" > "${results_cache_dir}/before_build"

    if [ ! -f "effective_rpminspect.yaml" ]; then
        # Get the effective config file
        /usr/bin/rpminspect -c ${config} \
                ${debug:+-v} \
                ${profile_name:+--profile=$profile_name} \
                -D > effective_rpminspect.yaml || :
    fi

    rpminspect_get_local_config.sh "${after_build}"

    # Update the virus dababase
    freshclam 2>&1 > freshclam.log || :

    # Update annobin
    # FIXME: we don't want to touch packages when the base image is Rawhide...
    #     We can uncomment this once the latest annocheck can be installed from a stable repo.
    #dnf update -y annobin* 2>&1 > update_annobin.log || :

    # Update the data package
    dnf update -y rpminspect-data* 2>&1 > update_rpminspect_data.log || :

    # Run all inspections and cache results
    /usr/bin/rpminspect -c ${config} \
            ${debug:+-v} \
            --format=json \
            ${arches:+--arches=$arches} \
            ${default_release_string:+--release=$default_release_string} \
            ${profile_name:+--profile=$profile_name} \
            ${before_build} \
            ${after_build} \
            > results.json 2> stderr.log || :

    # Convert JSON to text and store results of each inspection to a separate file
    rpminspect_json2text.py "${results_cache_dir}" results.json
    touch "${results_cached_file}"
fi

after_build=$(cat "${results_cache_dir}/after_build")
before_build=$(cat "${results_cache_dir}/before_build")

# Get description for current inspection
/usr/bin/rpminspect -l -v | awk -v RS= -v ORS='\n\n' "/    ${test_name}\n/" | sed -e 's/^[ \t]*//' | tail -n +2 > "${results_cache_dir}/${test_name}_description"

echo "rpminspect version: ${RPMINSPECT_VERSION} (with data package: ${RPMINSPECT_DATA_VERSION})"
echo "rpminspect profile: ${profile_name:-none}"
echo "new build: ${after_build}"
if [ -z "${before_build}" ]; then
    echo "old build: not found (in ${previous_tag} $(basename ${koji_bin}) tag)"
else
    echo "old build: ${before_build} (found in ${previous_tag} $(basename ${koji_bin}) tag)"
fi
echo
echo "Test description:"
cat "${results_cache_dir}/${test_name}_description"
echo "======================================== Test Output ========================================"

quit_if_disabled "${test_name}"

if [ -f "${results_cache_dir}/${test_name}_result" ]; then
    cat "${results_cache_dir}/${test_name}_result"
    rc=$(cat "${results_cache_dir}/${test_name}_status")
else
    # This inspection did not run (modularity inspection?)
    cat "${results_cache_dir}/skipped_result"
    rc=0  # success
fi

exit $((rc))
