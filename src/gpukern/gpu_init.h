/**
 * @file
 *
 * @author Arne Vansteenkiste
 * @author Ben Van de Wiele
 */
#ifndef gpu_init_h
#define gpu_init_h

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Does the necessary initialization before the GPU backend can be used
 */
void gpu_init(int threads,  ///< number of threads per block, 0 means autoset
              int options   ///< currently not used
              );

/**
 * Selects a GPU when more than one is present
 */
void gpu_set_device(int devid);

#ifdef __cplusplus
}
#endif
#endif
