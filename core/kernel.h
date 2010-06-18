/**
 * @file
 *
 *
 *
 * @author Arne Vansteenkiste, Ben Van de Wiele
 *
 */
#ifndef KERNEL_H
#define KERNEL_H

#include "tensor.h"
#include "param.h"
#include "gpu_micromag3d_kernel.h"

#ifdef __cplusplus
extern "C" {
#endif


tensor* init_kernel(param*);


#ifdef __cplusplus
}
#endif
#endif