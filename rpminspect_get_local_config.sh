#!/bin/bash

# Usage:
# ./rpminspect_get_local_config.sh <after-build>
#
# The script recognizes following environment variables:
# KOJI_BIN - path where to find "koji" binary
# CONFIG_BRANCH - git branch where to look for the rpminspect.yaml
# DEFAULT_CONFIG_BRANCH - same as CONFIG_BRANCH;
#     this branch will be used when CONFIG_BRANCH branch doesn't exist or if the CONFIG_BRANCH variable is not set


config_branch="${CONFIG_BRANCH}"
default_config_branch="${DEFAULT_CONFIG_BRANCH}"
koji_bin="${KOJI_BIN:-/usr/bin/koji}"

after_build="${1}"

repo_ref=$("${koji_bin}" buildinfo "${after_build}" | grep "^Source: " | awk '{ print $2 }' | sed 's|^git+||')
repo_url=$(echo "${repo_ref}" | awk -F'#' '{ print $1 }')
commit_ref=$(echo "${repo_ref}" | awk -F'#' '{ print $2 }')


find_config_branch() {
    # Determine in which branch we should look for the rpminspect.yaml file
    # Params:
    # $1: config branch
    # $2: default config brach
    local release_branch="$1"
    local default_branch="$2"

    for b in "${release_branch}" "${default_branch}"; do
        if [ -n "${b}" ]; then
            # check if branch exists in the remote repository
            git ls-remote --exit-code --heads "${repo_url}" "refs/heads/${b}" > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "${b}"
                return
            fi
        fi
    done

    echo -n ""
    return
}

# obtain the package-specific config file
if [ ! -f "rpminspect.yaml" ]; then
    (
        set -x
        branch=$(find_config_branch "${config_branch}" "${default_config_branch}")

        tmp_dir=$(mktemp -d -t rpminspect-XXXXXXXXXX)

        pushd "${tmp_dir}"
            git init
            git remote add origin "${repo_url}"

            if [ -n "${branch}" ]; then
                # we take the config from the HEAD of the given branch
                git fetch origin "refs/heads/${branch}" --depth 1
                git checkout "${branch}"
            else
                # we take the config from the build commit
                echo "Config branch doesn't exist, using the commit hash..."
                git fetch origin
                git checkout "${commit_ref}"
            fi
        popd

        # and finally, copy the config to the current directory;
        if [ -f "${tmp_dir}/rpminspect.yaml" ]; then
            cp "${tmp_dir}/rpminspect.yaml" .
        fi
        rm -Rf "${tmp_dir}"
    ) >> clone.log 2>&1
fi
