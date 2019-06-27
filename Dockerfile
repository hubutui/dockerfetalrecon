# Set up a docker image for fetalReconstruction
# https://github.com/bkainz/fetalReconstruction
#
# Jeff Stout BCH 20190625
#
# Build with
#
#   docker build -t <name> .
#
# In the case of a proxy (located at 192.168.13.14:3128), do:
#
#    docker build --build-arg http_proxy=http://10.41.13.4:3128 --build-arg https_proxy=https://10.41.13.6:3128 -t fetalrecon .
#
# To run an interactive shell inside this container, do:
#
#   docker run -it fetalrecon /bin/bash 
#
#   docker run -it --mount type=bind,source=/home/jeff/data/,target=/data fetalrecon
#
# To pass an env var HOST_IP to container, do:
#
#   docker run -ti -e HOST_IP=$(ip route | grep -v docker | awk '{if(NF==11) print $9}') --entrypoint /bin/bash local/chris_dev_backend
#

FROM nvidia/cuda:9.1-devel-ubuntu16.04
# https://hub.docker.com/r/nvidia/cuda

# using build command noted above is better pratice
# ENV http_proxy http://10.41.13.4:3128

# ENV https_proxy https://10.41.13.6:3128

# update and install dependencies
RUN         apt-get update \
                && apt-get install -y --no-install-recommends \
                    apt-utils \
                && apt-get install -y --no-install-recommends \
                    software-properties-common \
                    wget \
                    make \
                    git \
                    curl \
                    vim \
                    cmake \
                    gcc \
                    libtbb-dev \
                    libgsl-dev \
                    cmake-curses-gui

# add cuda samples to the image
ADD ./samples.tar.gz /usr/local/cuda-9.1

# These samples are extracted from the downloadable installation for CUDA-9.1
# https://developer.nvidia.com/compute/cuda/9.1/Prod/cluster_management/cuda_cluster_pkgs_9.1.85_ubuntu1604
# under cuda_cluster_pkgs_ubuntu1604/cuda-cluster-devel-9-1_9.1.85-1_amd64.deb/data.tar.xz/samples
# This could be made better, by dl and extract in the docker file.
RUN make -C /usr/local/cuda-9.1/samples

# this is the relevant fetalReconstruction
# COPY ./fetalReconstruction /usr/src/fetalReconstruction/
RUN git clone https://github.com/bkainz/fetalReconstruction.git /usr/src/fetalReconstruction/

# add boost and install additional libraries
# ADD ./boost_1_58_0.tar.bz2 /usr/src/boost/
RUN wget https://sourceforge.net/projects/boost/files/boost/1.58.0/boost_1_58_0.tar.bz2 -P /usr/src/ \
    && cd /usr/src/ && tar -xf boost_1_58_0.tar.bz2

RUN cd /usr/src/boost_1_58_0 \
    && ./bootstrap.sh --with-libraries=program_options,filesystem,system,thread \
    && ./b2 install

# ADD ./tbb2019_20190605oss_lin.tgz /usr/src/tbb/
# no longer needed with the pacakge added above 

# build ZLIB
RUN cd /usr/src/fetalReconstruction/source/IRTKSimple2/nifti/zlib \
    && ./configure && make install

RUN         apt-get update \
                && apt-get install -y --no-install-recommends \
			libpng-dev

# set up and build the fetalRecon software 
RUN mkdir /usr/src/fetalReconstruction/source/build \
        && mkdir /data \
	&& cd /usr/src/fetalReconstruction/source/build \
	&& cmake .. \
	&& cmake -D CUDA_SDK_ROOT_DIR:PATH=/usr/local/cuda-9.1/samples .. \
	&& make \
    && cp /usr/src/fetalReconstruction/source/bin/PVRreconstructionGPU /usr/bin \
    && cp /usr/src/fetalReconstruction/source/bin/SVRreconstructionGPU /usr/bin

#############################################################################

# some example code: 

# RUN mkdir -p /usr/src/boost \
#     && curl -SL http://example.com/big.tar.xz \
#     | tar -xJC /usr/src/things \
#     && make -C /usr/src/things all



# # Example Dockerfile from Hsaio

# FROM python:3.7-alpine3.9

# # https://stackoverflow.com/questions/55808233/alpine-docker-image-from-python3-x-alpine3-x-uses-different-package-version-for

# RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && apk update

# RUN apk del .python-rundeps

# RUN apk add git gcc linux-headers musl-dev libffi-dev openssl-dev python3-dev

# COPY . /nirscloud_auth
# WORKDIR /nirscloud_auth

# RUN mkdir /etc/nirscloud_auth
# COPY production.ini.template /etc/nirscloud_auth/production.ini

# RUN python --version
# RUN pip3 install -r requirements.txt
# RUN python3 setup.py develop

# ENTRYPOINT ["python", "-m", "nirscloud_auth.main", "-i", "/etc/nirscloud_auth/production.ini", "-p", "3456"]

# perhaps could set it up like the mirtk docker image:

# # Make "mirtk" the default executable for application containers
# ENTRYPOINT ["python", "/usr/local/bin/mirtk"]
# CMD ["help"]

# # Assume user data volume to be mounted at /data
# #   docker run --volume=/path/to/data:/data
# WORKDIR /data