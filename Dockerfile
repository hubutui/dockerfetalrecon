FROM nvidia/cuda:10.2-devel-ubuntu18.04

RUN rm -vf /etc/apt/sources.list.d/*
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt \
    apt update \
    && apt install -y --no-install-recommends \
    cmake \
    git \
    libboost-atomic-dev \
    libboost-chrono-dev \
    libboost-date-time-dev \
    libboost-filesystem-dev \
    libboost-program-options-dev \
    libboost-system-dev \
    libboost-thread-dev \
    libgsl0-dev \
    libnifti-dev \
    libpng-dev \
    libtbb-dev \
    wget
RUN wget https://developer.download.nvidia.cn/compute/cuda/repos/ubuntu1804/x86_64/cuda-keyring_1.0-1_all.deb \
    && dpkg -i cuda-keyring_1.0-1_all.deb \
    && rm -vf cuda-keyring_1.0-1_all.deb \
    && apt-key del 7fa2af80
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt \
    apt update \
    && apt install -y --no-install-recommends cuda-samples-10-2
WORKDIR /workspace
RUN git clone https://github.com/bkainz/fetalReconstruction.git \
    && cd /workspace/fetalReconstruction/source \
    && sed -i '104i set(CUDA_CUDA_LIBRARY "/usr/local/cuda/lib64/stubs/libcuda.so")' /workspace/fetalReconstruction/source/cmake/FindSciCuda.cmake \
    && cmake . -DCMAKE_BUILD_TYPE=Release -DCUDA_SDK_ROOT_DIR=/usr/local/cuda/samples \
    -DCUDA_NVCC_FLAGS="-gencode=arch=compute_30,code=sm_30;-gencode=arch=compute_35,code=sm_35;-gencode=arch=compute_37,code=sm_37;-gencode=arch=compute_50,code=sm_50;-gencode=arch=compute_52,code=sm_52;-gencode=arch=compute_53,code=sm_53;-gencode=arch=compute_60,code=sm_60;-gencode=arch=compute_61,code=sm_61;-gencode=arch=compute_62,code=sm_62;-gencode=arch=compute_70,code=sm_70;-gencode=arch=compute_72,code=sm_72;-gencode=arch=compute_75,code=sm_75" \
    && make \
    && cp bin/PVRreconstructionGPU /usr/bin \
    && cp bin/SVRreconstructionGPU /usr/bin
