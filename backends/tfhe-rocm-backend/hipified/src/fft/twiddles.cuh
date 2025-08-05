#ifndef GPU_BOOTSTRAP_TWIDDLES_CUH
#define GPU_BOOTSTRAP_TWIDDLES_CUH

#include <hip/hip_runtime.h>
#include "hip/hip_complex.h"

/*
 * 'negtwiddles' are stored in device memory to profit caching
 */
extern __device__ double2 negtwiddles[8192];
#endif
