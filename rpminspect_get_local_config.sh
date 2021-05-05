#!/bin/bash

# Usage:
# ./rpminspect_get_local_config.sh $AFTER_BUILD
#
# The script recognizes following environment variables:
# KOJI_BIN - path where to find "koji" binary
# CONFIG_BRANCH - git branch where to look for the rpminspect.yaml


config_branch="${CONFIG_BRANCH}"
koji_bin="${KOJI_BIN:-/usr/bin/koji}"

after_build="${1}"

repo_ref=$(${koji_bin} buildinfo ${after_build} | grep "^Source: " | awk '{ print $2 }' | sed 's|^git+||')
repo_url=$(echo ${repo_ref} | awk -F'#' '{ print $1 }')
commit_ref=$(echo ${repo_ref} | awk -F'#' '{ print $2 }')

# obtain the package-specific config file
if [ ! -f "rpminspect.yaml" ]; then
    (
        tmp_dir=$(mktemp -d -t rpminspect-XXXXXXXXXX)

        pushd ${tmp_dir}
            git init
            git remote add origin ${repo_url}

            if [ -n "${config_branch}" ]; then
                # we take the config from the HEAD of the given branch
                git fetch origin "refs/heads/${config_branch}" --depth 1
                git checkout ${config_branch}
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
