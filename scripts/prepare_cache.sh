#!/bin/bash

# Prepare cache for rpminspect.
# The after build is a build from Zuul -- it is a mock build provided in a form of a YUM repository.
# The before build is downloaded from Koji.

repo_url="$1"

if [ -z "${repo_url}" ]; then
    echo "Usage: $0 [repo-url]"
    exit 1
fi

set -e

script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
workdir=${RPMINSPECT_WORKDIR:-${PWD}}
cache_dir="${workdir}/cache"
after_cache_dir="${cache_dir}/after"
download_dir=$(mktemp -d -t rpminspect_download.XXXXXX)

rm -Rf "$cache_dir"
mkdir -p "${cache_dir}" "${after_cache_dir}"

rm -Rf "${download_dir}"
mkdir -p "$download_dir"

set -x

# list all NVRs in the Zuul YUM repository
nvrs=$(dnf repoquery -q --nvr --repofrompath="zuul-built,$repo_url" --repo zuul-built)

# download all RPMs from the YUM repository
for nvr in ${nvrs}; do
    pushd "${download_dir}"
        rpm_url=$(dnf download -q --repofrompath="zuul-built,${repo_url}" --url "${nvr}")
        wget --retry-connrefused --waitretry=5 --read-timeout=20 --timeout=15 -t 10 "${rpm_url}"

        # move the downloaded RPM to a arch-specific subdirectory
        rpm=$(basename "${rpm_url}")
        arch=$(rpm -qp --qf "%{arch}" "${rpm}")
        arch_dir="${after_cache_dir}/${arch}"
        mkdir -p "${arch_dir}"
        mv "${rpm}" "${arch_dir}"
    popd
done

# download the SRPM from the YUM repository
srpm_rpm=
after_build=
pushd "${after_cache_dir}"
    mkdir -p "src/"
    pushd "src/"
        srpm_rpm=$(dnf repoquery -q --repofrompath="zuul-built,$repo_url" --repo zuul-built  | grep ".src$" | head -1)
        after_build="mock-build-${srpm_rpm%.*}"
        dnf download -q --repofrompath="zuul-built,$repo_url" --repo zuul-built --source "${srpm_rpm}"
    popd
popd

mv "${after_cache_dir}" "${cache_dir}/${after_build}"

# fetch the previous build from Koji
component_name=$(echo "${srpm_rpm}" | sed 's/^\(.*\)-\([^-]\{1,\}\)-\([^-]\{1,\}\)$/\1/')
before_nvr=$("${KOJI_BIN}" -p "${KOJI_PROFILE}" list-tagged --latest --inherit --quiet "${BEFORE_BUILD_TAG}" "${component_name}" | awk -F' ' '{ print $1 }')

"${RPMINSPECT_BIN}" --verbose --workdir "${cache_dir}" "${RPMINSPECT_ARCHES:+--arches=$RPMINSPECT_ARCHES}" --fetch-only "${before_nvr}"

# store before, after NVRs, and component name in text files in the cache directory
pushd "${cache_dir}"
    echo -n "${before_nvr}" > before_build
    echo -n "${after_build}" > after_build
    echo -n "${component_name}" > component_name
popd
