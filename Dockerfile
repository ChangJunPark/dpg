FROM ubuntu:16.04 AS updated
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get upgrade -qq

FROM updated as build
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq
RUN apt-get install -y  \
  build-essential \
  cmake \
  git \
  graphviz \
  libatlas-base-dev \
  libboost-filesystem-dev \
  libboost-iostreams-dev \
  libboost-program-options-dev \
  libboost-regex-dev \
  libboost-serialization-dev \
  libboost-system-dev \
  libboost-test-dev \
  libboost-graph-dev \
  libcgal-dev \
  libcgal-qt5-dev \
  libfreeimage-dev \
  libgflags-dev \
  libglew-dev \
  libglu1-mesa-dev \
  libgoogle-glog-dev \
  libjpeg-dev \
  libopencv-dev \
  libpng-dev \
  libqt5opengl5-dev \
  libsuitesparse-dev \
  libtiff-dev \
  libxi-dev \
  libxrandr-dev \
  libxxf86vm-dev \
  libxxf86vm1 \
  mediainfo \
  mercurial \
  qtbase5-dev \
  libatlas-base-dev \
  libsuitesparse-dev

WORKDIR /tmp/build

# Install openmvg
RUN git clone -b develop --recursive https://github.com/openMVG/openMVG.git openmvg && \
  mkdir openmvg_build && cd openmvg_build && \
  cmake -DCMAKE_BUILD_TYPE=RELEASE . ../openmvg/src -DCMAKE_INSTALL_PREFIX=/opt/openmvg && \
  make -j4  && \
  make install

# Install eigen
RUN hg clone https://bitbucket.org/eigen/eigen#3.2 eigen && \
  mkdir eigen_build && cd eigen_build && \
  cmake . ../eigen && \
  make -j4 && \
  make install 

# Get vcglib
RUN git clone https://github.com/cdcseacave/VCG.git vcglib 

# Install ceres solver
RUN git clone https://ceres-solver.googlesource.com/ceres-solver ceres_solver && \
  cd ceres_solver && git checkout tags/1.14.0 && cd .. && \
  mkdir ceres_build && cd ceres_build && \
  cmake . ../ceres_solver/ -DMINIGLOG=OFF -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF && \
  make -j4 && \
  make install

# Install openmvs
RUN git clone https://github.com/cdcseacave/openMVS.git openmvs && \
  mkdir openmvs_build && cd openmvs_build && \
  cmake . ../openmvs -DCMAKE_BUILD_TYPE=Release -DVCG_DIR="../vcglib" -DCMAKE_INSTALL_PREFIX=/opt/openmvs && \
  make -j4 && \
  make install

# Install cmvs-pmvs
RUN git clone https://github.com/pmoulon/CMVS-PMVS /tmp/build/cmvs-pmvs && \
  mkdir /tmp/build/cmvs-pmvs_build && cd /tmp/build/cmvs-pmvs_build && \
  cmake ../cmvs-pmvs/program -DCMAKE_INSTALL_PREFIX=/opt/cmvs && \
  make -j4 && \
  make install

# Install colmap
RUN git clone -b master https://github.com/colmap/colmap /tmp/build/colmap && \
  mkdir -p /tmp/build/colmap_build && cd /tmp/build/colmap_build && \
  cmake . ../colmap -DCMAKE_INSTALL_PREFIX=/opt/colmap && \
  make -j4 && \
  make install

# ..and then create a more lightweight image to actually run stuff in.
FROM updated
ENV DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000
RUN apt-get update && apt-get install -y \
  curl \
  exiftool \
  ffmpeg \
  mediainfo \
  graphviz \
  libpng12-0 \
  libjpeg-turbo8 \
  libtiff5 \
  libxxf86vm1 \
  libxi6 \
  libxrandr2 \
  libatlas-base-dev \
  libqt5widgets5 \
  libboost-iostreams1.58.0 \
  libboost-program-options1.58.0 \
  libboost-serialization1.58.0 \
  libopencv-calib3d2.4v5 \
  libopencv-highgui2.4v5 \
  libgoogle-glog0v5 \
  libfreeimage3 \
  libcgal11v5 \
  libglew1.13 \
  libcholmod3.0.6 \
  libcxsparse3.1.4 \
  python-minimal
COPY --from=build /opt /opt
COPY pipeline.py /opt/dpg/pipeline.py
RUN echo ubuntu soft core unlimited >> /etc/security/limits.conf
RUN echo ubuntu hard core unlimited >> /etc/security/limits.conf
RUN groupadd -g $GID ptools
RUN useradd -r -u $UID -m -g ptools ptools
WORKDIR /
USER ptools
ENV PATH=/opt/openmvs/bin/OpenMVS:/opt/openmvg/bin:/opt/cmvs/bin:/opt/colmap/bin:/opt/dpg:$PATH
