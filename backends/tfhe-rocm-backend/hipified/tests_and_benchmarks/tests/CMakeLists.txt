project(test_tfhe_rocm_backend LANGUAGES CXX)

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

include(FetchContent)
FetchContent_Declare(googletest
                     URL https://github.com/google/googletest/archive/03597a01ee50ed33e9dfd640b249b4be3799d395.zip)

# For Windows: Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt
    ON
    CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

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
include_directories(${TFHE_RS_BINARY_DIR})
include_directories(${TFHE_RS_BINARY_DIR}/deps)
include_directories("${CMAKE_CURRENT_SOURCE_DIR}")
include_directories("${HIP_ROOT_DIR}/include")

add_library(tfhe_rs_lib STATIC IMPORTED)
add_dependencies(tfhe_rs_lib tfhe-rs)
set_target_properties(tfhe_rs_lib PROPERTIES IMPORTED_LOCATION ${TFHE_RS_BINARY_DIR}/libtfhe.a)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wl,--no-as-needed -ldl")

set(BINARY test_tfhe_rocm_backend)

file(
    GLOB_RECURSE TEST_SOURCES
    LIST_DIRECTORIES false
    test_*.cpp)

add_executable(${BINARY} ${TEST_SOURCES} ../utils.cpp ../setup_and_teardown.cpp)

add_test(NAME ${BINARY} COMMAND ${BINARY})

set_target_properties(${BINARY} PROPERTIES 
    HIP_SEPARABLE_COMPILATION ON 
    HIP_RESOLVE_DEVICE_SYMBOLS ON
    POSITION_INDEPENDENT_CODE ON)
target_link_libraries(${BINARY} PUBLIC GTest::gtest_main tfhe_rs_lib tfhe_rocm_backend hip::host)

include(GoogleTest)
gtest_discover_tests(${BINARY})
