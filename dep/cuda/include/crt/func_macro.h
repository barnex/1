/*
 * Copyright 1993-2008 NVIDIA Corporation.  All rights reserved.
 *
 * NOTICE TO USER:   
 *
 * This source code is subject to NVIDIA ownership rights under U.S. and 
 * international Copyright laws.  Users and possessors of this source code 
 * are hereby granted a nonexclusive, royalty-free license to use this code 
 * in individual and commercial software.
 *
 * NVIDIA MAKES NO REPRESENTATION ABOUT THE SUITABILITY OF THIS SOURCE 
 * CODE FOR ANY PURPOSE.  IT IS PROVIDED "AS IS" WITHOUT EXPRESS OR 
 * IMPLIED WARRANTY OF ANY KIND.  NVIDIA DISCLAIMS ALL WARRANTIES WITH 
 * REGARD TO THIS SOURCE CODE, INCLUDING ALL IMPLIED WARRANTIES OF 
 * MERCHANTABILITY, NONINFRINGEMENT, AND FITNESS FOR A PARTICULAR PURPOSE.
 * IN NO EVENT SHALL NVIDIA BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL, 
 * OR CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS 
 * OF USE, DATA OR PROFITS,  WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE 
 * OR OTHER TORTIOUS ACTION,  ARISING OUT OF OR IN CONNECTION WITH THE USE 
 * OR PERFORMANCE OF THIS SOURCE CODE.  
 *
 * U.S. Government End Users.   This source code is a "commercial item" as 
 * that term is defined at  48 C.F.R. 2.101 (OCT 1995), consisting  of 
 * "commercial computer  software"  and "commercial computer software 
 * documentation" as such terms are  used in 48 C.F.R. 12.212 (SEPT 1995) 
 * and is provided to the U.S. Government only as a commercial end item.  
 * Consistent with 48 C.F.R.12.212 and 48 C.F.R. 227.7202-1 through 
 * 227.7202-4 (JUNE 1995), all U.S. Government End Users acquire the 
 * source code with only those rights set forth herein. 
 *
 * Any use of this source code in individual and commercial software must 
 * include, in the user documentation and internal comments to the code,
 * the above Disclaimer and U.S. Government End Users Notice.
 */

#if !defined(__FUNC_MACRO_H__)
#define __FUNC_MACRO_H__

#if defined(__CUDABE__)

#define __func__(decl) \
        ___device__(static) decl
#define __device_func__(decl) \
        ___device__(static) decl

#else /* __CUDABE__ */

#if !defined(__CUDA_INTERNAL_COMPILATION__)

#error -- incorrect inclusion of a cudart header file

#endif /* !__CUDA_INTERNAL_COMPILATION__ */

#if defined(__cplusplus) && defined(__device_emulation) && !defined(__multi_core__)

#define __begin_host_func \
        }
#define __end_host_func \
        namespace __cuda_emu {
#define __host_device_call(f) \
        __cuda_emu::f

#else /* __cplusplus && __device_emulation && !__multi_core__ */

#define __begin_host_func
#define __end_host_func
#define __host_device_call(f) \
        f

#endif /* __cplusplus && __device_emulation !__multi_core__ */

#if defined(__APPLE__)

#define __func__(decl) \
        extern __attribute__((__weak_import__, __weak__)) decl; decl
#define __device_func__(decl) \
        static __attribute__((__unused__)) decl

#elif defined(__GNUC__)

#define __func__(decl) \
        extern __attribute__((__weak__)) decl; decl
#define __device_func__(decl) \
        static __attribute__((__unused__)) decl

#elif defined(_WIN32)

#define __func__(decl) \
        static decl
#define __device_func__(decl) \
        static decl

#endif /* __APPLE__ */

#endif /* CUDABE */

#endif /* __FUNC_MACRO_H__ */
