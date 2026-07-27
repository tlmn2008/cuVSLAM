# Copyright (c) 2026, NVIDIA CORPORATION. All rights reserved.
#
# NVIDIA software released under the NVIDIA Community License is intended to be used to enable
# the further development of AI and robotics technologies. Such software has been designed, tested,
# and optimized for use with NVIDIA hardware, and this License grants permission to use the software
# solely with such hardware.
# Subject to the terms of this License, NVIDIA confirms that you are free to commercially use,
# modify, and distribute the software with NVIDIA hardware. NVIDIA does not claim ownership of any
# outputs generated using the software or derivative works thereof. Any code contributions that you
# share with NVIDIA are licensed to NVIDIA as feedback under this License and may be incorporated
# in future releases without notice or attribution.
# By using, reproducing, modifying, distributing, performing, or displaying any portion or element
# of the software or derivative works thereof, you agree to be bound by this License.

project(cuda_kernels LANGUAGES CXX CUDA)

set(SOURCES
    convolutions.cu
    gftt.cu
    image_pyramid.cu
    lk_tracker.cu
    selection_v2.cu
    image_cast.cu
    sort.cu
    st_tracker.cu
    sba_v1.cu
    sba_imu_v1.cu
    window_matcher.cu
    photometric_kernel.cu
    point_to_point_icp_kernel.cu
    plane_detection_kernel.cu
    )

add_library(cuda_kernels STATIC ${SOURCES})

# CUDA_ARCHITECTURES is initialized from CMAKE_CUDA_ARCHITECTURES, which the root CMakeLists sets for
# every cuVSLAM CUDA target (an explicit arch list/value, or OFF + global -arch=all for the
# CMake < 3.23 "all" fallback). No per-target architecture handling is needed here.
# On CoreX/ivcore11 the separable-compilation device-link step (clang++ -dlink feeding a full
# PIE host object into ld -shared) fails ("cannot find -lcudart" / R_X86_64_PC32 in shared
# object). These kernels do not need cross-TU device linking, so disable it there (see the
# cuda-separable-compilation-shared-pic compatibility case). NVIDIA keeps the original behaviour.
if(CMAKE_CUDA_COMPILER_ID STREQUAL "ILUVATAR")
    set_target_properties(cuda_kernels PROPERTIES
        CUDA_SEPARABLE_COMPILATION OFF
        CUDA_RESOLVE_DEVICE_SYMBOLS OFF
    )
else()
    set_target_properties(cuda_kernels PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON
        CUDA_RESOLVE_DEVICE_SYMBOLS ON
    )
endif()

# CoreX/ivcore11 (clang++ CUDA front end) does not accept the nvcc-style
# "--compiler-options=<a,b>" (-Xcompiler) wrapper — it errors with "unknown argument".
# clang compiles host+device in one pass, so -fPIC / -fvisibility=hidden are passed
# directly. The nvcc-only -G / -lineinfo debug flags are also unsupported on ivcore11.
if(CMAKE_CUDA_COMPILER_ID STREQUAL "ILUVATAR")
    target_compile_options(cuda_kernels PRIVATE
        $<$<COMPILE_LANGUAGE:CUDA>:-fPIC>
        $<$<COMPILE_LANGUAGE:CUDA>:-fvisibility=hidden>
    )
else()
    target_compile_options(cuda_kernels PRIVATE
        $<$<COMPILE_LANGUAGE:CUDA>:--compiler-options=-fPIC,-fvisibility=hidden>
        # Enable device debug info for compute-sanitizer support
        $<$<AND:$<COMPILE_LANGUAGE:CUDA>,$<CONFIG:Debug>>:-G>
        $<$<AND:$<COMPILE_LANGUAGE:CUDA>,$<CONFIG:RelWithDebInfo>>:-lineinfo>
    )
endif()

# CoreX/ivcore11 has no self-contained static cudart (its libcudart_static.a pulls an undefined
# CreateLogger from libixthunk); link the shared runtime there. NVIDIA keeps the static runtime.
if(CMAKE_CUDA_COMPILER_ID STREQUAL "ILUVATAR")
    set(_cuvslam_cudart CUDA::cudart)
else()
    set(_cuvslam_cudart CUDA::cudart_static)
endif()
target_link_libraries(cuda_kernels PUBLIC
    cuvslam_settings
    ${_cuvslam_cudart}
    CUDA::cublas
    CUDA::cusolver
)
