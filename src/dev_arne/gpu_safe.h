/**
 * @file
 *
 * gpu_safe() should be wrapped around cuda functions to check for a non-zero error status.
 *
 * @author Arne Vansteenkiste
 */
#ifndef gpu_safe_h
#define gpu_safe_h

#include <assert.h>
#include <cufft.h>

#ifdef __cplusplus
extern "C" {
#endif


/**
 * This macro function should be wrapped around cuda functions to check for a non-zero error status.
 * It will print an error message and abort when neccesary.
 * @code
 * gpu_safe( cudaMalloc(...) );
 * @endcode
 */
#define gpu_safe(s) { if(s != cudaSuccess) { fprintf(stderr, "received CUDA error: %s\n", cudaGetErrorString((cudaError_t)s)); assert(s == 0);}}

/**
 * Safe wrapper around cudaThreadSynchronize(), aborts on error.
 */
#define gpu_sync() gpu_safe(cudaThreadSynchronize())

///@internal
char* cufftGetErrorString(cufftResult s);


/**
 * This macro function should be wrapped around cuda FFT functions to check for a non-zero error status.
 * It will print an error message and abort when neccesary.
 * @code
 * gpu_safefft( cudafft_exec(...) );
 * @endcode
 */
#define gpu_safefft(s) { if(s != CUFFT_SUCCESS) { fprintf(stderr, "received CUFFT error: %s\n", cufftGetErrorString((cufftResult)s)); assert(s == 0);}}

#ifdef __cplusplus
}
#endif
#endif
