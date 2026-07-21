# syntax = docker/dockerfile:1.4

# Use NVIDIA CUDA base image with Ubuntu 20.04, CUDA 11.2, cuDNN 8
# This avoids manual CUDA/cuDNN installation and provides better caching
FROM nvidia/cuda:11.2.2-cudnn8-devel-ubuntu20.04 AS gpu-base

# Arguments
ARG WORKSPACE_FLAVOR="gpu"
ARG WORKSPACE_VERSION="latest"
ARG BUILD_DATE="unknown"
ARG VCS_REF="unknown"

# Environment variables
ENV WORKSPACE_FLAVOR=$WORKSPACE_FLAVOR
ENV WORKSPACE_VERSION=$WORKSPACE_VERSION
ENV TF_FORCE_GPU_ALLOW_GROWTH=true

# NVIDIA Container Runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV NVIDIA_REQUIRE_CUDA "cuda>=11.2 brand=tesla,driver>=418,driver<419 brand=tesla,driver>=440,driver<441 driver>=450"

# CUDA paths are already set in the base image
ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

# NCCL version
ENV NCCL_VERSION 2.8.4

# Link Cupti
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:/usr/local/cuda/extras/CUPTI/lib64

# Copy cleanup scripts
COPY resources/scripts/clean-layer.sh /usr/bin/clean-layer.sh
COPY resources/scripts/fix-permissions.sh /usr/bin/fix-permissions.sh
RUN chmod +x /usr/bin/clean-layer.sh /usr/bin/fix-permissions.sh

# Install additional system dependencies for GPU packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    libomp-dev libopenblas-base \
    && clean-layer.sh

### GPU DATA SCIENCE LIBRARIES ###

# Use BuildKit cache mounts for pip and conda
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/opt/conda/pkgs \
    --mount=type=cache,target=/var/tmp \
    \

    # Install pytorch gpu
    # uninstall cpu only packages via conda
    conda remove --force -y pytorch cpuonly && \
    # https://pytorch.org/get-started/locally/
    conda install cudatoolkit=11.2 -c pytorch -c nvidia && \
    pip install --no-cache-dir torch==1.9.0+cu111 torchvision==0.10.0+cu111 torchaudio==0.9.0 -f https://download.pytorch.org/whl/torch_stable.html && \
    # Install cupy: https://cupy.chainer.org/
    pip install --no-cache-dir cupy-cuda112 && \
    # Install pycuda: https://pypi.org/project/pycuda
    pip install --no-cache-dir pycuda && \
    # Install gpu utils libs
    pip install --no-cache-dir gpustat py3nvml gputil && \
    # Install scikit-cuda: https://scikit-cuda.readthedocs.io/en/latest/install.html
    pip install --no-cache-dir scikit-cuda && \
    # Install tensorflow gpu
    pip uninstall -y tensorflow tensorflow-cpu intel-tensorflow && \
    pip install --no-cache-dir tensorflow-gpu==2.5.0 && \
    # Install ONNX GPU Runtime
    pip uninstall -y onnxruntime && \
    pip install --no-cache-dir onnxruntime-gpu==1.8.0 onnxruntime-training==1.8.0 && \
    # Install faiss gpu
    # conda remove --force -y faiss-cpu && \
    # conda install -y faiss-gpu -c pytorch && \
    # Update mxnet to gpu edition
    pip uninstall -y mxnet-mkl && \
    # cuda111 -> >= 11.1
    pip install --no-cache-dir mxnet-cu112 && \
    # install jax: https://github.com/google/jax#pip-installation
    pip install --# install jax: https://github.com/google/jax#pip-installation \
    pip install --upgrade jax[cuda111] -f https://storage.googleapis.com/jax-releases/jax_releases.html && \
    # Install pygpu - Required for theano: http://deeplearning.net/software/libgpuarray/
    conda install -y pygpu && \
    # Install lightgbm
    pip uninstall -y lightgbm && \
    pip install lightgbm --install-option=--gpu --install-option="--opencl-include-dir=/usr/local/cuda/include/" --install-option="--opencl-library=/usr/local/cuda/lib64/libOpenCL.so"  && \
    # nvidia python ml lib
    pip install --upgrade --force-reinstall nvidia-ml-py3 && \
    # SpeedTorch: https://github.com/Santosh-Gupta/SpeedTorch
    pip install --no-cache-dir SpeedTorch && \
    # Ipyexperiments - fix memory leaks
    pip install --no-cache-dir ipyexperiments && \
    # Cleanup
    clean-layer.sh

# TODO install DALI: https://docs.nvidia.com/deeplearning/dali/user-guide/docs/installation.html#dali-and-ngc
# TODO: if > Ubuntu 19.04 -> install nvtop: https://github.com/Syllo/nvtop
# TODO: Install Arrayfire: https://arrayfire.com/download/ pip install --no-cache-dir arrayfire && \
# TODO Nvidia Apex: https://github.com/NVIDIA/apex

### END DATA SCIENCE LIBRARIES ###

### GPU TOOLS ###

### END GPU TOOLS ###

### CONFIGURATION ###

# argument needs to be initalized again
ARG ARG_WORKSPACE_VERSION="latest"
ENV WORKSPACE_VERSION=$ARG_WORKSPACE_VERSION

# Overwrite & add Labels
ARG ARG_BUILD_DATE="unknown"
ARG ARG_VCS_REF="unknown"

LABEL \
    "workspace.version"=$WORKSPACE_VERSION \
    "workspace.flavor"=$WORKSPACE_FLAVOR \
    "workspace.baseimage"="nvidia/cuda:11.2.2-cudnn8-devel-ubuntu20.04" \
    "org.opencontainers.image.version"=$WORKSPACE_VERSION \
    "org.opencontainers.image.revision"=$ARG_VCS_REF \
    "org.opencontainers.image.created"=$ARG_BUILD_DATE \
    "org.label-schema.version"=$WORKSPACE_VERSION \
    "org.label-schema.vcs-ref"=$ARG_VCS_REF \
    "org.label-schema.build-date"=$ARG_BUILD_DATE
