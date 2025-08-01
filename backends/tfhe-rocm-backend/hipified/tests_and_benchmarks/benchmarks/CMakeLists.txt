project(benchmark_tfhe_rocm_backend LANGUAGES CXX)

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

# Enable HIP language
enable_language(HIP)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Disable the Google Benchmark requirement on Google Test
set(BENCHMARK_ENABLE_GTEST_TESTS OFF)
set(BENCHMARK_ENABLE_TESTING OFF)

include(FetchContent)
FetchContent_Declare(
    googlebenchmark
    GIT_REPOSITORY https://github.com/google/benchmark.git
    GIT_TAG v1.7.1)
FetchContent_MakeAvailable(googlebenchmark)

# Enable ExternalProject CMake module
include(ExternalProject)

set(CONCRETE_ROCM_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../")

# Enable ExternalProject CMake module
include(ExternalProject)
set(TFHE_RS_SOURCE_DIR "${CMAKE_BINARY_DIR}/../../../../")
set(TFHE_RS_BINARY_DIR "${TFHE_RS_SOURCE_DIR}/target/release")

if(NOT TARGET tfhe-rs)
    ExternalProject_Add(
        tfhe-rs
        SOURCE_DIR ${TFHE_RS_SOURCE_DIR}
        BINARY_DIR ${TFHE_RS_SOURCE_DIR}
        BUILD_ALWAYS 1
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ${CMAKE_COMMAND} -E env CARGO_PROFILE=release make build_c_api
        INSTALL_COMMAND ""
        LOG_BUILD ON)
endif()

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../include)
include_directories(${CONCRETE_ROCM_SOURCE_DIR}/include)
include_directories(${CONCRETE_ROCM_SOURCE_DIR}/src)
include_directories(${TFHE_RS_BINARY_DIR})
include_directories(${TFHE_RS_BINARY_DIR}/deps)
include_directories("${CMAKE_CURRENT_SOURCE_DIR}")

find_package(OpenMP REQUIRED)
# Add the OpenMP flag to the compiler flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")

add_library(tfhe_rs_lib STATIC IMPORTED)
add_dependencies(tfhe_rs_lib tfhe-rs)
set_target_properties(tfhe_rs_lib PROPERTIES IMPORTED_LOCATION ${TFHE_RS_BINARY_DIR}/libtfhe.a)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wl,--no-as-needed -ldl")

set(BINARY benchmark_tfhe_rocm_backend)

file(
    GLOB_RECURSE BENCH_SOURCES
    LIST_DIRECTORIES false
    benchmark*.cpp main.cpp)

add_executable(${BINARY} ${BENCH_SOURCES} ../utils.cpp ../setup_and_teardown.cpp)

set_target_properties(benchmark_tfhe_rocm_backend PROPERTIES 
    HIP_SEPARABLE_COMPILATION ON 
    HIP_RESOLVE_DEVICE_SYMBOLS ON
    POSITION_INDEPENDENT_CODE ON)
target_link_libraries(
    benchmark_tfhe_rocm_backend
    PUBLIC benchmark::benchmark tfhe_rs_lib tfhe_rocm_backend OpenMP::OpenMP_CXX
    PRIVATE hip::host)
