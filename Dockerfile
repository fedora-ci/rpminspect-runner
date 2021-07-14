FROM registry.fedoraproject.org/fedora:34
LABEL maintainer "Fedora-CI"
LABEL description="rpminspect for fedora-ci"

# https://copr.fedorainfracloud.org/coprs/dcantrell/rpminspect/
ENV RPMINSPECT_VERSION=1.6-0.1.202107121853git.fc34
ENV RPMINSPECT_DATA_VERSION=1:1.5-0.1.202106151642git.fc34

ENV RPMINSPECT_WORKDIR=/workdir/
ENV HOME=${RPMINSPECT_WORKDIR}

RUN mkdir -p ${RPMINSPECT_WORKDIR} &&\
    chmod 777 ${RPMINSPECT_WORKDIR}

RUN dnf -y install 'dnf-command(copr)' && \
    dnf -y copr enable dcantrell/rpminspect

# We enable updates-testing to pull in the latest annobin
RUN dnf install -y --enablerepo=updates-testing \
    rpminspect-${RPMINSPECT_VERSION} \
    rpminspect-data-fedora-${RPMINSPECT_DATA_VERSION} \
    libabigail \
    clamav-update \
    python3-pyyaml \
    koji \
    git \
    && dnf clean all

COPY *.sh rpminspect_json2text.py /usr/local/bin/

WORKDIR ${RPMINSPECT_WORKDIR}
