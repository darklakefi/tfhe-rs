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

// ROCm doesn't support cluster_group (CUDA 9.0+ feature)
// These template specializations are removed for ROCm builds
