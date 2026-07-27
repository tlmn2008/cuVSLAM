#!/bin/bash
# Primary ivcore11 configure: cuNLS OFF (cuDSS is NVIDIA-only prebuilt, terminal).
# clang++ as CUDA compiler, ivcore11 arch, Rerun/NVTX off per SOP.
cd /home/repos/cuVSLAM
source /etc/profile.d/corex.sh
rm -rf build
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CUDA_COMPILER=/usr/local/corex/bin/clang++ \
  -DCUDAToolkit_ROOT=/usr/local/corex \
  -DCMAKE_CUDA_ARCHITECTURES=ivcore11 \
  -DUSE_CUNLS=OFF -DUSE_RERUN=OFF -DUSE_NVTX=OFF \
  -DOpenCV_DIR=/usr/lib/x86_64-linux-gnu/cmake/opencv4 \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 2>&1
echo "CONFIGURE_EXIT=${PIPESTATUS[0]}"
