#!/usr/bin/python3
# /// script
# dependencies = [
#   "fedora-distro-aliases",
#   "click",
# ]
# ///

import re

import click
from fedora_distro_aliases import get_distro_aliases

# TODO: There is no clean way to break down the `fedora-rawhide` from the aliases right now, using
#   fedora-all alias instead
# https://github.com/rpm-software-management/fedora-distro-aliases/issues/29
fedora_all = get_distro_aliases()["fedora-all"]


@click.command()
@click.argument("distro-name")
def main(distro_name: str) -> None:
    """
    Get the equivalent previous tag from the distro context
    """
    if fedora_match := re.match(r"fedora-(?P<branch>.+)", distro_name):
        branch = fedora_match.group("branch")
        if branch != "rawhide":
            # For numbered branches (e.g. fedora-42)
            branch = f"f{branch}"
    else:
        # TODO: Deal with epel and eln
        raise NotImplementedError
    distro_info = next(d for d in fedora_all if d.branch == branch)
    # TODO: would be cleaner if we made rpminspect_runner.sh a python script instead
    print(f"fc{distro_info.version_number}")
    print(f"f{distro_info.version_number}-updates")


if __name__ == "__main__":
    main()
