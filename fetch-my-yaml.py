#!/usr/bin/python3

"""Clone given git repository and copy rpminspect.yaml to the current working directory."""

import shutil
import tempfile
from pathlib import Path
from typing import List

import click
import git
from retry import retry


@retry((git.exc.GitCommandError), delay=60, tries=10, log_traceback=True)
def clone_and_copy(repo_url: str, branches: List[str], commit: str) -> None:
    """Clone given git repository and copy rpminspect.yaml to the current working directory."""
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

        rpminspect_yaml_path = Path(tmp_dir, "rpminspect.yaml")
        if rpminspect_yaml_path.is_file():
            print("rpminspect.yaml file found!")
            shutil.copy(rpminspect_yaml_path, Path(Path.cwd(), "rpminspect.yaml"))
        else:
            print("No rpminspect.yaml in the repository...")


@click.command()
@click.argument("repo-url")
@click.argument("branches")
@click.argument("commit")
def main(repo_url: str, branches: str, commit: str) -> None:
    branches = branches.split(",")
    clone_and_copy(repo_url, branches, commit)


if __name__ == "__main__":
    main()
