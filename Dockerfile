FROM registry.fedoraproject.org/fedora:32
LABEL maintainer "Fedora-CI"
LABEL description="rpminspect for fedora-ci"

ENV RPMINSPECT_VERSION=1.2-0.1.202010081406git.fc32
ENV RPMINSPECT_DATA_VERSION=1:1.2-0.1.202010072008git.fc32

ENV RPMINSPECT_WORKDIR=/workdir/
ENV RPMINSPECT_RUNNER_DIR=/rpminspect_runner/
ENV HOME=${RPMINSPECT_WORKDIR}

RUN mkdir -p ${RPMINSPECT_WORKDIR} ${RPMINSPECT_RUNNER_DIR} &&\
    chmod 777 ${RPMINSPECT_WORKDIR} ${RPMINSPECT_RUNNER_DIR}

RUN dnf -y install 'dnf-command(copr)' && \
    dnf -y copr enable dcantrell/rpminspect

RUN dnf -y install \
    rpminspect-${RPMINSPECT_VERSION} \
    rpminspect-data-fedora-${RPMINSPECT_DATA_VERSION} \
    libabigail \
    koji \
    && dnf clean all

COPY . rpminspect_runner.sh ${RPMINSPECT_RUNNER_DIR}

WORKDIR ${RPMINSPECT_WORKDIR}
