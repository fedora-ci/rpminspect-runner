#!/usr/bin/python3

"""Get the source URL and commit hash for the given build NVR or task ID."""

import click
import koji
import json
import os


KOJI_HUB_URL = os.environ.get("KOJI_HUB_URL", "https://koji.fedoraproject.org/kojihub")

koji_client = koji.ClientSession(KOJI_HUB_URL)


def original_url_to_json(original_url: str) -> dict:
    """Convert the original URL ("git+https://repo.git#commit") to a JSON object."""
    if original_url.startswith("git+"):
        original_url = original_url[4:]
    return {
        "source_url": original_url.split('#')[0],
        "commit": original_url.split('#')[1]
    }


def get_original_url_from_build_nvr(build_nvr: str) -> str:
    """Get the original URL for the given build NVR."""
    build_info = koji_client.getBuild(build_nvr)
    return build_info.get("extra", {}).get("source", {}).get("original_url", "")


def get_original_url_from_task_id(task_id: str) -> str:
    """Get the original URL for the given task ID."""
    task_info = koji_client.getTaskInfo(task_id, request=True)
    task_request = task_info.get("request", [])

    # This is probably a regular or scratch task ID
    if task_request and isinstance(task_request[0], str):
        return task_request[0]

    # This is probably a Konflux task ID
    builds = koji_client.listBuilds(taskID=task_id)
    if not builds:
        return None

    return builds[0].get("extra", {}).get("source", {}).get("original_url", "")


@click.command()
@click.argument("build-or-task-id")
def main(build_or_task_id: str) -> None:
    if build_or_task_id.isdigit():
        # This is a task ID
        original_url = get_original_url_from_task_id(build_or_task_id)
        result_json = original_url_to_json(original_url)
    else:
        # This is a build NVR
        original_url = get_original_url_from_build_nvr(build_or_task_id)
        result_json = original_url_to_json(original_url)
    print(json.dumps(result_json, indent=4))


if __name__ == "__main__":
    main()
