FROM debian:bullseye-slim AS percolator-build
ARG DEBIAN_FRONTEND=noninteractive
ARG PERCOLATOR_GIT_URL=https://github.com/percolator/percolator.git
ARG PERCOLATOR_VERSION=3-05
ARG PERCOLATOR_BRANCH="branch-${PERCOLATOR_VERSION}"
ARG SOURCE_DIR=/workspace/source
ARG RELEASE_DIR=/workspace/release
ARG BUILD_DIR=/workspace/build
ARG PERCOLATOR_BUILD_DIR="${BUILD_DIR}/percolator"
ARG CONVERTERS_BUILD_DIR="${BUILD_DIR}/converters"
ARG XERCES_VERSION="3.2.4"
ARG XERCES_URL="https://archive.apache.org/dist/xerces/c/3/sources/xerces-c-${XERCES_VERSION}.tar.gz"
ARG XERCES_BUILD_DIR=${BUILD_DIR}/xerces-c-${XERCES_VERSION}
ARG NUM_BUILD_CORES=20
ARG MAKEFLAGS="-j${NUM_BUILD_CORES}"


RUN apt-get update \
  && apt-get install -y --no-install-recommends --no-install-suggests \
    ca-certificates \
    git \
    cmake \
    wget \
    unzip \
    curl \
    build-essential \
    g++ \
    make \
    rpm \
    fakeroot \
    libxml2-utils \
    libgtest-dev \
    xsdcxx \
    # this needs to have a few compile flags set currently
    # see below
    # libxerces-c-dev \
    libboost-dev \
    libboost-filesystem-dev \
    libboost-system-dev \
    libboost-thread-dev \
    libtokyocabinet-dev \
    zlib1g-dev \
    libbz2-dev \
    python3 \
  && rm -rf /var/lib/apt/lists/*


# installing and building xercesc
# see: https://github.com/percolator/percolator/issues/188
WORKDIR ${BUILD_DIR}
RUN wget --no-check-certificate ${XERCES_URL}
RUN tar xzf "xerces-c-${XERCES_VERSION}".tar.gz
WORKDIR ${XERCES_BUILD_DIR}
RUN ./configure --prefix=${XERCES_BUILD_DIR} --disable-netaccessor-curl --disable-transcoder-icu > ../xercesc_config.log 2>&1
RUN make > ../xercesc_make.log 2>&1
RUN make install > ../xercesc_install.log 2>&1

# cloning percolator repo
WORKDIR ${SOURCE_DIR}
RUN mkdir -p ${RELEASE_DIR} ${BUILD_DIR}
RUN git clone --depth=1 --branch ${PERCOLATOR_BRANCH} ${PERCOLATOR_GIT_URL}

# building percolator with XML support
WORKDIR ${PERCOLATOR_BUILD_DIR}
RUN cmake \
    -DTARGET_ARCH=amd64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_PREFIX_PATH="${XERCES_BUILD_DIR}" \
    -DXML_SUPPORT=ON \
    -DGOOGLE_TEST=1 \
    ${SOURCE_DIR}/percolator
RUN make
RUN make package

# copying release files
RUN cp ${PERCOLATOR_BUILD_DIR}/*.deb ${RELEASE_DIR}

# testing percolator
RUN ln -s /usr/bin/python3 /usr/bin/python
RUN make install
RUN make test
# only available in 3-06?
# RUN make test-install

LABEL org.opencontainers.image.source https://github.com/radusuciu/docker-percolator
