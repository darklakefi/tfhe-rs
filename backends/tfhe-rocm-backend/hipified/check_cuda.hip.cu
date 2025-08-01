
#include <hip/hip_runtime.h>
#include <stdio.h>

int main(int argc, char **argv) {
    hipDeviceProp_t dP;
    float min_cc = 3.0;

    int rc = hipGetDeviceProperties(&dP, 0);
    if (rc != hipSuccess) {
        hipError_t error = hipGetLastError();
        printf("ROCm/HIP error: %s", hipGetErrorString(error));
        return rc; /* Failure */
    }
    if ((dP.major + (dP.minor / 10)) < min_cc) {
        printf("Min Compute Capability of %2.1f required: %d.%d found\n Not "
               "Building ROCm Code",
               min_cc, dP.major, dP.minor);
        return 1; /* Failure */
    } else {
        // Map common CUDA compute capabilities to ROCm gfx architectures
        int compute_capability = dP.major * 10 + dP.minor;
        
        // Default mapping based on compute capability
        const char* gfx_arch;
        switch(compute_capability) {
            case 70:  // Pascal/Turing equivalent
            case 75:
                gfx_arch = "gfx906";  // Vega 20
                break;
            case 80:  // Ampere equivalent
                gfx_arch = "gfx908";  // MI100
                break;
            case 86:  // Newer Ampere equivalent
            case 89:
                gfx_arch = "gfx90a";  // MI200
                break;
            default:
                gfx_arch = "gfx906";  // Safe default
                break;
        }
        
        printf("%s", gfx_arch);
        return 0; /* Success */
    }
}
