# rpminspect-image development

## How to update rpminspect

The runner script tries to update rpminspect (and data package) to the latest version every time it runs.


## How to build and run the container image locally


Build the image using podman:
```shell
$ podman build -t quay.io/fedoraci/rpminspect:devel .
```

You can also force-update base image and dependencies with `--pull` and `--no-cache` options:
```shell
$ podman build --pull --no-cache -t quay.io/fedoraci/rpminspect:devel .
```

Run the image:
```shell
$ podman run -ti --rm quay.io/fedoraci/rpminspect:devel /bin/bash

# inside the container:
# test rpminspect directly
$ rpminspect-fedora -T license gnome-chess-42.0-1.fc37
...
# test rpminspect via CI wrapper script
$ rpminspect_runner.sh 84688996 f37-updates license
...
```


## rpminspect-image CI/CD

Push to the master branch triggers a new image build in [Quay.io](https://quay.io/repository/fedoraci/rpminspect). Once the build is finished, you can pull the image from the registry (replace the image tag):

```
$ podman pull quay.io/fedoraci/rpminspect:329dd1f
```

The tag is always the first 7 letters of the commit hash (`git rev-parse --short HEAD`). However, the image is also tagged as `:latest`, for convenience.

### How to push to Quay.io manually

If Quay.io fails to build the image (infra/network errors...), it is possible to build it on a laptop and push it to the registry manually.

Only owners of the [`fedoraci` namespace](https://quay.io/organization/fedoraci/teams/owners) can push images manually.

Build the image using podman:
```shell
$ podman build --pull --no-cache -t quay.io/fedoraci/rpminspect:$(git rev-parse --short HEAD) .
```

Create a new [robot account](https://quay.io/repository/fedoraci/rpminspect?tab=settings), then click on the account name and select the "Docker Login" tab. Copy the login command and replace "docker" with "podman".

Push the image:
```shell
podman push quay.io/fedoraci/rpminspect:$(git rev-parse --short HEAD)
```


## Promote new image to production

Update image tag in [rpminspect.fmf](https://github.com/fedora-ci/rpminspect-pipeline/blob/master/rpminspect.fmf).


### Test the image end-to-end in CI

Opening a pull-request in [fedora-ci/rpminspect-pipeline](https://github.com/fedora-ci/rpminspect-pipeline) repository will automatically create a test pipeline in [Fedora CI Jenkins](https://osci-jenkins-1.ci.fedoraproject.org/job/fedora-ci/job/rpminspect-pipeline/view/change-requests/). This pipeline contains changes from the pull-request, so it is possible to update the image reference in the [rpminspect.fmf](https://github.com/fedora-ci/rpminspect-pipeline/blob/master/rpminspect.fmf) file and then test the whole pipeline end-to-end in Jenkins.
