//  This file is part of MuMax, a high-performance micromagnetic simulator.
//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.

package gpu

/*
#include "../../../../gpukern/gpukern.h"
*/
import "C"
import "unsafe"
import "runtime"

// This single file interfaces all the relevant CUDA C functions with go.
// It only wraps the (unsafe) C functions, higher level (safe) versions
// are implemented in device.go.

import (
	. "mumax/common"
	"fmt"
)


type Gpu struct {
	// intentionally empty, but the methods implement sim.Device
}

// Initializes the GPU to use device number "gpu_id",
// with maximum "threads" threads per thread block.
// The options flag is currently not used. 
func Init(gpu_id, threads, options int) Gpu {
	gpu := Gpu{}
	gpu.setDevice(gpu_id)
	gpu.init(threads, options)
	return gpu
}

func MaxThreads() int {
	return int(C.gpu_maxthreads())
}

// INTERNAL
func (d Gpu) init(threads, options int) {
	C.gpu_init(C.int(threads), C.int(options))
}

// Selects a GPU by number if more than one is present.
// (Counting starts from 0, which is the default GPU)
func (d Gpu) setDevice(devid int) {
	// a CUDA context is linked to a thread, and a context created in
	// one thread can not be accessed by another one. Therefore, we
	// have to lock the current goroutine to its current thread.
	// Otherwise it may be mapped to another thread by the go runtime,
	// making CUDA crash.
	// Debugvv("Locked OS thread")
	runtime.LockOSThread()
	C.gpu_set_device(C.int(devid))
}


func (d Gpu) Add(a, b uintptr, N int) {
	C.gpu_add((*C.float)(unsafe.Pointer(a)), (*C.float)(unsafe.Pointer(b)), C.int(N))
}

func (d Gpu) Madd(a uintptr, cnst float32, b uintptr, N int) {
	C.gpu_madd((*C.float)(unsafe.Pointer(a)), C.float(cnst), (*C.float)(unsafe.Pointer(b)), C.int(N))
}

func (d Gpu) Madd2(a, b, c uintptr, N int) {
	C.gpu_madd2((*C.float)(unsafe.Pointer(a)), (*C.float)(unsafe.Pointer(b)), (*C.float)(unsafe.Pointer(c)), C.int(N))
}

//func (c Gpu) addLinAnis(hx, hy, hz, mx, my, mz, kxx, kyy, kzz, kyz, kxz, kxy uintptr, N int) {
//	C.gpu_add_lin_anisotropy(
//		(*C.float)(unsafe.Pointer(hx)), (*C.float)(unsafe.Pointer(hy)), (*C.float)(unsafe.Pointer(hz)),
//		(*C.float)(unsafe.Pointer(mx)), (*C.float)(unsafe.Pointer(my)), (*C.float)(unsafe.Pointer(mz)),
//		(*C.float)(unsafe.Pointer(kxx)), (*C.float)(unsafe.Pointer(kyy)), (*C.float)(unsafe.Pointer(kzz)),
//		(*C.float)(unsafe.Pointer(kyz)), (*C.float)(unsafe.Pointer(kxz)), (*C.float)(unsafe.Pointer(kxy)),
//		(C.int)(N))
//}

func (d Gpu) LinearCombination(a, b uintptr, weightA, weightB float32, N int) {
	C.gpu_linear_combination((*C.float)(unsafe.Pointer(a)), (*C.float)(unsafe.Pointer(b)), C.float(weightA), C.float(weightB), C.int(N))
}

//func (d Gpu) LinearCombinationMany(result uintptr, vectors []uintptr, weights []float32, NElem int) {
//	C.gpu_linear_combination_many(
//		(*C.float)(unsafe.Pointer(result)),
//		(**C.float)(unsafe.Pointer(&vectors[0])),
//		(*C.float)(unsafe.Pointer(&weights[0])),
//		(C.int)(len(vectors)),
//		(C.int)(NElem))
//}

func (d Gpu) AddConstant(a uintptr, cnst float32, N int) {
	C.gpu_add_constant((*C.float)(unsafe.Pointer(a)), C.float(cnst), C.int(N))
}

func (d Gpu) Reduce(operation int, input, output uintptr, buffer *float32, blocks, threads, N int) float32 {
	return float32(C.gpu_reduce(C.int(operation), (*C.float)(unsafe.Pointer(input)), (*C.float)(unsafe.Pointer(output)), (*C.float)(unsafe.Pointer(buffer)), C.int(blocks), C.int(threads), C.int(N)))
}

func (d Gpu) Normalize(m uintptr, N int) {
	C.gpu_normalize_uniform((*C.float)(unsafe.Pointer(m)), C.int(N))
}

func (d Gpu) NormalizeMap(m, normMap uintptr, N int) {
	C.gpu_normalize_map((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(normMap)), C.int(N))
}

func (d Gpu) LLDeltaM(m, h uintptr, alpha, dtGilbert float32, N int) {
	C.gpu_deltaM((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(h)), C.float(alpha), C.float(dtGilbert), C.int(N))
}

func (d Gpu) LLBDeltaM(m, h uintptr, alpha, beta, epsillon float32, u []float32, dtGilb float32, size []int) {
	C.gpu_spintorque_deltaM((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(h)), C.float(alpha), C.float(beta), C.float(epsillon), (*C.float)(unsafe.Pointer(&u[0])), C.float(dtGilb), C.int(size[0]), C.int(size[1]), C.int(size[2]))
}

//func (d Gpu) AddLocalFields(m, h uintptr, Hext []float32, anisType int, anisK []float32, anisAxes []float32, N int) {
//	C.gpu_add_local_fields((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(h)), C.int(N), (*C.float)(unsafe.Pointer(&Hext[0])), C.int(anisType), (*C.float)(unsafe.Pointer(&anisK[0])), (*C.float)(unsafe.Pointer(&anisAxes[0])))
//}

// func (d Gpu) semianalStep(m, h uintptr, dt, alpha float32, order, N int) {
// 	switch order {
// 	default:
// 		panic(fmt.Sprintf("Unknown semianal order:", order))
// 	case 0:
// 		C.gpu_anal_fw_step((C.float)(dt), (C.float)(alpha), (C.int)(N), (*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(h)))
// 	}
// }

//func (d Gpu) SemianalStep(min, mout, h uintptr, dt, alpha float32, N int) {
//	C.gpu_anal_fw_step((C.float)(dt), (C.float)(alpha), (C.int)(N), (*C.float)(unsafe.Pointer(min)), (*C.float)(unsafe.Pointer(mout)), (*C.float)(unsafe.Pointer(h)))
//}


func (d Gpu) KernelMul(mx, my, mz, kxx, kyy, kzz, kyz, kxz, kxy uintptr, kerneltype, nRealNumbers int) {
	switch kerneltype {
	default:
		panic(fmt.Sprintf("Unknown kernel type:", kerneltype))
	case 6:
		C.gpu_kernelmul6(
			(*C.float)(unsafe.Pointer(mx)), (*C.float)(unsafe.Pointer(my)), (*C.float)(unsafe.Pointer(mz)),
			(*C.float)(unsafe.Pointer(kxx)), (*C.float)(unsafe.Pointer(kyy)), (*C.float)(unsafe.Pointer(kzz)),
			(*C.float)(unsafe.Pointer(kyz)), (*C.float)(unsafe.Pointer(kxz)), (*C.float)(unsafe.Pointer(kxy)),
			C.int(nRealNumbers))
	case 4:
		C.gpu_kernelmul4(
			(*C.float)(unsafe.Pointer(mx)), (*C.float)(unsafe.Pointer(my)), (*C.float)(unsafe.Pointer(mz)),
			(*C.float)(unsafe.Pointer(kxx)), (*C.float)(unsafe.Pointer(kyy)), (*C.float)(unsafe.Pointer(kzz)),
			(*C.float)(unsafe.Pointer(kyz)),
			C.int(nRealNumbers))
	}
}


func (d Gpu) CopyPadded(source, dest uintptr, sourceSize, destSize []int, direction int) {
	switch direction {
	default:
		panic(fmt.Sprintf("Unknown padding direction:", direction))
	case CPY_PAD:
		C.gpu_copy_pad((*C.float)(unsafe.Pointer(source)), (*C.float)(unsafe.Pointer(dest)),
			C.int(sourceSize[0]), C.int(sourceSize[1]), C.int(sourceSize[2]),
			C.int(destSize[0]), C.int(destSize[1]), C.int(destSize[2]))
	case CPY_UNPAD:
		C.gpu_copy_unpad((*C.float)(unsafe.Pointer(source)), (*C.float)(unsafe.Pointer(dest)),
			C.int(sourceSize[0]), C.int(sourceSize[1]), C.int(sourceSize[2]),
			C.int(destSize[0]), C.int(destSize[1]), C.int(destSize[2]))
	}
}


func (d Gpu) NewFFTPlan(dataSize, logicSize []int) uintptr {
	Csize := (*C.int)(unsafe.Pointer(&dataSize[0]))
	CpaddedSize := (*C.int)(unsafe.Pointer(&logicSize[0]))
	return uintptr(unsafe.Pointer(C.new_gpuFFT3dPlan_padded(Csize, CpaddedSize)))
}


func (d Gpu) FreeFFTPlan(plan uintptr) {
	C.delete_gpuFFT3dPlan((*C.gpuFFT3dPlan)(unsafe.Pointer(plan)))
}


func (d Gpu) Fft(plan uintptr, in, out uintptr, direction int) {
	switch direction {
	default:
		panic(fmt.Sprintf("Unknown FFT direction:", direction))
	case FFT_FORWARD:
		C.gpuFFT3dPlan_forward((*C.gpuFFT3dPlan)(unsafe.Pointer(plan)), (*C.float)(unsafe.Pointer(in)), (*C.float)(unsafe.Pointer(out)))
	case FFT_INVERSE:
		C.gpuFFT3dPlan_inverse((*C.gpuFFT3dPlan)(unsafe.Pointer(plan)), (*C.float)(unsafe.Pointer(in)), (*C.float)(unsafe.Pointer(out)))
	}
}


func (d Gpu) NewArray(components, nFloats int) []uintptr {
	list := uintptr(unsafe.Pointer(C.new_gpu_array(C.int(components * nFloats))))
	array := make([]uintptr, components)
	for i := range array {
		array[i] = ArrayOffset(list, i*nFloats)
	}
	return array
}

func (d Gpu) FreeArray(ptr uintptr) {
	C.free_gpu_array((*C.float)(unsafe.Pointer(ptr)))
}

func (d Gpu) Memcpy(source, dest uintptr, nFloats, direction int) {
	C.memcpy_gpu_dir((*C.float)(unsafe.Pointer(source)), (*C.float)(unsafe.Pointer(dest)), C.int(nFloats), C.int(direction))
}


//func (d Gpu) Stride() int {
//	return int(C.gpu_stride_float())
//}

//func (d Gpu) overrideStride(nFloats int) {
//	C.gpu_override_stride(C.int(nFloats))
//}

func (d Gpu) Zero(data uintptr, nFloats int) {
	C.gpu_zero((*C.float)(unsafe.Pointer(data)), C.int(nFloats))
}

//func (d Gpu) UsedMem() uint64 {
//	return uint64(C.gpu_usedmem())
//}

//func (d Gpu) PrintProperties() {
//	C.gpu_print_properties_stdout()
//}


func (d Gpu) String() string {
	return "GPU"
}

func (d Gpu) TimerPrintDetail() {
	//C.timer_printdetail()
}
