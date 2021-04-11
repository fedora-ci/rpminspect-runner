# How to update rpminspect and/or the data package

There are two variables in the [Dockerfile](./Dockerfile) that control which version of `rpminspect`/`data package` is installed inside the container image:

```shell
# https://copr.fedorainfracloud.org/coprs/dcantrell/rpminspect/
ENV RPMINSPECT_VERSION=1.5-0.1.202104092118git.fc33
ENV RPMINSPECT_DATA_VERSION=1:1.4-0.1.202103081853git.fc33
```

In order to upgrade/downgrade either the `rpminspect` itself, or the `data package`, all you need to do is to update the corresponding version in the Dockerfile.

See the next section for information on what happens when you merge your changes to the master branch.


# rpminspect-image CI/CD

Push to the master branch triggers new image build in [Quay.io](https://quay.io/repository/fedoraci/rpminspect). Once the build is finished, you can pull the image from the registry:

```
podman pull quay.io/fedoraci/rpminspect:3d81480
```

The tag is always the first 7 letters of the commit hash. However, the image also has the `:latest` tag for convenience.
