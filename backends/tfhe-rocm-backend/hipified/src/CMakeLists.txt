# Find all HIP source files (both .cu and .hip files)
file(GLOB_RECURSE SOURCES "*.cu" "*.hip")
add_library(tfhe_rocm_backend STATIC ${SOURCES} pbs/programmable_bootstrap_multibit_128.cuh
                                     pbs/programmable_bootstrap_multibit_128.cu)

# Set HIP-specific properties
set_target_properties(tfhe_rocm_backend PROPERTIES 
    HIP_SEPARABLE_COMPILATION ON
    HIP_RESOLVE_DEVICE_SYMBOLS ON
    POSITION_INDEPENDENT_CODE ON)

# Link ROCm/HIP libraries
target_link_libraries(tfhe_rocm_backend PUBLIC hip::host OpenMP::OpenMP_CXX)
target_include_directories(tfhe_rocm_backend PRIVATE .)
