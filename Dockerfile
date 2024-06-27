FROM registry.fedoraproject.org/fedora:41
LABEL maintainer "Fedora CI"
LABEL description="rpminspect for Fedora CI"

# https://copr.fedorainfracloud.org/coprs/dcantrell/rpminspect/
ENV RPMINSPECT_PACKAGE_NAME=rpminspect
ENV RPMINSPECT_DATA_PACKAGE_NAME=rpminspect-data-fedora

RUN dnf -y install 'dnf5-command(copr)' && \
    dnf -y copr enable dcantrell/rpminspect && \
    dnf -y copr enable @osci/fedora-license-data

# We enable updates-testing to pull in the latest annobin
RUN dnf install -y --enablerepo=updates-testing \
    ${RPMINSPECT_PACKAGE_NAME} \
    ${RPMINSPECT_DATA_PACKAGE_NAME} \
    "libabigail >= 2.5" \
    "annobin-annocheck >= 12.59" \
    clamav-update \
    python3-pyyaml \
    python3-click \
    python3-retry \
    python3-GitPython \
    koji \
    git \
    jq \
    && dnf clean all

# Update the virus database (we also update it when running the inspection)
RUN freshclam

COPY *.sh *.py /usr/local/bin/
