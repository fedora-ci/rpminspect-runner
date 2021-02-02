# rpminspect container image

This repository contains bits needed to build a container image for [rpminspect](https://github.com/rpminspect/rpminspect). This image can be later used by Fedora CI.


# Example usage

`rpminspect_runner.sh` has three parameters: \<task-id> \<koji-tag-with-previous-build> [ \<inspection-name> ]

```shell
podman run -ti --rm quay.io/fedoraci/rpminspect rpminspect_runner.sh 49176420 f34-updates
```
