FROM registry.fedoraproject.org/fedora:33
LABEL maintainer "Fedora-CI"
LABEL description="rpminspect for fedora-ci"

ENV RPMINSPECT_VERSION=1.1-0.1.202009022120git.fc33
ENV RPMINSPECT_DATA_VERSION=1.1-0.1.202009041630git.fc33

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
    koji \
    && dnf clean all

COPY . rpminspect_runner.sh ${RPMINSPECT_RUNNER_DIR}

WORKDIR ${RPMINSPECT_WORKDIR}
