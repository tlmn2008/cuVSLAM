#!/usr/bin/env bash
# 重建 OpenCV runtime shim：仅软链系统(新 __cxx11 ABI) OpenCV，前置 LD_LIBRARY_PATH 以
# 避免 CoreX(/usr/local/corex/lib64) 自带旧 ABI OpenCV 在运行期遮蔽测试二进制所链接的系统 OpenCV。
# 用法: bash make_opencv_shim.sh && export LD_LIBRARY_PATH=$PWD/../opencv_shim:$LD_LIBRARY_PATH
set -euo pipefail
SHIM_DIR="$(cd "$(dirname "$0")/.." && pwd)/opencv_shim"
mkdir -p "$SHIM_DIR"
cd "$SHIM_DIR"
ln -sf /usr/lib/x86_64-linux-gnu/libopencv_*.so.406 . 2>/dev/null || true
ln -sf /usr/lib/x86_64-linux-gnu/libopencv_*.so.4.6.0 . 2>/dev/null || true
echo "opencv_shim rebuilt at $SHIM_DIR ($(ls | wc -l) links)"
