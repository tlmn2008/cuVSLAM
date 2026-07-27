#!/bin/bash
cd /home/repos/cuVSLAM
source /etc/profile.d/corex.sh
cmake --build build --parallel "$(nproc)" 2>&1
echo "BUILD_EXIT=${PIPESTATUS[0]}"
