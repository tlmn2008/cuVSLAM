# cuVSLAM → Iluvatar CoreX (ivcore11) 迁移记录

## 来源
- 仓库: https://github.com/nvidia-isaac/cuVSLAM.git
- 分支: `main`
- 起点 commit: `57f42cc92d93eef47577d726789852a350b2a369`
- commit 日期: 2026-07-22T22:19:46+04:00
- 说明: NVIDIA Isaac 的 CUDA 加速视觉 SLAM/里程计 C++ 库，含一手 CUDA 内核面。使用 git-lfs（test_data）与 FetchContent（Eigen/spdlog/lmdb/googletest/cuNLS 等）。

## CUDA 使用性质
- 一手 CUDA：`libs/cuda_modules/**`（含 `cuda_kernels`，14 个 `.cu` 设备编译单元），覆盖特征、SOF、光束平差(SBA)等。
- 数值精度：SLAM/光束平差数学重度依赖 FP64（double）。ivcore11 无真实 FP64，double 退化为 fp32 → SBA 参考一致性测试无法达标（见结果）。
- 纹理：使用 `tex2D<>` 纹理采样，ivcore11 无纹理硬件。
- 依赖：cuNLS（USE_CUNLS 默认 ON）通过 FetchContent 拉取，并下载 NVIDIA 专有预编译 cuDSS —— ivcore11 无对应实现。

## 环境
- CoreX SDK: `/usr/local/corex`（zero-touch，未改动）。IX-ML 4.4.0 / Driver 4.5.0。
- GPU: 2x Iluvatar BI-V150（ivcore11）可见，测试 `CUDA_VISIBLE_DEVICES=0,1`（≤2）。
- 编译器: `clang/clang++`（CUDA 编译器 = `/usr/local/corex/bin/clang++`，CUDA_COMPILER_ID=ILUVATAR）。无 nvcc。

## 适配内容
构建系统按 `CMAKE_CUDA_COMPILER MATCHES corex` / `CUDA_COMPILER_ID STREQUAL ILUVATAR` 条件分支，未破坏原 NVIDIA 路径：
1. **CUDA 架构/编译器**：`-DCMAKE_CUDA_COMPILER=.../clang++ -DCMAKE_CUDA_ARCHITECTURES=ivcore11`，`CMAKE_CUDA_FLAGS += -std=c++17`（clang 忽略 CMAKE_CUDA_STANDARD，否则 ixthrust 报 “requires C++17”）。
2. **软件纹理桥**：新增 `corex_compat/texture_bridge/`（`texture_indirect_functions.h` + `corex_prelude.h`），以 `-include` 强制注入每个 TU，为 host/device 一致提供 `tex2D<>`；并对 host pass 增加前置声明。`include_directories(BEFORE /usr/local/corex/include)` 使 host `.cpp` 也能找到 CUDA 头。
3. **分离编译/设备链接**：对 ILUVATAR 关闭 `CUDA_SEPARABLE_COMPILATION` 与 `CUDA_RESOLVE_DEVICE_SYMBOLS`（`-dlink` 在该工具链失败），内核自包含。
4. **CUDA 运行时库**：由 `cudart_static` 改为 shared `CUDA::cudart`（CoreX `libcudart_static.a` 依赖 `libixthunk` 的 `CreateLogger` 符号，静态链接未定义）。涉及 `cmake/cuVSLAMUtils.cmake`、`libs/common`、`libs/cuda_modules/cuda_kernels`。
5. **去 nvcc 专有 flag**：移除 `--compiler-options=-fPIC,...`、`-G`、`-lineinfo`，改用 clang 原生 `-fPIC -fvisibility=hidden`。
6. **依赖裁剪**：`-DUSE_CUNLS=OFF`（cuNLS/cuDSS terminal wall，禁用 Multisensor 模式）、`-DUSE_NVTX=OFF`、`-DUSE_RERUN=OFF`。
7. **OpenCV**：`-DOpenCV_DIR=/usr/lib/x86_64-linux-gnu/cmake/opencv4` 用系统新 ABI OpenCV（解决编译期 ABI 不匹配）；运行期以 `corex_port/opencv_shim`（仅 OpenCV 软链）前置 LD_LIBRARY_PATH，避免 CoreX 旧 ABI OpenCV 遮蔽。

改动文件：`CMakeLists.txt`、`cmake/cuVSLAMUtils.cmake`、`libs/common/CMakeLists.txt`、`libs/cuda_modules/cuda_kernels/CMakeLists.txt`、`libs/cuvslam/CMakeLists.txt`、新增 `corex_compat/`。

## 结果
- **编译**：success。14 个 `.cu` + 266 个 `.cpp` 单元全部以 clang++(ivcore11) 编译并链接为 `libcuvslam.so`(14.7MB) 及 28 个测试二进制。
- **测试**（`ctest -V`，2x BI-V150）：ctest 二进制 14/15 通过；gtest 用例 193/196 通过（另 19 个 upstream `DISABLED_` 未执行）。test_status=partial_pass。
  - 失败仅 `cuda_modules_test` 的 3 个 SBA 光束平差用例（`SBABuildFullSystem`/`SBAEvaluateCost`/`SBAComputePredictedRelativeReduction`），根因 = ivcore11 无 FP64。
  - 核心追踪相关测试（`odometry_test`/`slam_test`/`imu_test`/`pipelines_test`/`map_test`/`sof_test` 等）全部通过。
- **整体**：partial —— 编译成功、核心追踪可用，Multisensor(cuNLS) 与 SBA 数值精调受 FP64/闭源依赖限制。

## Failure Gate
逐一复现并分类每个壁垒（详见 `blockers.json`）：
- `cuNLS/cuDSS`（terminal）：以 USE_CUNLS=ON 复现配置失败；cuDSS 为 NVIDIA 闭源预编译无 ivcore11 档，无源码可重编 → 按契约 USE_CUNLS=OFF 关闭 Multisensor。
- `SBA FP64 精度`（terminal）：复现 3 例失败，确认为硬件级 FP64 缺失导致的数值不一致，非崩溃；不放宽阈值以免掩盖真实精度损失，如实保留失败。
- `OpenCV 运行期 ABI 冲突`（workaround-able，已解决）：建 opencv_shim 前置 LD_LIBRARY_PATH，camera_test 通过。
- `nvcc→clang++ 工具链差异`（workaround-able，已解决）：纹理桥/分离编译/shared cudart/C++17 等逐项适配，编译链接全通过。
所有 workaround-able 壁垒均已实际尝试并解决；仅 FP64 与 cuDSS 两个硬件/闭源 terminal 壁垒无法绕过，已如实记录。
