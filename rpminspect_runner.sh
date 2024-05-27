#!/bin/bash

# Usage:
# ./rpminspect_runner.sh $TASK_ID $PREVIOUS_TAG
#
# The script recognizes following environment variables:
# RPMINSPECT_CONFIG - path to the rpminspect config file
# RPMINSPECT_PROFILE_NAME - rpminspect profile to use
# PREVIOUS_TAG - koji tag where to look for previous builds
# DEFAULT_RELEASE_STRING - release string to use in case builds
#                          don't have them (e.g.: missing ".fc34")
# KOJI_BIN - path where to find "koji" binary
# KOJI_NVR - run rpminspect on this NVR instead of the TASK_ID
# ARCHES - a comma-separated list of architectures to test (e.g.: x86_64,noarch,src)
# IS_MODULE - "yes" if the given TASK_ID is a module task ID from MBS
# MBS_API_URL - Module Build System (MBS) API URL
# TESTS - a comma-separated list of inspections to run
# CLAMAV_DATABASE_MIRROR_URL - if set, use this mirror to update the clamav database
# IGNORE_LOCAL_RPMINSPECT_YAML - "yes" if the local rpminspect.yaml file should be ignored
# RPMINSPECT_YAML_LOOKUP_STRATEGY - one of: "branch", "commit", "fallback". Where to look for the local rpminspect.yaml file

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
    if [ ${retval} -gt 3 ]; then
        # something unexpected happened — treat it as an infra error
        exit 2
    fi
    exit $retval
}

config=${RPMINSPECT_CONFIG:-/usr/share/rpminspect/fedora.yaml}
koji_bin=${KOJI_BIN:-/usr/bin/koji}
exts="yaml json dson"

task_id=${1}
previous_tag=${2}


# In case there is no dist tag (like ".fc34") in the package name,
# rpminspect doesn't know which test configuration to use
default_release_string=${DEFAULT_RELEASE_STRING}

profile_name=${RPMINSPECT_PROFILE_NAME}

arches=${ARCHES}

is_module="${IS_MODULE}"

tests="${TESTS}"

# support running out of git tree
MYDIR="$(dirname $(realpath "$0"))"
export PATH="$PATH:$MYDIR:$MYDIR/scripts"

get_name_from_nvr() {
    # Extract package name (N) from NVR.
    # Params:
    # $1: NVR
    local nvr=$1
    # Pfff... close your eyes here...
    name=$(echo $nvr | sed 's/^\(.*\)-\([^-]\{1,\}\)-\([^-]\{1,\}\)$/\1/')
    echo -n ${name}
}

get_ns_from_module_nvr() {
    # Extract "module_name-stream" (ns) from NVR.
    # Params:
    # $1: NVR
    local nvr=$1
    name=$(echo $nvr | sed 's/^\(.*[^-]\{1,\}\)-\([^-]\{1,\}\)$/\1/')
    echo -n ${name}
}

get_task_info() {
    # Get information about given task id. Specifically NVR and whether it is a scratch build or not.
    # Params:
    # $1: task id
    local task_id=$1
    task_info=$("$koji_bin" taskinfo -v -r "$task_id")
    build_nvr=$(basename "$(echo "$task_info" | grep "SRPM: " | head -1 | awk '{ print $2 }' | sed 's|\.src.rpm$||g')")
    is_scratch="no"
    is_scratch_output=$(echo "$task_info" | grep "scratch: True")
    if [ -n "$is_scratch_output" ]; then
        is_scratch="yes"
    fi
    echo -n "${build_nvr} ${is_scratch}"
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

	# Reset $before_build so we can return an empty string if no previous builds are found
	before_build=''

	# Look back 2 builds to see if we have an older version to compare against
        latest_two=$(${koji_bin} list-tagged --latest-n 2 --inherit --quiet ${previous_tag} ${package_name} | awk -F' ' '{ print $1 }')
        for nvr in $latest_two; do
            if [ "${nvr}" != "${after_build}" ]; then
                before_build=${nvr}
                break
            fi
        done

    fi
    # Provide either an empty string or the previous build
    echo -n ${before_build}
}

get_before_module_build() {
    # Find previous module build for given NVR.
    # The assumption is that the given NVR is not tagged in the "previous_tag".
    # If the NVR is tagger in the "previous_tag", then it has to be the latest NVR
    # for that module in that tag.
    # Params:
    # $1: NVR
    # $2: Koji tag where to look for older builds
    local after_build=$1
    local previous_tag=$2
    local name=$(get_name_from_nvr $after_build)
    local name_stream=$(get_ns_from_module_nvr $after_build)
    before_build=$(${koji_bin} list-tagged --inherit --latest-n=2 --quiet ${previous_tag} ${name} | grep "^${name_stream}" | awk -F' ' '{ print $1 }' | tail -1)

    if [ "${before_build}" == "${after_build}" ]; then
        # Reset $before_build so we can return an empty string if no previous builds are found
        before_build=''

        # Get the latest-1 NVR
        before_build_candidate=$(${koji_bin} list-tagged --inherit --latest-n=2 --quiet ${previous_tag} ${name} | grep "^${name_stream}" | awk -F' ' '{ print $1 }'  | head -1)
        if [ "${before_build_candidate}" != "${after_build}" ]; then
                before_build=${before_build_candidate}
        fi
    fi

    # Provide either an empty string or the previous build
    echo -n ${before_build}
}


freshclam_log=${TMT_TEST_DATA:-.}/freshclam.log

update_clamav_database() {
    # Update the virus dababase
    config_file="freshclam.conf"
    cp "/etc/$config_file" .
    if [ -n "$CLAMAV_DATABASE_MIRROR_URL" ]; then
        sed -i "s|^DatabaseMirror .*|DatabaseMirror $CLAMAV_DATABASE_MIRROR_URL|" "$config_file"
    fi

    freshclam --config-file="$config_file" > "$freshclam_log" 2>&1 || :
    # freshclam returns 0 even if the update download fails
    # https://github.com/Cisco-Talos/clamav/issues/965
    # Let's check the log for the complaint about the outdated database
    # and return non-zero if we find it there
    ! grep -q 'virus database is older' "$freshclam_log"
}


after_build_param="${task_id}"

before_build=''

if [ "${is_module}" == "yes" ]; then

    if [ -n "${KOJI_NVR}" ]; then
        after_build="${KOJI_NVR}"
    else
        module_info=$(curl "${MBS_API_URL}/module-build-service/1/module-builds/${task_id}")
        name=$(echo "${module_info}" | jq -r .name)
        stream=$(echo "${module_info}" | jq -r .stream)
        version=$(echo "${module_info}" | jq -r .version)
        context=$(echo "${module_info}" | jq -r .context)
        after_build="${name}-${stream}-${version}.${context}"
    fi

    if [ -n "$previous_tag" ]; then
        before_build=$(get_before_module_build "${after_build}" "${previous_tag}")
    fi
    after_build_param="${after_build}"
else
    if [ -n "${KOJI_NVR}" ]; then
        after_build="${KOJI_NVR}"
        after_build_param="${after_build}"
    else
        task_info=$(get_task_info "${task_id}")
        after_build=$(echo "$task_info" | awk '{ print $1 }')
        is_scratch=$(echo "$task_info" | awk '{ print $2 }')
        if [ -n "$previous_tag" ]; then
            before_build=$(get_before_build "${after_build}" "${previous_tag}")
        fi
        if [ "$is_scratch" == "no" ]; then
            after_build_param="$after_build"
        fi
    fi
fi

repo_ref=$("${koji_bin}" taskinfo -v "${task_id}" | grep "Source: " | awk '{ print $2 }' | sed 's|^git+||')
repo_url=$(echo "${repo_ref}" | awk -F'#' '{ print $1 }' | awk -F'?' '{ print $1 }')
commit_ref=$(echo "${repo_ref}" | awk -F'#' '{ print $2 }' | awk -F'?' '{ print $1 }')

if [ "${IGNORE_LOCAL_RPMINSPECT_YAML}" == "yes" ]; then
    echo "IGNORE_LOCAL_RPMINSPECT_YAML is set to "yes" -> skipping fetching the local rpminspect.yaml file"
else
    fetch-my-conf.py ${RPMINSPECT_YAML_LOOKUP_STRATEGY:+--strategy "$RPMINSPECT_YAML_LOOKUP_STRATEGY"} "${repo_url}" "${CONFIG_BRANCHES}" "${commit_ref}" || :
fi

if ! update_clamav_database; then
    # Oops, incremental update of the ClamAV virus database has failed.
    # Let's try again. freshclam should attempt to download the whole
    # daily.cvd this time, instead of just incremental patches.
    update_clamav_database || :
fi

# Update the data packages, but from COPR, not from the official Fedora repositories
dnf -y update --disablerepo="fedora*" "${RPMINSPECT_PACKAGE_NAME}" "${RPMINSPECT_DATA_PACKAGE_NAME}" fedora-license-data > update_rpminspect.log 2>&1 || :

output_filename=${TMT_TEST_DATA:-.}/result.json
verbose_log=${TMT_TEST_DATA:-.}/verbose.log
# Workdir used by rpminspect
workdir="${PWD}/workdir/"
# Temp dir should be inside the container's default workdir; The default workdir can be a mounted volume,
# which can provide better IO performance under certain circumstances.
tmpdir="${PWD}/tempfiles/"
mkdir -p "${workdir}" "${tmpdir}"

# Virus inspection is a heavy user of the temp dir
export TMPDIR="${tmpdir}"

# Run all inspections
rc=0

(
    echo "Checking the component-specific rpminspect config file..."
    set -x
    for ext in ${exts} ; do
        if [ -f "rpminspect.${ext}" ]; then
            echo "=> rpminspect.${ext} contents:"
            cat "rpminspect.${ext}"
        fi
    done
    rpm -qa | grep rpminspect
    /usr/bin/rpminspect -c ${config} \
        --workdir "${workdir}" \
        --format=json \
        --output="${output_filename}" \
        --verbose \
        ${arches:+--arches=$arches} \
        ${default_release_string:+--release=$default_release_string} \
        ${profile_name:+--profile=$profile_name} \
        ${tests:+--tests=$tests} \
        ${before_build} \
        "${after_build_param}"
) > "$verbose_log" 2>&1 || rc=$?

rm -Rf "${workdir}"
rm -Rf "${tmpdir}"

case $rc in
    0) tmtresult="pass" ;;
    1) tmtresult="fail" ;;
    *) tmtresult="error" ;;
esac

# when running through TMT, create custom results.yaml to include extra logs
# TODO: add duration: 00:11:22
if [ -n "$TMT_TEST_DATA" ]; then
    # get rpminspect's results viewer
    curl --silent --show-error --fail --retry 5 \
        --output "$TMT_TEST_DATA/viewer.html" \
        https://raw.githubusercontent.com/rpminspect/rpminspect/main/contrib/viewer.html

    cat <<EOF > "$TMT_TEST_DATA/results.yaml"
- name: /rpminspect
  result: $tmtresult
  log:
    - ../output.txt
    - viewer.html
    - verbose.log
    - result.json
    - freshclam.log
EOF
    # if dist-git uses a custom rpminspect config, add that as an artifact as well
    for ext in ${exts} ; do
        cfgfile="rpminspect.${ext}"
        if [ -e "${cfgfile}" ]; then
            cp "${cfgfile}" "$TMT_TEST_DATA"
            echo "    - data/rpminspect/data/${cfgfile}" >> "$TMT_TEST_DATA/results.yaml"
        fi
    done
    echo "running in TMT, wrote $TMT_TEST_DATA/results.yaml"
fi
