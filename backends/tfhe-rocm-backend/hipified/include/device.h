#ifndef DEVICE_H
#define DEVICE_H

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <hip/hip_runtime.h>
#include <vector>

extern "C" {

#define check_cuda_error(ans)                                                  \
  { cuda_error((ans), __FILE__, __LINE__); }
inline void cuda_error(hipError_t code, const char *file, int line) {
  if (code != hipSuccess) {
    std::fprintf(stderr, "Cuda error: %s %s %d\n", hipGetErrorString(code),
                 file, line);
    std::abort();
  }
}
#define PANIC(format, ...)                                                     \
  {                                                                            \
    std::fprintf(stderr, "%s::%d::%s: panic.\n" format "\n", __FILE__,         \
                 __LINE__, __func__, ##__VA_ARGS__);                           \
    std::abort();                                                              \
  }

uint32_t cuda_get_device();
void cuda_set_device(uint32_t gpu_index);

hipEvent_t cuda_create_event(uint32_t gpu_index);

void cuda_event_record(hipEvent_t event, hipStream_t stream,
                       uint32_t gpu_index);
void cuda_stream_wait_event(hipStream_t stream, hipEvent_t event,
                            uint32_t gpu_index);

void cuda_event_destroy(hipEvent_t event, uint32_t gpu_index);

hipStream_t cuda_create_stream(uint32_t gpu_index);

void cuda_destroy_stream(hipStream_t stream, uint32_t gpu_index);

void cuda_synchronize_stream(hipStream_t stream, uint32_t gpu_index);

uint32_t cuda_is_available();

void *cuda_malloc(uint64_t size, uint32_t gpu_index);

void *cuda_malloc_with_size_tracking_async(uint64_t size, hipStream_t stream,
                                           uint32_t gpu_index,
                                           uint64_t &size_tracker,
                                           bool allocate_gpu_memory);

void *cuda_malloc_async(uint64_t size, hipStream_t stream, uint32_t gpu_index);

bool cuda_check_valid_malloc(uint64_t size, uint32_t gpu_index);
uint64_t cuda_device_total_memory(uint32_t gpu_index);

void cuda_memcpy_with_size_tracking_async_to_gpu(void *dest, const void *src,
                                                 uint64_t size,
                                                 hipStream_t stream,
                                                 uint32_t gpu_index,
                                                 bool gpu_memory_allocated);

void cuda_memcpy_async_to_gpu(void *dest, const void *src, uint64_t size,
                              hipStream_t stream, uint32_t gpu_index);

void cuda_memcpy_with_size_tracking_async_gpu_to_gpu(
    void *dest, void const *src, uint64_t size, hipStream_t stream,
    uint32_t gpu_index, bool gpu_memory_allocated);

void cuda_memcpy_async_gpu_to_gpu(void *dest, void const *src, uint64_t size,
                                  hipStream_t stream, uint32_t gpu_index);

void cuda_memcpy_gpu_to_gpu(void *dest, void const *src, uint64_t size,
                            uint32_t gpu_index);

void cuda_memcpy_async_to_cpu(void *dest, const void *src, uint64_t size,
                              hipStream_t stream, uint32_t gpu_index);

void cuda_memset_with_size_tracking_async(void *dest, uint64_t val,
                                          uint64_t size, hipStream_t stream,
                                          uint32_t gpu_index,
                                          bool gpu_memory_allocated);

void cuda_memset_async(void *dest, uint64_t val, uint64_t size,
                       hipStream_t stream, uint32_t gpu_index);

int cuda_get_number_of_gpus();

void cuda_synchronize_device(uint32_t gpu_index);

void cuda_drop(void *ptr, uint32_t gpu_index);

void cuda_drop_with_size_tracking_async(void *ptr, hipStream_t stream,
                                        uint32_t gpu_index,
                                        bool gpu_memory_allocated);

void cuda_drop_async(void *ptr, hipStream_t stream, uint32_t gpu_index);
}

uint32_t cuda_get_max_shared_memory(uint32_t gpu_index);

bool cuda_check_support_cooperative_groups();

bool cuda_check_support_thread_block_clusters();

template <typename Torus>
void cuda_set_value_async(hipStream_t stream, uint32_t gpu_index,
                          Torus *d_array, Torus value, Torus n);

#endif 

