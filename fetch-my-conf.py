#!/usr/bin/python3

"""Clone given git repository and copy local rpminspect configuration file to the current working directory."""

import shutil
import tempfile
from pathlib import Path
from typing import List

import click
import git
from retry import retry


@retry((git.exc.GitCommandError), delay=60, tries=10, log_traceback=True)
def clone_and_copy(repo_url: str, branches: List[str], commit: str) -> None:
    """Clone given git repository and copy local rpminspect configuration file to the current working directory."""
    git_cmd = git.cmd.Git()

    for branch in branches:
        # Stop here if the branch exists
        if [x for x in git_cmd.ls_remote("--heads", repo_url, f"refs/heads/{branch}").split("\n") if x]:
            break
    else:
        # None of the branches exist -- we will need to use the commit hash
        branch = None

    with tempfile.TemporaryDirectory() as tmp_dir:
        if branch:
            print(f"Cloning {repo_url} (branch: {branch})...")
            git.Repo.clone_from(url=repo_url, to_path=tmp_dir, single_branch=True, branch=branch)
        else:
            print(f"Cloning {repo_url} (commit: {commit})...")
            git_repo = git.Repo.clone_from(url=repo_url, to_path=tmp_dir)
            git_repo.git.checkout(commit)

        for t in ["yaml", "json", "dson"]:
            cfgfile = "rpminspect.%s" % t
            rpminspect_cfg_path = Path(tmp_dir, cfgfile)

            if rpminspect_cfg_path.is_file():
                print("%s file found!" % cfgfile)
                shutil.copy(rpminspect_cfg_path, Path(Path.cwd(), cfgfile))
            else:
                print("No %s in the repository..." % cfgfile)


@click.command()
@click.argument("repo-url")
@click.argument("branches")
@click.argument("commit")
def main(repo_url: str, branches: str, commit: str) -> None:
    branches = branches.split(",")
    clone_and_copy(repo_url, branches, commit)


if __name__ == "__main__":
    main()
