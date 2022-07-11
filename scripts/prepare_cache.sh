#!/bin/bash

# Prepare cache for rpminspect.
# The after build is a build from Zuul -- it is a mock build provided in a form of a YUM repository.
# The before build is downloaded from Koji.

# repo_url="https://centos.softwarefactory-project.io/logs/11/11/9e75bb0c73d34f33b216e278645cb648efc4b929/check/mock-build/d39b3e8/repo/"

repo_url="$1"

if [ -z "${repo_url}" ]; then
    echo "Usage: $0 [repo-url]"
    exit 1
fi

set -e
set -x

here_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
workdir=${RPMINSPECT_WORKDIR:-${here_dir}}
cache_dir="${workdir}/cache"
after_cache_dir="${cache_dir}/after"
download_dir=$(mktemp -d -t rpminspect_download.XXXXXX)

rm -Rf "$cache_dir"
mkdir -p "${cache_dir}" "${after_cache_dir}"

rm -Rf "${download_dir}"
mkdir -p "$download_dir"

# list all NVRs in the Zuul YUM repository
nvrs=$(dnf repoquery -q --nvr --repofrompath="zuul-built,$repo_url" --repo zuul-built)

# download all RPMs from the YUM repository
for nvr in ${nvrs}; do
    pushd "${download_dir}"
        rpm_url=$(dnf download -q --repofrompath="zuul-built,${repo_url}" --url "${nvr}")
        wget "${rpm_url}"

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
pushd "${after_cache_dir}"
    mkdir -p "src/"
    pushd "src/"
        srpm_rpm=$(dnf repoquery -q --repofrompath="zuul-built,$repo_url" --repo zuul-built  | grep ".src$" | head -1)
        dnf download -q --repofrompath="zuul-built,$repo_url" --repo zuul-built --source "${srpm_rpm}"
    popd
popd


# fetch the previous build from Koji
package_name=$(echo "${srpm_rpm}" | sed 's/^\(.*\)-\([^-]\{1,\}\)-\([^-]\{1,\}\)$/\1/')
before_nvr=$(koji -p stream list-tagged --latest --inherit --quiet c9s-pending "${package_name}" | awk -F' ' '{ print $1 }')

rpminspect-centos --workdir "${cache_dir}" --arch src,noarch,x86_64 --fetch-only "${before_nvr}"
mv "${cache_dir}/${before_nvr}" "${cache_dir}/before"

# store before and after NVRs in text files in the cache directory
pushd "${cache_dir}"
    echo "${before_nvr}" > before_build
    echo "${srpm_rpm}" > after_build
popd
