#!/usr/bin/python3
# /// script
# dependencies = [
#   "fedora-distro-aliases",
#   "koji",
#   "click",
# ]
# ///

import click
from fedora_distro_aliases import (
    filter_distro,
    Distro,
    bodhi_active_releases,
    get_distro_aliases,
)
import koji

aliases = get_distro_aliases()
# Workaround the fact that eln is not in the aliases right now
# https://github.com/rpm-software-management/fedora-distro-aliases/issues/30
eln_distro = [
    Distro.from_bodhi_release(release)
    for release in bodhi_active_releases()
    if release["branch"] == "eln"
]
aliases["eln"] = eln_distro

def get_build_macros(build_tag: str):
    session = koji.ClientSession("https://koji.fedoraproject.org/kojihub")
    return session.getBuildConfig(build_tag)


@click.command()
@click.argument("dist-git-branch")
def main(dist_git_branch: str) -> None:
    """
    Get the equivalent previous tag from the distro context
    """
    distro_info = filter_distro(aliases, branch=dist_git_branch)
    if not distro_info:
        click.echo(f"Could not identify distro for branch '{dist_git_branch}'", err=True)
        exit(1)
    # There does not seem to be an easy way to get %{?distro} so we build it manually for each case
    match distro_info.product:
        case "fedora":
            if distro_info.branch == "eln":
                # Special handling for eln since the `%{?distro}` has is not predictable
                try:
                    configs = get_build_macros("eln-build")
                    eln_macro = configs["extra"]["rpm.macro.eln"]
                except Exception:
                    click.echo("Failed to get eln distro tag", err=True)
                    raise
                print(f"eln{eln_macro}")
                print("eln")
            else:
                print(f"fc{distro_info.version}")
                if distro_info.branch == "rawhide":
                    print(f"f{distro_info.version}")
                else:
                    print(f"f{distro_info.version}-updates")
        case "epel":
            epel_version: str = distro_info.version
            print(f"el{epel_version.replace('.','_')}")
            print(f"epel{epel_version}")
        case _:
            click.echo(f"Unrecognized distro.product '{distro_info.product}' of '{dist_git_branch}'", err=True)
            exit(1)


if __name__ == "__main__":
    main()
