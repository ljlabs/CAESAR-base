FROM everpeace/kube-openmpi:0.7.0

# Variables
ENV SOURCE_BASE_DIR /scratch
ENV INSTALL_BASE_DIR /opt

ENV SOURCE_OPENCV_DIR ${SOURCE_BASE_DIR}/opencv
ENV OPENCV_DIR ${INSTALL_BASE_DIR}/OpenCV

ENV SOURCE_CMAKE_DIR ${SOURCE_BASE_DIR}/cmake
ENV INSTALL_CMAKE_DIR ${INSTALL_BASE_DIR}/cmake

# install dependencies

ENV TZ Africa/Johannesburg
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN echo "deb http://security.ubuntu.com/ubuntu xenial-security main" | tee -a /etc/apt/sources.list
RUN apt update

RUN apt-get install build-essential git pkg-config \
    libavcodec-dev libavformat-dev libswscale-dev libv4l-dev \
    libxvidcore-dev libx264-dev libjpeg-dev libtiff-dev \
    gfortran openexr libatlas-base-dev python3-dev python3-numpy \
    libtbb2 libtbb-dev libdc1394-22-dev libgtk2.0-dev python-dev \
    python-numpy libjasper-dev libjasper1 libgsl-dev libxpm-dev \
    libcfitsio-dev r-base r-base-dev libssl-dev g++ make wget libcurl4-openssl-dev \
    libx11-dev libxft-dev libxext-dev libpng-dev libjpeg-dev \
    libavcodec-dev libavformat-dev libswscale-dev libcfitsio-bin gcc-4.8 \
    g++-4.8 libc++-dev -yqq


# install CMAKE
# NB: Required >3.8 by jsoncpp
ENV CMAKE_VERSION="3.16.4"
ENV CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz"
ENV CMAKE_SRC_DIR="${SOURCE_BASE_DIR}/cmake/cmake-${CMAKE_VERSION}"
ENV CMAKE_INSTALL_DIR="${INSTALL_BASE_DIR}/cmake/v${CMAKE_VERSION}"

# Create install dir
RUN mkdir -p ${SOURCE_CMAKE_DIR} && mkdir -p ${INSTALL_CMAKE_DIR}

# Download tar file
RUN cd ${SOURCE_CMAKE_DIR} && wget ${CMAKE_URL}

# Untar file
RUN cd ${SOURCE_CMAKE_DIR} && tar xzvf ${SOURCE_CMAKE_DIR}/cmake-${CMAKE_VERSION}.tar.gz

# Configure, build and install
RUN cd ${CMAKE_SRC_DIR} && ./bootstrap --prefix=${CMAKE_INSTALL_DIR} && \
    make -j10 && \
    make install

# Set env var
ENV CMAKE_RECENT=${CMAKE_INSTALL_DIR}/bin/cmake

## Clear source & build dir
RUN rm -rf ${CMAKE_SRC_DIR}

# install opencv
RUN mkdir $SOURCE_OPENCV_DIR && cd $SOURCE_OPENCV_DIR
RUN cd ${SOURCE_OPENCV_DIR} &&  git clone https://github.com/opencv/opencv.git
 RUN cd ${SOURCE_OPENCV_DIR} && git clone https://github.com/opencv/opencv_contrib.git

RUN cd ${SOURCE_OPENCV_DIR}/opencv && git tag && git checkout 3.4.10
RUN cd ${SOURCE_OPENCV_DIR}/opencv_contrib && git tag && git checkout 3.4.10

RUN cd ${SOURCE_OPENCV_DIR}/opencv && mkdir build && cd build && \
    ${CMAKE_RECENT} -D CMAKE_BUILD_TYPE=RELEASE \
        -D CMAKE_INSTALL_PREFIX=$OPENCV_DIR \
         -DOPENCV_EXTRA_MODULES_PATH=${SOURCE_OPENCV_DIR}/opencv_contrib/modules \
        .. && \
        make -j10 && make install


# Setting environment variables
ENV PATH=${PATH}:${OPENCV_DIR}/bin
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${OPENCV_DIR}/lib
ENV PKG_CONFIG_PATH=${PKG_CONFIG_PATH}:${OPENCV_DIR}/lib/pkgconfig

#clean up
RUN rm -rf $SOURCE_OPENCV_DIR

# install boost
RUN apt-get install libboost-all-dev -yqq

# install protobuf
RUN apt-get install libprotobuf-dev protobuf-compiler -yqq

# install jsoncpp
RUN apt-get install libjsoncpp-dev -yqq

# install log4cxx
RUN apt-get install liblog4cxx-dev -yqq

# install root
ENV SOURCE_ROOT_DIR ${SOURCE_BASE_DIR}/root
ENV ROOTSYS ${INSTALL_BASE_DIR}/root

RUN mkdir ${ROOTSYS} && mkdir ${SOURCE_ROOT_DIR}

RUN cd ${SOURCE_ROOT_DIR} &&  git clone https://github.com/root-project/root
RUN cd ${SOURCE_ROOT_DIR}/root && git tag && git checkout v5-99-06

RUN R -e "install.packages('Rcpp',dependencies=TRUE, repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('RInside',dependencies=TRUE, repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('C50',dependencies=TRUE, repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('RSNNS',dependencies=TRUE, repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('e1071',dependencies=TRUE, repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('xgboost',dependencies=TRUE, repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('rrcovHD',dependencies=TRUE, repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('truncnorm',dependencies=TRUE, repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('FNN',dependencies=TRUE, repos='http://cran.rstudio.com/')" && \
    R -e "install.packages('akima',dependencies=TRUE, repos='http://cran.rstudio.com/')"

ENV LD_LIBRARY_PATH /usr/local/lib/R/site-library/RInside/lib:$LD_LIBRARY_PATH

RUN cd ${SOURCE_ROOT_DIR}/root && git tag && git checkout v6-14-08

RUN mkdir ${SOURCE_ROOT_DIR}/build && \
    cd ${SOURCE_ROOT_DIR}/build && \
    ${CMAKE_RECENT} -D CMAKE_INSTALL_PREFIX=${ROOTSYS} \
    -D CMAKE_BUILD_TYPE=Release \
    -D fitsio=ON \
    -D gsl_shared=ON \
    -D mathmore=ON \
    -D minuit2=ON \
    -D roofit=ON \
    -D shared=ON \
    -D soversion=ON \
    -D tmva=ON \
    -D unuran=ON \
    -D x11=ON \
    -D xft=ON \
    -D pyroot=ON\
    -D r=ON \
    -D builtin_xrootd=ON \
    ${SOURCE_ROOT_DIR}/root && \
    make && \
    make install

RUN cp -r ${SOURCE_ROOT_DIR}/root/etc/cmake ${ROOTSYS}/etc
RUN rm -rf ${SOURCE_ROOT_DIR}

ENV PATH=$PATH:$ROOTSYS/bin:$PYTHONDIR/lib
ENV LD_LIBRARY_PATH $ROOTSYS/lib:$PYTHONDIR/lib:$LD_LIBRARY_PATH
ENV PYTHONPATH $ROOTSYS/lib:$PYTHONPATH

# JSONCPP

# Set env variables and create installation dirs
ENV JSONCPP_URL="https://github.com/open-source-parsers/jsoncpp.git"
ENV JSONCPP_SRC_DIR="${SOURCE_BASE_DIR}/jsoncpp"
ENV JSONCPP_BUILD_DIR="${SOURCE_BASE_DIR}/jsoncpp-build"
ENV JSONCPP_INSTALL_DIR="${INSTALL_BASE_DIR}/jsoncpp"

RUN mkdir -p ${JSONCPP_BUILD_DIR} && \
	mkdir -p ${JSONCPP_INSTALL_DIR}

RUN cd ${SOURCE_BASE_DIR} && git clone ${JSONCPP_URL}

RUN cd ${JSONCPP_BUILD_DIR} && ${CMAKE_RECENT} -DCMAKE_INSTALL_PREFIX=${JSONCPP_INSTALL_DIR} -DBUILD_SHARED_LIBS=ON -DJSONCPP_WITH_PKGCONFIG_SUPPORT=ON ${JSONCPP_SRC_DIR} \
  && make -j10 \
  && make install

RUN rm -rf $JSONCPP_SRC_DIR

# Set env vars
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${JSONCPP_INSTALL_DIR}/lib
ENV PKG_CONFIG_PATH=${PKG_CONFIG_PATH}:${JSONCPP_INSTALL_DIR}/lib/pkgconfig

ENV JSONCPP_ROOT ${JSONCPP_INSTALL_DIR}
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$JSONCPP_ROOT/lib
ENV PKG_CONFIG_PATH $PKG_CONFIG_PATH:$JSONCPP_ROOT/lib/pkgconfig

## Clear source & build dir
RUN rm -rf ${JSONCPP_SRC_DIR} \
	&& rm -rf ${JSONCPP_BUILD_DIR}


# install CASA NRAO
ENV CASA_VERSION="5.1.1"
ENV CASA_VERSION_MINOR="5"
ENV CASA_URL="https://casa.nrao.edu/download/distro/linux/release/el7/casa-release-${CASA_VERSION}-${CASA_VERSION_MINOR}"'.el7.tar.gz'
ENV CASA_UNTAR_DIR="casa-release-$CASA_VERSION-$CASA_VERSION_MINOR.el7"
ENV CASA_BASE_DIR="${SOURCE_BASE_DIR}/CASA"
ENV CASA_INSTALL_DIR="${CASA_BASE_DIR}/v${CASA_VERSION}"
ENV CASASRC="${CASA_BASE_DIR}/.casa"
ENV CASA_LOGON_FILE="${CASASRC}/init.py"
ENV CASALD_LIBRARY_PATH="${LD_LIBRARY_PATH}"

RUN mkdir -p ${CASA_BASE_DIR} \
	&& mkdir -p ${CASASRC} \
	&& chmod -R a+rwx ${CASASRC}

# Download & install CASA
RUN cd $CASA_BASE_DIR && wget -nc -O casa${CASA_VERSION}.tar.gz ${CASA_URL}

RUN cd ${CASA_BASE_DIR} && tar -xzvf $CASA_BASE_DIR/casa${CASA_VERSION}.tar.gz && \
    mv ${CASA_UNTAR_DIR} v${CASA_VERSION}


# Setting environment variables
# NB: Do not add CASA python lib dir to PYTHONPATH because it will screw up python (changes site.py with CASA site.py)
# NB: Never ever put CASA stuff paths before your system path!!!
# NB: Define CASALD_LIBRARY_PATH and set it to LD_LIBRARY_PATH because casa startup script has a nasty statement that removes your LD_LIBRARY_PATH (yes, CASA sucks)!!!
ENV PATH=${PATH}:${CASA_INSTALL_DIR}/bin

ENV CASAPATH ${CASA_INSTALL_DIR}
ENV CASA_DIR ${CASA_INSTALL_DIR}
ENV CASASRC ${CASASRC}
ENV PATH $PATH:$CASA_DIR/bin
ENV CASALD_LIBRARY_PATH $LD_LIBRARY_PATH

# Create logon file under $CASASRC dir
RUN echo 'import sys' > ${CASA_LOGON_FILE}
RUN echo "sys.path = [''] + sys.path" >> ${CASA_LOGON_FILE}

# Clear CASA tar
RUN rm -rf ${SOFTDIR_TAR}/casa${CASA_VERSION}.tar.gz


RUN echo "export LD_LIBRARY_PATH=/usr/local/lib/R/site-library/RInside/lib:/opt/root/lib:/lib:/opt/OpenCV/lib:/opt/jsoncpp/lib:/opt/jsoncpp/lib" >> /root/.bashrc && \
    echo "export LD_LIBRARY_PATH=/usr/local/lib/R/site-library/RInside/lib:/opt/root/lib:/lib:/opt/OpenCV/lib:/opt/jsoncpp/lib:/opt/jsoncpp/lib" >> /home/openmpi/.bashrc

COPY hostGenerator.sh /kube-openmpi/utils/hostGenerator.sh
COPY init.sh /init.sh
