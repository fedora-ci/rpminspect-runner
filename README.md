# rpminspect container image

This repository contains bits needed to build a container image for [rpminspect](https://github.com/rpminspect/rpminspect). This image can be later used by Fedora CI.

## Example usage

`rpminspect_runner.sh` takes three parameters: `<task-id>` `<koji-tag-with-previous-build>` `<inspection-name>`

```shell
$ podman run -ti --rm quay.io/fedoraci/rpminspect /bin/bash
(inside container) $ rpminspect_runner.sh 60499294 f35-updates license
```

## Development

Looking for information on how to make changes to the container image? Take a look [here](./docs/development.md)!
