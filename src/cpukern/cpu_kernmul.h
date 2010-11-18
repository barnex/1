/**
 * @file
 *
 * @author Arne Vansteenkiste
 * @author Ben Van de Wiele
 */
#ifndef cpu_kernmul_h
#define cpu_kernmul_h

#ifdef __cplusplus
extern "C" {
#endif


/**
 * @internal
 * Extract only the real parts from an interleaved complex array.
 */
//void cpu_extract_real(float* complex, float* real, int NReal);


/**
 * @internal 
 * Kernel is symmetric.
 * The multiplication is in-place, fftMi is overwritten by fftHi
 */
void cpu_kernelmul6(float* fftMx,  float* fftMy,  float* fftMz,
                    float* fftKxx, float* fftKyy, float* fftKzz,
                    float* fftKyz, float* fftKxz, float* fftKxy,
                    int nRealNumbers);
/**
 * @internal 
 * Kernel is symmetric and Kxy = Kxz = 0.
 * The multiplication is in-place, fftMi is overwritten by fftHi
 */
void cpu_kernelmul4(float* fftMx,  float* fftMy,  float* fftMz,
                    float* fftKxx, float* fftKyy, float* fftKzz,
                    float* fftKyz,
                    int nRealNumbers);

#ifdef __cplusplus
}
#endif
#endif
