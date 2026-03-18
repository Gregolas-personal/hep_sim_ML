FROM ubuntu:24.04

ARG TARGETPLATFORM
ARG TARGETARCH
ARG ROOT_BUILD_JOBS=4

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

ENV ROOT_VERSION=6.36.06
ENV ROOT_BINARY_TARBALL=root_v6.36.06.Linux-ubuntu24.04-x86_64-gcc13.3.tar.gz
ENV ROOT_SOURCE_TARBALL=root_v6.36.06.source.tar.gz
ENV PYTHIA_VERSION=8317
ENV PYTHIA_TARBALL=pythia8317.tgz
ENV DELPHES_VERSION=3.5.1
ENV HEPMC3_VERSION=3.3.1
ENV MADGRAPH_VERSION=3.5.13
ENV MADGRAPH_TARBALL=MG5_aMC_v3.5.13.tar.gz
ENV MADGRAPH_SERIES=3.6.x

RUN apt-get update && apt-get install -y --no-install-recommends \
    binutils \
    cmake \
    dpkg-dev \
    g++ \
    gcc \
    gfortran \
    git \
    ninja-build \
    rsync \
    wget \
    curl \
    ca-certificates \
    make \
    patch \
    xz-utils \
    pkg-config \
    python3 \
    python3-pip \
    python3-dev \
    python3-numpy \
    libssl-dev \
    libx11-dev \
    libxext-dev \
    libxft-dev \
    libxrender-dev \
    libxpm-dev \
    libtbb-dev \
    libvdt-dev \
    libgif-dev \
    libpcre3-dev \
    libglu1-mesa-dev \
    libglew-dev \
    libftgl-dev \
    libfftw3-dev \
    libcfitsio-dev \
    libgraphviz-dev \
    libavahi-compat-libdnssd-dev \
    libldap2-dev \
    libxml2-dev \
    libkrb5-dev \
    libgsl-dev \
    nlohmann-json3-dev \
    libmysqlclient-dev \
    libgl2ps-dev \
    liblzma-dev \
    libxxhash-dev \
    liblz4-dev \
    libzstd-dev \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libbz2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN set -euxo pipefail; \
    if [[ "${TARGETARCH}" == "amd64" ]]; then \
      echo "Installing prebuilt ROOT for ${TARGETPLATFORM}"; \
      curl -fsSL -O https://root.cern/download/${ROOT_BINARY_TARBALL} && \
      tar -xzf ${ROOT_BINARY_TARBALL} && \
      rm -f ${ROOT_BINARY_TARBALL}; \
    elif [[ "${TARGETARCH}" == "arm64" ]]; then \
      echo "Building ROOT from source for ${TARGETPLATFORM}"; \
      curl -fsSL -O https://root.cern/download/${ROOT_SOURCE_TARBALL} && \
      mkdir -p /opt/root-src && \
      tar -xzf ${ROOT_SOURCE_TARBALL} --strip-components=1 -C /opt/root-src && \
      cmake -S /opt/root-src -B /opt/root-build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/root \
        -Dgnuinstall=ON \
        -Ddavix=OFF \
        -Dfftw3=ON \
        -Dgdml=OFF \
        -Dhttp=OFF \
        -Dpyroot=OFF \
        -Droot7=OFF \
        -Droofit=OFF \
        -Dtmva=OFF \
        -Dtpython=OFF \
        -Dtestsupport=OFF \
        -Dtesting=OFF \
        -Dxrootd=OFF && \
      cmake --build /opt/root-build --parallel "${ROOT_BUILD_JOBS}" && \
      cmake --install /opt/root-build && \
      rm -rf /opt/${ROOT_SOURCE_TARBALL} /opt/root-src /opt/root-build; \
    else \
      echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; \
      exit 1; \
    fi

ENV ROOTSYS=/opt/root
ENV PATH=${ROOTSYS}/bin:${PATH}
ENV LD_LIBRARY_PATH=${ROOTSYS}/lib:${LD_LIBRARY_PATH}
ENV PYTHONPATH=${ROOTSYS}/lib:${PYTHONPATH}

WORKDIR /opt
RUN wget -q https://gitlab.cern.ch/hepmc/HepMC3/-/archive/${HEPMC3_VERSION}/HepMC3-${HEPMC3_VERSION}.tar.gz && \
    tar -xzf HepMC3-${HEPMC3_VERSION}.tar.gz && \
    mkdir -p /opt/HepMC3-${HEPMC3_VERSION}/build && \
    cd /opt/HepMC3-${HEPMC3_VERSION}/build && \
    cmake .. \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DHEPMC3_ENABLE_ROOTIO=OFF \
      -DHEPMC3_ENABLE_PROTOBUFIO=OFF \
      -DHEPMC3_ENABLE_TEST=OFF && \
    make -j"$(nproc)" && \
    make install && \
    cd /opt && rm -f HepMC3-${HEPMC3_VERSION}.tar.gz

WORKDIR /opt
RUN wget -q https://pythia.org/download/pythia83/${PYTHIA_TARBALL} && \
    tar -xzf ${PYTHIA_TARBALL} && \
    cd pythia${PYTHIA_VERSION} && \
    ./configure --prefix=/usr/local --with-hepmc3=/usr/local && \
    make -j"$(nproc)" && \
    make install && \
    cd /opt && rm -f ${PYTHIA_TARBALL}

ENV PYTHIA8=/usr/local
ENV PATH=/usr/local/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH}

WORKDIR /opt
RUN wget -q https://github.com/delphes/delphes/archive/refs/tags/${DELPHES_VERSION}.tar.gz -O delphes-${DELPHES_VERSION}.tar.gz && \
    tar -xzf delphes-${DELPHES_VERSION}.tar.gz && \
    mv delphes-${DELPHES_VERSION} Delphes && \
    cd Delphes && \
    make -j"$(nproc)" && \
    rm -f /opt/delphes-${DELPHES_VERSION}.tar.gz

ENV DELPHES_DIR=/opt/Delphes
ENV PATH=${DELPHES_DIR}:${PATH}
ENV LD_LIBRARY_PATH=${DELPHES_DIR}:${LD_LIBRARY_PATH}

WORKDIR /opt
RUN curl -fsSL -o ${MADGRAPH_TARBALL} https://launchpad.net/mg5amcnlo/3.0/${MADGRAPH_SERIES}/+download/${MADGRAPH_TARBALL} && \
    MG_DIR="$(tar -tzf ${MADGRAPH_TARBALL} | head -n 1 | cut -d/ -f1)" && \
    tar -xzf ${MADGRAPH_TARBALL} && \
    mv "${MG_DIR}" MG5_aMC && \
    rm -f ${MADGRAPH_TARBALL}

ENV MADGRAPH_DIR=/opt/MG5_aMC
ENV PATH=${MADGRAPH_DIR}/bin:${PATH}

RUN pip3 install --break-system-packages --no-cache-dir uproot awkward vector pandas pyarrow

WORKDIR /workspace
COPY pythia_to_hepmc3.cc /workspace/
COPY run_madgraph.sh /workspace/
COPY run_sim.sh /workspace/
COPY PYTHIA_cards /workspace/PYTHIA_cards
COPY MG_cards /workspace/MG_cards
COPY cards /workspace/cards

RUN chmod +x /workspace/run_sim.sh /workspace/run_madgraph.sh && \
    g++ -O3 -std=c++17 /workspace/pythia_to_hepmc3.cc \
      -o /workspace/pythia_to_hepmc3 \
      -I/usr/local/include \
      -I/usr/local/include/Pythia8 \
      -L/usr/local/lib -lpythia8 -lHepMC3

CMD ["/bin/bash"]
