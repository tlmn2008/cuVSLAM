#!/bin/bash
# Failure-Gate reproduction: attempt the default (USE_CUNLS=ON) configure on ivcore11.
# This is expected to hit the cuDSS prebuilt-archive wall (NVIDIA-only). Also warms the
# FetchContent cache for all base dependencies (eigen/gtest/spdlog/lmdb/...).
cd /home/repos/cuVSLAM
source /etc/profile.d/corex.sh
rm -rf build_cunls
cmake -S . -B build_cunls \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CUDA_COMPILER=/usr/local/corex/bin/clang++ \
  -DCUDAToolkit_ROOT=/usr/local/corex \
  -DCMAKE_CUDA_ARCHITECTURES=ivcore11 \
  -DUSE_CUNLS=ON -DUSE_RERUN=OFF -DUSE_NVTX=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 2>&1
echo "CONFIGURE_EXIT=${PIPESTATUS[0]}"
