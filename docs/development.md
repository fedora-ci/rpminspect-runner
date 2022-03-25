# rpminspect-image development

## How to update rpminspect

There is a variable in the [Dockerfile](./Dockerfile) that controls which version of `rpminspect` is installed inside the container image:

```shell
# https://copr.fedorainfracloud.org/coprs/dcantrell/rpminspect/
ENV RPMINSPECT_VERSION=1.10-0.1.202203231925git.fc37
```

In order to upgrade/downgrade `rpminspect`, all you need to do is to update the corresponding version in the Dockerfile.

See the next section for information on what happens when you merge your changes to the master branch.


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


## How to regenerate the list of inspections for TMT

If you're running `rpminspect` via TMT (Fedora CI [does](https://github.com/fedora-ci/rpminspect-pipeline/blob/master/rpminspect.fmf)), then you may want to occasionally update the list of inspections that TMT should run. This should typically be done when `rpminspect` is being updated to a new (major?) version.

This is how the list can be regenerated:

```shell
$ podman run quay.io/fedoraci/rpminspect:latest generate_tmt.sh
    - name: license
      framework: shell
      test: /usr/local/bin/rpminspect_runner.sh $TASK_ID $PREVIOUS_TAG license
      duration: 20m
    - name: emptyrpm
      framework: shell
      test: /usr/local/bin/rpminspect_runner.sh $TASK_ID $PREVIOUS_TAG emptyrpm
      duration: 20m
... <snip> ...
```

Note the assumption here is that the container image with the new rpminspect is already built and available in the registry (or locally, on your laptop).

Once you have the list of inspections, you can update the TMT definition file (`.fmf`). For Fedora CI, the TMT file can be found [here](https://github.com/fedora-ci/rpminspect-pipeline/blob/master/rpminspect.fmf).
