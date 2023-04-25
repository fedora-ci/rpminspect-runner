# rpminspect container image

This repository contains bits needed to build a container image for [rpminspect](https://github.com/rpminspect/rpminspect). This image can be later used by Fedora CI. There is also a version for CentOS Stream.


## Example usage

`rpminspect_runner.sh` takes three parameters: `<task-id>` `<koji-tag-with-previous-build>` `<inspection-name>`

```shell
$ podman run -ti --rm quay.io/fedoraci/rpminspect /bin/bash
(inside container) $ rpminspect_runner.sh 60499294 f35-updates license
```

`rpminspect_zuul_runner.sh` requires at least 2 parameters: `<zuul-repo>` and `<test-name>`.
See `rpminspect_zuul_runner.sh --help`.

```shell
$ podman run -ti --rm quay.io/fedoraci/rpminspect-stream /bin/bash
(inside container) $ rpminspect_zuul_runner.sh -r "https://centos.softwarefactory-project.io/logs/11/11/9e75bb0c73d34f33b216e278645cb648efc4b929/check/mock-build/d39b3e8/repo/" -t arch
```


## Development

Looking for information on how to make changes to the container image? Take a look [here](./docs/development.md)!

