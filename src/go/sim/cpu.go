//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.

package sim

/*
#include "../../cpukern/cpukern.h"
*/
import "C"
import "unsafe"

/**
 * This single file interfaces all the relevant FFTW/cpu functions with go
 * It only wraps the functions, higher level constructs and assetions
 * are in separate files like fft.go, ...
 *
 * @note cgo does not seem to like many cgofiles, so I put everything together here.
 * @author Arne Vansteenkiste
 */

import (
	. "mumax/common"
	"fmt"
	"os"
)

var CPU *Backend = NewBackend(&Cpu{})

type Cpu struct {
	// intentionally empty, but the methods implement sim.Device
}

func (d Cpu) maxthreads() int {
	return int(C.cpu_maxthreads())
}

func (d Cpu) init(threads, options int) {
	C.cpu_init(C.int(threads), C.int(options))
}

func (d Cpu) setDevice(devid int) {
	fmt.Fprintln(os.Stderr, "setDevice(", devid, ") has no effect on CPU")
}

func (d Cpu) add(a, b uintptr, N int) {
	C.cpu_add((*C.float)(unsafe.Pointer(a)), (*C.float)(unsafe.Pointer(b)), C.int(N))
}

func (d Cpu) madd(a uintptr, cnst float32, b uintptr, N int) {
	C.cpu_madd((*C.float)(unsafe.Pointer(a)), C.float(cnst), (*C.float)(unsafe.Pointer(b)), C.int(N))
}

func (d Cpu) madd2(a, b, c uintptr, N int) {
	panic(Bug("unimplemented"))
	//C.cpu_madd2((*C.float)(unsafe.Pointer(a)), (*C.float)(unsafe.Pointer(b)), (*C.float)(unsafe.Pointer(c)), C.int(N))
}

func (c Cpu) addLinAnis(hx, hy, hz, mx, my, mz, kxx, kyy, kzz, kyz, kxz, kxy uintptr, N int) {
	panic(Bug("unimplemented"))
}

func (d Cpu) linearCombination(a, b uintptr, weightA, weightB float32, N int) {
	C.cpu_linear_combination((*C.float)(unsafe.Pointer(a)), (*C.float)(unsafe.Pointer(b)), C.float(weightA), C.float(weightB), C.int(N))
}

func (d Cpu) linearCombinationMany(result uintptr, vectors []uintptr, weights []float32, NElem int) {
	panic("unimplemented")
	//   C.cpu_linear_combination_many(
	//     (*C.float)(unsafe.Pointer(result)),
	//     (**C.float)(unsafe.Pointer(&vectors[0])),
	//     (*C.float)(unsafe.Pointer(&weights[0])),
	//     (C.int)(NElem)
	//   )
}

func (d Cpu) scaledDotProduct(result, a, b uintptr, scale float32, N int) {
	C.cpu_scale_dot_product((*C.float)(unsafe.Pointer(result)), (*C.float)(unsafe.Pointer(a)), (*C.float)(unsafe.Pointer(b)), C.float(scale), C.int(N))
}

func (d Cpu) reduce(operation int, input, output uintptr, buffer *float32, blocks, threads, N int) float32 {
	return float32(C.cpu_reduce(C.int(operation), (*C.float)(unsafe.Pointer(input)), (*C.float)(unsafe.Pointer(output)), (*C.float)(unsafe.Pointer(buffer)), C.int(blocks), C.int(threads), C.int(N)))
	//panic("unimplemented")
}

func (d Cpu) addConstant(a uintptr, cnst float32, N int) {
	C.cpu_add_constant((*C.float)(unsafe.Pointer(a)), C.float(cnst), C.int(N))
}

func (d Cpu) normalize(m uintptr, N int) {
	C.cpu_normalize_uniform((*C.float)(unsafe.Pointer(m)), C.int(N))
}

func (d Cpu) normalizeMap(m, normMap uintptr, N int) {
	C.cpu_normalize_map((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(normMap)), C.int(N))
}

func (d Cpu) deltaM(m, h uintptr, alpha float32, alphaMask *DevTensor, dtGilbert float32, N int) {
	var alphaMap unsafe.Pointer
	if alphaMask != nil {
		alphaMap = unsafe.Pointer(alphaMask.data)
	}
	C.cpu_deltaM((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(h)), C.float(alpha), (*C.float)(alphaMap), C.float(dtGilbert), C.int(N))
}

func (d Cpu) spintorqueDeltaM(m, h uintptr, alpha, beta, epsillon float32, u []float32, jMask *DevTensor, dtGilb float32, size []int) {
	//C.cpu_spintorque_deltaM((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(h)), C.float(alpha),  C.float(beta),  C.float(epsillon), (*C.float)(unsafe.Pointer(&u[0])), C.float(dtGilb), C.int(size[0]), C.int(size[1]), C.int(size[2]))
	panic(Bug("spin torque not implemented on CPU"))
}

func (d Cpu) addLocalFields(m, h uintptr, Hext []float32, hMask *DevTensor, anisType int, anisK []float32, anisAxes []float32, N int) {
	// hMask may be nil, then hMap must be NULL
	var hMap unsafe.Pointer
	if hMask != nil {
		hMap = unsafe.Pointer(hMask.data)
	}
	C.cpu_add_local_fields((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(h)), C.int(N), (*C.float)(unsafe.Pointer(&Hext[0])), (*C.float)(hMap), C.int(anisType), (*C.float)(unsafe.Pointer(&anisK[0])), (*C.float)(unsafe.Pointer(&anisAxes[0])))
}

func (d Cpu) addLocalFieldsPhi(m, h, phi uintptr, Hext []float32, hMask *DevTensor, anisType int, anisK []float32, anisAxes []float32, N int) {
	// hMask may be nil, then hMap must be NULL
	var hMap unsafe.Pointer
	if hMask != nil {
		hMap = unsafe.Pointer(hMask.data)
	}
	C.cpu_add_local_fields_H_and_phi((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(h)), (*C.float)(unsafe.Pointer(phi)), C.int(N), (*C.float)(unsafe.Pointer(&Hext[0])), (*C.float)(hMap), C.int(anisType), (*C.float)(unsafe.Pointer(&anisK[0])), (*C.float)(unsafe.Pointer(&anisAxes[0])))
}

func (d Cpu) addExch(m, h uintptr, size, periodic, exchinconv []int, cellsize []float32, exchType int) {
	C.cpu_add_exch((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(h)), (*C.int)(unsafe.Pointer(&size[0])), (*C.int)(unsafe.Pointer(&periodic[0])), (*C.int)(unsafe.Pointer(&exchinconv[0])), (*C.float)(unsafe.Pointer(&cellsize[0])), C.int(exchType))
}

// func (d Cpu) semianalStep(min, mout, h uintptr, dt, alpha float32, N int) {
// 	switch order {
// 	default:
// 		panic(fmt.Sprintf("Unknown semianal order:", order))
// 	case 0:
// 		panic("unimplemented")
// 		//C.cpu_anal_fw_step_unsafe((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(h)), C.float(dt), C.float(alpha), C.int(N))
// 	}
// }

func (d Cpu) semianalStep(min, mout, h uintptr, dt, alpha float32, N int) {
	C.cpu_anal_fw_step((C.float)(dt), (C.float)(alpha), (C.int)(N), (*C.float)(unsafe.Pointer(min)), (*C.float)(unsafe.Pointer(mout)), (*C.float)(unsafe.Pointer(h)))
}

//___________________________________________________________________________________________________ Kernel multiplication


func (d Cpu) extractReal(complex, real uintptr, NReal int) {
	panic("deprecated")
	//C.cpu_extract_real((*C.float)(unsafe.Pointer(complex)), (*C.float)(unsafe.Pointer(real)), C.int(NReal))
}

func (d Cpu) kernelMul(mx, my, mz, kxx, kyy, kzz, kyz, kxz, kxy uintptr, kerneltype, nRealNumbers int) {
	switch kerneltype {
	default:
		panic(fmt.Sprintf("Unknown kernel type:", kerneltype))
	case 4:
		C.cpu_kernelmul4(
			(*C.float)(unsafe.Pointer(mx)), (*C.float)(unsafe.Pointer(my)), (*C.float)(unsafe.Pointer(mz)),
			(*C.float)(unsafe.Pointer(kxx)), (*C.float)(unsafe.Pointer(kyy)), (*C.float)(unsafe.Pointer(kzz)),
			(*C.float)(unsafe.Pointer(kyz)),
			C.int(nRealNumbers))
	case 6:
		C.cpu_kernelmul6(
			(*C.float)(unsafe.Pointer(mx)), (*C.float)(unsafe.Pointer(my)), (*C.float)(unsafe.Pointer(mz)),
			(*C.float)(unsafe.Pointer(kxx)), (*C.float)(unsafe.Pointer(kyy)), (*C.float)(unsafe.Pointer(kzz)),
			(*C.float)(unsafe.Pointer(kyz)), (*C.float)(unsafe.Pointer(kxz)), (*C.float)(unsafe.Pointer(kxy)),
			C.int(nRealNumbers))
	}

}

//___________________________________________________________________________________________________ Copy-pad


func (d Cpu) copyPadded(source, dest uintptr, sourceSize, destSize []int, direction int) {
	switch direction {
	default:
		panic(fmt.Sprintf("Unknown padding direction:", direction))
	case CPY_PAD:
		C.cpu_copy_pad((*C.float)(unsafe.Pointer(source)), (*C.float)(unsafe.Pointer(dest)),
			C.int(sourceSize[0]), C.int(sourceSize[1]), C.int(sourceSize[2]),
			C.int(destSize[0]), C.int(destSize[1]), C.int(destSize[2]))
	case CPY_UNPAD:
		C.cpu_copy_unpad((*C.float)(unsafe.Pointer(source)), (*C.float)(unsafe.Pointer(dest)),
			C.int(sourceSize[0]), C.int(sourceSize[1]), C.int(sourceSize[2]),
			C.int(destSize[0]), C.int(destSize[1]), C.int(destSize[2]))
	}
}

//___________________________________________________________________________________________________ FFT


// unsafe creation of C fftPlan INPLACE
// TODO outplace, check placeness
func (d Cpu) newFFTPlan(dataSize, logicSize []int) uintptr {
	Csize := (*C.int)(unsafe.Pointer(&dataSize[0]))
	CpaddedSize := (*C.int)(unsafe.Pointer(&logicSize[0]))
	return uintptr(unsafe.Pointer(C.new_cpuFFT3dPlan(Csize, CpaddedSize)))
}

func (d Cpu) freeFFTPlan(plan uintptr) {
	//panic(Bug("Unimplemented"))
	C.delete_cpuFFT3dPlan((*C.cpuFFT3dPlan)(unsafe.Pointer(plan)))
}

func (d Cpu) fft(plan uintptr, in, out uintptr, direction int) {
	switch direction {
	default:
		panic(fmt.Sprintf("Unknown FFT direction:", direction))
	case FFT_FORWARD:
		C.cpuFFT3dPlan_forward((*C.cpuFFT3dPlan)(unsafe.Pointer(plan)), (*C.float)(unsafe.Pointer(in)), (*C.float)(unsafe.Pointer(out)))
	case FFT_INVERSE:
		C.cpuFFT3dPlan_inverse((*C.cpuFFT3dPlan)(unsafe.Pointer(plan)), (*C.float)(unsafe.Pointer(in)), (*C.float)(unsafe.Pointer(out)))
	}
}

func (d Cpu) gaussianNoise(data uintptr, mean, stddev float32, N int) {
	panic("unimplemented")
	//C.cpu_gaussian_noise((*C.float)(unsafe.Pointer(data)), C.float(mean), C.float(stddev), C.int(N))
}
//_______________________________________________________________________________ GPU memory allocation

// Allocates an array of float32s on the CPU.
// By convention, GPU arrays are represented by an uintptr,
// while host arrays are *float32's.
func (d Cpu) newArray(nFloats int) uintptr {
	return uintptr(unsafe.Pointer(C.new_cpu_array(C.int(nFloats))))
}

func (d Cpu) freeArray(ptr uintptr) {
	C.free_cpu_array((*C.float)(unsafe.Pointer(ptr)))
}

func (d Cpu) memcpy(source, dest uintptr, nFloats, direction int) {
	C.cpu_memcpy((*C.float)(unsafe.Pointer(source)), (*C.float)(unsafe.Pointer(dest)), C.int(nFloats)) //direction is ignored, it's always "CPY_ON" because there is no separate device
}

// ///
// func (d Cpu) memcpyTo(source *float32, dest uintptr, nFloats int) {
// 	C.cpu_memcpy((*C.float)(unsafe.Pointer(source)), (*C.float)(dest), C.int(nFloats))
// }
//
// ///
// func (d Cpu) memcpyFrom(source uintptr, dest *float32, nFloats int) {
// 	C.cpu_memcpy((*C.float)(source), (*C.float)(unsafe.Pointer(dest)), C.int(nFloats))
// }
//
// ///
// func (d Cpu) memcpyOn(source, dest uintptr, nFloats int) {
// 	C.cpu_memcpy((*C.float)(source), (*C.float)(dest), C.int(nFloats))
//}

/// Gets one float32 from a GPU array
// func (d Cpu) arrayGet(array uintptr, index int) float32 {
// 	return float32(C.cpu_array_get((*C.float)(array), C.int(index)))
// }
//
// func (d Cpu) arraySet(array uintptr, index int, value float32) {
// 	C.cpu_array_set((*C.float)(array), C.int(index), C.float(value))
// }

func (d Cpu) arrayOffset(array uintptr, index int) uintptr {
	return uintptr(array + uintptr(SIZEOF_CFLOAT*index)) //return uintptr(unsafe.Pointer(C.cpu_array_offset((*C.float)(unsafe.Pointer(array)), C.int(index))))
}

//___________________________________________________________________________________________________ GPU Stride

// The GPU stride in number of float32s (!)
func (d Cpu) Stride() int {
	return int(C.cpu_stride_float())
}

// Takes an array size and returns the smallest multiple of Stride() where the array size fits in
// func(d Cpu) PadToStride(nFloats int) int{
//   return int(C.cpu_pad_to_stride(C.int(nFloats)));
// }

// Override the GPU stride, handy for debugging. -1 Means reset to the original GPU stride
func (d Cpu) overrideStride(nFloats int) {
	C.cpu_override_stride(C.int(nFloats))
}

//___________________________________________________________________________________________________ tensor utilities

/// Overwrite n float32s with zeros
func (d Cpu) zero(data uintptr, nFloats int) {
	C.cpu_zero((*C.float)(unsafe.Pointer(data)), C.int(nFloats))
}

func (d Cpu) UsedMem() uint64 {
	return 0 // meh
}

// Print the GPU properties to stdout
func (d Cpu) PrintProperties() {
	C.cpu_print_properties_stdout()
}

// //___________________________________________________________________________________________________ misc

func (d Cpu) String() string {
	return "CPU"
}

func (d Cpu) TimerPrintDetail() {
	//C.timer_printdetail()
}
