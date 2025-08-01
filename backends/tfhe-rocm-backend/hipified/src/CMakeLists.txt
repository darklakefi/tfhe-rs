# Find all HIP source files (.hip.cu)
file(GLOB_RECURSE SOURCES "*.hip.cu")

# Debug: Print the found files
message(STATUS "Found HIP source files: ${SOURCES}")

# Ensure we have source files
if(NOT SOURCES)
    message(FATAL_ERROR "No .hip.cu source files found!")
endif()

# Explicitly set the language for .hip.cu files to be HIP
set_source_files_properties(${SOURCES} PROPERTIES LANGUAGE HIP)

# Create the ROCm backend library
add_library(tfhe_rocm_backend STATIC ${SOURCES})

# Set HIP-specific properties
set_target_properties(tfhe_rocm_backend PROPERTIES 
    HIP_SEPARABLE_COMPILATION ON
    HIP_RESOLVE_DEVICE_SYMBOLS ON
    POSITION_INDEPENDENT_CODE ON
    LINKER_LANGUAGE HIP)

# Link ROCm/HIP libraries
target_link_libraries(tfhe_rocm_backend PUBLIC hip::host OpenMP::OpenMP_CXX)
target_include_directories(tfhe_rocm_backend PRIVATE .)
