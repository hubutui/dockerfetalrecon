# Set up a docker image for fetalReconstruction
# https://github.com/bkainz/fetalReconstruction
#
# Jeff Stout BCH 201900823
#
# Build with
#
#   docker build -t <name> .
#
# In the case of a proxy (located at 192.168.13.14:3128), do:
#
#    docker build --build-arg http_proxy=http://10.41.13.4:3128 --build-arg https_proxy=https://10.41.13.6:3128 -t fetalrecon:6.5 .
#
# --no-cache will force a clean build
# 
# To run an interactive shell inside this container, do:
#
#   docker run --gpus all -it fetalrecon /bin/bash 
#
#   docker run --gpus all -it --mount type=bind,source=/neuro/users/jeff.stout/docker/data,target=/data fetalrecon:6.5
#
#   docker run --gpus '"device=1"' -it --mount type=bind,source=/neuro/users/jeff.stout/docker/data,target=/data fetalrecon:6.5
# 
# To pass an env var HOST_IP to container, do:
#
#   docker run -ti -e HOST_IP=$(ip route | grep -v docker | awk '{if(NF==11) print $9}') --entrypoint /bin/bash local/chris_dev_backend
# 
# Docker build cuda library issue:
# the default runtime must be set to nvidia in order to have CUDA libararies mounted during build (see: https://github.com/NVIDIA/nvidia-docker/wiki/Advanced-topics)
# This can be accomplished for the docker 19.03 nvidia-runtime by:
# installing the nvidia-container-runtime package in your host. Then put this inside /etc/docker/daemon.json
# {
#     "runtimes": {
#         "nvidia": {
#             "path": "/usr/bin/nvidia-container-runtime",
#             "runtimeArgs": []
#         }
#     },
#     "default-runtime": "nvidia"
# }

FROM nvidia/cuda:6.5-devel
# https://hub.docker.com/r/nvidia/cuda

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
                    # libgsl-dev \
                    cmake-curses-gui \
                    libpng-dev

# add cuda samples to the image
# COPY ./cuda-samples-linux-6.5.14-18745345.run /usr/cudasamples/
RUN wget http://developer.download.nvidia.com/compute/cuda/6_5/rel/installers/cuda_6.5.14_linux_64.run -P /usr/cudasamples/ \
    && sh /usr/cudasamples/cuda-samples-linux-6.5.14-18745345.run -noprompt \
    &&  make -C /usr/local/cuda/samples -j8

RUN         apt-get update \
                && apt-get install -y --no-install-recommends \
                    libgsl0-dev 

# add boost and install additional libraries
RUN wget https://sourceforge.net/projects/boost/files/boost/1.58.0/boost_1_58_0.tar.bz2 -P /usr/src/ \
    && cd /usr/src/ && tar -xf boost_1_58_0.tar.bz2 \
    && cd /usr/src/boost_1_58_0 \
    && ./bootstrap.sh --with-libraries=program_options,filesystem,system,thread,atomic,chrono,date_time \
    && ./b2 install

# RUN wget https://sourceforge.net/projects/boost/files/boost/1.55.0/boost_1_55_0.tar.bz2 -P /usr/src/ \
#     && cd /usr/src/ && tar -xf boost_1_55_0.tar.bz2 \
#     && cd /usr/src/boost_1_55_0 \
#     && ./bootstrap.sh --with-libraries=program_options,filesystem,system,thread,atomic,chrono,date_time \
#     && ./b2 install

# this is the relevant fetalReconstruction use the copy when you need to modify the code
# COPY ./fetalReconstruction /usr/src/fetalReconstruction/
RUN git clone https://github.com/bkainz/fetalReconstruction.git /usr/src/fetalReconstruction/ \
&& cd /usr/src/fetalReconstruction/ && git checkout 042b4f7acaaf4c572de1c1ff1bca95bb746e4fae

# build ZLIB
RUN cd /usr/src/fetalReconstruction/source/IRTKSimple2/nifti/zlib \
    && ./configure && make install

# set up and build the fetalRecon software 
RUN mkdir /usr/src/fetalReconstruction/source/build \
        && mkdir /data \
    && cd /usr/src/fetalReconstruction/source/build 

# # update cmake to the latest version so that it plays nice with CUDA 9.0
# RUN apt-get update \
#                 && apt-get install -y --no-install-recommends \
#                     apt-transport-https ca-certificates gnupg software-properties-common wget \
#     && wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | apt-key add - \
#     && apt-add-repository 'deb https://apt.kitware.com/ubuntu/ xenial main' \
#     && apt-get update \
#     && apt-get install -y --no-install-recommends cmake

RUN cd /usr/src/fetalReconstruction/source/build \
    # && cmake -DCUDA_SDK_ROOT_DIR:PATH=/usr/local/cuda/samples -DCUDA_NVCC_FLAGS=-gencode=arch=compute_35,code=sm_35 .. \
    && cmake -DCUDA_SDK_ROOT_DIR:PATH=/usr/local/cuda/samples .. \
    # && cmake -DCUDA_SDK_ROOT_DIR:PATH=/usr/local/cuda/samples -DCUDA_CUDA_LIBRARY:PATH=/usr/lib/x86_64-linux-gnu/libcuda.so .. \
    && make -j8 ; exit 0
# the error above is weird. run make again and it is all good, I don't know why
RUN cd /usr/src/fetalReconstruction/source/build \
    && make -j8 \
    && cp /usr/src/fetalReconstruction/source/bin/PVRreconstructionGPU /usr/bin \
    && cp /usr/src/fetalReconstruction/source/bin/SVRreconstructionGPU /usr/bin

#############################################################################
# Compute architecture compile flag information for line 97 above. cm_35 is the original device that the code was written for. 
# http://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/
#  https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html#gpu-compilation
#  "In fact, --gpu-architecture=arch --gpu-code=code,... is equivalent to --generate-code=arch=arch,code=code,.... "
#  -gencode=arch=compute_70,code=sm_70
#  -gencode=arch=compute_30,code=sm_30 (this was native for the fetal recon intially, I think)

# useful test for PVRreconstructionGPU
# cd /usr/src/fetalReconstruction/data
# PVRreconstructionGPU -o 3TReconstruction.nii.gz -i 14_3T_nody_001.nii.gz 10_3T_nody_001.nii.gz 21_3T_nody_001.nii.gz 23_3T_nody_001.nii.gz -m mask_10_3T_brain_smooth.nii.gz --resolution 1.0
# current error:
# CUDA Error in patchBasedPSFReconstructionKernel(), line 132: too many resources requested for launch
# NOTE: all the other various memory errors were fixed by making certain there was sufficient memory open to run the code
# all the compile errors (some very werid) were fixed by updating cmake

