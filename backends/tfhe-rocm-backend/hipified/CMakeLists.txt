cmake_minimum_required(VERSION 3.24 FATAL_ERROR)
project(tfhe_rocm_backend LANGUAGES CXX)

# See if the minimum ROCm version is available. If not, only enable documentation building.
set(MINIMUM_SUPPORTED_ROCM_VERSION 5.0)

# Find ROCm installation
find_package(hip QUIET)
if(NOT hip_FOUND)
    set(HIP_ROOT_DIR "/opt/rocm" CACHE PATH "Root directory of HIP installation")
    list(APPEND CMAKE_PREFIX_PATH ${HIP_ROOT_DIR})
    find_package(hip REQUIRED)
endif()

# Check if HIP compiler is available
find_program(HIP_HIPCC_EXECUTABLE
    NAMES hipcc
    HINTS ${HIP_ROOT_DIR}/bin
    PATHS /opt/rocm/bin
    DOC "HIP compiler"
)

if(NOT HIP_HIPCC_EXECUTABLE)
    message(FATAL_ERROR "HIP compiler (hipcc) not found. Please install ROCm.")
endif()

# Check ROCm version
execute_process(
    COMMAND ${HIP_HIPCC_EXECUTABLE} --version
    OUTPUT_VARIABLE HIP_VERSION_OUTPUT
    ERROR_QUIET
)

# Extract version from hipcc output
string(REGEX MATCH "HIP version: ([0-9]+\\.[0-9]+)" HIP_VERSION_MATCH "${HIP_VERSION_OUTPUT}")
if(HIP_VERSION_MATCH)
    set(HIP_VERSION ${CMAKE_MATCH_1})
else()
    # Fallback: try to get version from ROCm
    execute_process(
        COMMAND cat /opt/rocm/.info/version
        OUTPUT_VARIABLE ROCM_VERSION_OUTPUT
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(ROCM_VERSION_OUTPUT)
        set(HIP_VERSION ${ROCM_VERSION_OUTPUT})
    else()
        set(HIP_VERSION "5.0")  # Default assumption
    endif()
endif()

if(HIP_VERSION VERSION_LESS ${MINIMUM_SUPPORTED_ROCM_VERSION})
    message(FATAL_ERROR "ROCm ${MINIMUM_SUPPORTED_ROCM_VERSION} or greater is required for compilation. Found: ${HIP_VERSION}")
endif()

# Get ROCm GPU architecture
set(OUTPUTFILE ${CMAKE_CURRENT_SOURCE_DIR}/rocm_script)
set(HIPFILE ${CMAKE_CURRENT_SOURCE_DIR}/check_cuda.hip.cu)

# Compile and run the architecture detection
execute_process(
    COMMAND ${HIP_HIPCC_EXECUTABLE} ${HIPFILE} -o ${OUTPUTFILE}
    RESULT_VARIABLE COMPILE_RESULT
    ERROR_QUIET
)

if(COMPILE_RESULT EQUAL 0)
    execute_process(
        COMMAND ${OUTPUTFILE}
        RESULT_VARIABLE HIP_RETURN_CODE
        OUTPUT_VARIABLE ARCH_OUTPUT
        ERROR_QUIET
    )
    file(REMOVE ${OUTPUTFILE})
else()
    set(HIP_RETURN_CODE 1)
    set(ARCH_OUTPUT "Failed to compile architecture detection")
endif()

if(${HIP_RETURN_CODE} EQUAL 0)
    set(HIP_SUCCESS "TRUE")
    # The check script now directly outputs the gfx architecture
    string(STRIP "${ARCH_OUTPUT}" ROCM_ARCH)
    # Validate that we got a proper gfx architecture
    if(NOT ROCM_ARCH MATCHES "^gfx[0-9]+")
        set(ROCM_ARCH "gfx906")  # Default to Vega 20 if invalid
    endif()
else()
    set(HIP_SUCCESS "FALSE")
    set(ROCM_ARCH "gfx906")  # Default architecture
endif()

# Multi-architecture support
if(${MULTI_ARCH})
    message(STATUS "Multi-architecture GPU build enabled: gfx803, gfx900, gfx906, gfx908, gfx90a, gfx1030")
    set(HIP_ARCHITECTURES "gfx803;gfx900;gfx906;gfx908;gfx90a;gfx1030")
    message(STATUS "ROCm Version: ${HIP_VERSION}")
    message(STATUS "ROCm Path: ${HIP_ROOT_DIR}")
elseif(${HIP_SUCCESS})
    message(STATUS "ROCm Architecture: ${ROCM_ARCH}")
    message(STATUS "ROCm Version: ${HIP_VERSION}")
    message(STATUS "ROCm Path: ${HIP_ROOT_DIR}")
    set(HIP_ARCHITECTURES ${ROCM_ARCH})
else()
    message(WARNING "Failed to detect ROCm architecture: ${ARCH_OUTPUT}")
    message(STATUS "Using default architecture: ${ROCM_ARCH}")
    set(HIP_ARCHITECTURES ${ROCM_ARCH})
endif()

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
else()
    message("Building ROCm backend in ${CMAKE_BUILD_TYPE}")
endif()

# Add OpenMP support
find_package(OpenMP REQUIRED)

# Enable HIP language
enable_language(HIP)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_HIP_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS} -fopenmp=libomp")

# ROCm/HIP specific compiler flags
set(CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS} ${OpenMP_CXX_FLAGS}")
set(CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS} -fPIC")
set(CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS} -std=c++17 -fopenmp=libomp")

# Set architecture-specific flags
if(${MULTI_ARCH})
    foreach(arch IN LISTS HIP_ARCHITECTURES)
        set(CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS} --offload-arch=${arch}")
    endforeach()
else()
    set(CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS} --offload-arch=${ROCM_ARCH}")
endif()

# Architecture preprocessor definition
string(REPLACE "gfx" "" ROCM_ARCH_NUM "${ROCM_ARCH}")
add_compile_definitions(ROCM_ARCH=${ROCM_ARCH_NUM})

# Check if the DEBUG flag is defined
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    # Debug mode
    message("Compiling in Debug mode")
    add_definitions(-DDEBUG)
    set(CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS} -O0 -g")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O0 -g")
else()
    # Release mode
    message("Compiling in Release mode")
    set(CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS} -O3")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3")
endif()

# Check if the USE_ROCPROF environment variable is set (ROCm equivalent of nvtools)
if(${USE_ROCPROF})
    message(STATUS "USE_ROCPROF is enabled")
    add_definitions(-DUSE_ROCPROF)
    find_library(ROCTRACER_LIBRARY roctracer64 HINTS ${HIP_ROOT_DIR}/lib)
    if(ROCTRACER_LIBRARY)
        message(STATUS "Found ROCTracer: ${ROCTRACER_LIBRARY}")
    endif()
endif()

# ROCm/HIP specific optimizations
set(CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS} -munsafe-fp-atomics")
set(CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS} -ffast-math")

set(INCLUDE_DIR include)

add_subdirectory(src)
enable_testing()
add_subdirectory(tests_and_benchmarks)
target_include_directories(tfhe_rocm_backend PRIVATE ${INCLUDE_DIR})

# This is required for rust cargo build
install(TARGETS tfhe_rocm_backend DESTINATION .)

install(TARGETS tfhe_rocm_backend DESTINATION lib)

# Define a function to add a lint target.
find_file(CPPLINT NAMES cpplint cpplint.exe)
if(CPPLINT)
    # Add a custom target to lint all child projects. Dependencies are specified in child projects.
    add_custom_target(all_lint)
    # Don't trigger this target on ALL_BUILD or Visual Studio 'Rebuild Solution'
    set_target_properties(all_lint PROPERTIES EXCLUDE_FROM_ALL TRUE)
    # set_target_properties(all_lint PROPERTIES EXCLUDE_FROM_DEFAULT_BUILD TRUE)
endif()
