option(TFHE_ROCM_BACKEND_BUILD_TESTS "Build the test tool" OFF)
option(TFHE_ROCM_BACKEND_BUILD_BENCHMARKS "Build the benchmark tool" OFF)

if(TFHE_ROCM_BACKEND_BUILD_TESTS)
    message(STATUS "Building the ROCm test tool")
    add_subdirectory(tests)
endif()

if(TFHE_ROCM_BACKEND_BUILD_BENCHMARKS)
    message(STATUS "Building the ROCm benchmark tool")
    add_subdirectory(benchmarks)
endif()
