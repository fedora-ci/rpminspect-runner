FROM registry.fedoraproject.org/fedora:32
LABEL maintainer "Fedora-CI"
LABEL description="rpminspect for fedora-ci"

ENV RPMINSPECT_VERSION=1.2-0.1.202010151343git.fc32
ENV RPMINSPECT_DATA_VERSION=1:1.2-0.1.202010121348git.fc32

ENV RPMINSPECT_WORKDIR=/workdir/
ENV HOME=${RPMINSPECT_WORKDIR}

RUN mkdir -p ${RPMINSPECT_WORKDIR} &&\
    chmod 777 ${RPMINSPECT_WORKDIR}

RUN dnf -y install 'dnf-command(copr)' && \
    dnf -y copr enable dcantrell/rpminspect

RUN dnf -y install \
    rpminspect-${RPMINSPECT_VERSION} \
    rpminspect-data-fedora-${RPMINSPECT_DATA_VERSION} \
    libabigail \
    koji \
    && dnf clean all

COPY rpminspect_runner.sh /usr/local/bin/rpminspect_runner

WORKDIR ${RPMINSPECT_WORKDIR}
