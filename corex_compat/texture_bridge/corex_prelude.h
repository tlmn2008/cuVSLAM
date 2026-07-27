/*
 * CoreX/ivcore11 prelude — force-included (clang -include) into every cuVSLAM
 * translation unit on CoreX. ivcore11 has no texture hardware and its SDK does
 * not expose a usable tex2D<>/cudaCreateTextureObject, so we pull in the software
 * texture bridge right after cuda_runtime.h. Must be force-included (not shadowed):
 * the SDK cuda_runtime.h does not #include texture_indirect_functions.h on its own.
 */
#pragma once
#include <cuda_runtime.h>
#include "texture_indirect_functions.h"
