#include "programmable_bootstrap.cuh"

// Template specializations for cooperative groups

template <>
__device__ int get_this_block_rank(grid_group &group, bool support_dsm) {
  return blockIdx.y;
}

template <>
__device__ HIP_vector_type<double, 2u> *
get_join_buffer_element(int level_id, int glwe_id, grid_group &group,
                        HIP_vector_type<double, 2u> *global_memory_buffer, uint32_t polynomial_size,
                        uint32_t glwe_dimension, bool support_dsm) {
  HIP_vector_type<double, 2u> *buffer_slice =
      global_memory_buffer +
      (glwe_id + level_id * (glwe_dimension + 1)) * polynomial_size / 2;
  return buffer_slice;
}

template <>
__device__ double *get_join_buffer_element_128(
    int level_id, int glwe_id, grid_group &group, double *global_memory_buffer,
    uint32_t polynomial_size, uint32_t glwe_dimension, bool support_dsm) {
  double *buffer_slice =
      global_memory_buffer +
      (glwe_id + level_id * (glwe_dimension + 1)) * polynomial_size / 2 * 4;
  return buffer_slice;
}

// ROCm equivalent of CUDA_ARCH >= 900 check
// For ROCm, we check for architectures that support advanced cooperative groups
// This includes gfx90a and newer architectures
#if defined(__gfx90a__) || defined(__gfx940__) || defined(__gfx941__) || defined(__gfx942__) || (ROCM_ARCH >= 90)
template <>
__device__ int get_this_block_rank(cluster_group &cluster, bool support_dsm) {
  if (support_dsm)
    return cluster.block_index().y;
  else
    return blockIdx.y;
}

template <>
__device__ HIP_vector_type<double, 2u> *
get_join_buffer_element(int level_id, int glwe_id, cluster_group &cluster,
                        HIP_vector_type<double, 2u> *global_memory_buffer, uint32_t polynomial_size,
                        uint32_t glwe_dimension, bool support_dsm) {
  HIP_vector_type<double, 2u> *buffer_slice;
  if (support_dsm) {
    extern __shared__ HIP_vector_type<double, 2u> smem[];
    buffer_slice = cluster.map_shared_rank(
        smem, glwe_id + level_id * (glwe_dimension + 1));
  } else {
    buffer_slice =
        global_memory_buffer +
        (glwe_id + level_id * (glwe_dimension + 1)) * polynomial_size / 2;
  }
  return buffer_slice;
}

template <>
__device__ double *get_join_buffer_element_128(
    int level_id, int glwe_id, cluster_group &cluster, double *global_memory_buffer,
    uint32_t polynomial_size, uint32_t glwe_dimension, bool support_dsm) {
  double *buffer_slice;
  if (support_dsm) {
    extern __shared__ double smem[];
    // For 128-bit operations, we need 4x the space
    buffer_slice = smem + (glwe_id + level_id * (glwe_dimension + 1)) * polynomial_size / 2 * 4;
  } else {
    buffer_slice =
        global_memory_buffer +
        (glwe_id + level_id * (glwe_dimension + 1)) * polynomial_size / 2 * 4;
  }
  return buffer_slice;
}
#endif
