# rpminspect-image development

## How to update rpminspect and/or the data package

There are two variables in the [Dockerfile](./Dockerfile) that control which version of `rpminspect`/`data package` is installed inside the container image:

```shell
# https://copr.fedorainfracloud.org/coprs/dcantrell/rpminspect/
ENV RPMINSPECT_VERSION=1.5-0.1.202104092118git.fc33
ENV RPMINSPECT_DATA_VERSION=1:1.4-0.1.202103081853git.fc33
```

In order to upgrade/downgrade either the `rpminspect` itself, or the `data package`, all you need to do is to update the corresponding version in the Dockerfile.

See the next section for information on what happens when you merge your changes to the master branch.


## rpminspect-image CI/CD

Push to the master branch triggers a new image build in [Quay.io](https://quay.io/repository/fedoraci/rpminspect). Once the build is finished, you can pull the image from the registry (replace the image tag):

```
$ podman pull quay.io/fedoraci/rpminspect:abf4880
```

The tag is always the first 7 letters of the commit hash (`git rev-parse --short HEAD`). However, the image is also tagged as `:latest`, for convenience.


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
