//  This file is part of MuMax, a high-perfomrance micromagnetic simulator.
//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.

package device


import ()


type MultiGpu struct {
	gpuid    []int                 // IDs of the GPUs in the multi-GPU pool
	curraddr uintptr               // counter for making unique fake adresses in the multi-GPU memory space
	mmap     map[uintptr][]uintptr // maps each fake address of the multi-GPU memory space to adresses on each of the sub-devices
	msize    map[uintptr]int       // stores the length (in number of floats) of the alloctad storage of fake multi-GPU addresses
}

func NewMultiGpu(gpuids []int) *MultiGpu {
	d := new(MultiGpu)
	d.gpuid = gpuids
	d.mmap = make(map[uintptr][]uintptr)
	return d
}

// Returns the number of sub-devices in this multi-device.
func (d *MultiGpu) NDev() int {
	return len(d.gpuid)
}


// func (d *MultiGpu) init() {
// 	C.gpu_init()
// }
// 
//func (d *MultiGpu) setDevice(devid int) {
//	panic(Bug("MultiGpu.setDevice() is illegal"))
//}
// 
// 
// func (d *MultiGpu) add(a, b uintptr, N int) {
// 	C.gpu_add((*C.float)(unsafe.Pointer(a)), (*C.float)(unsafe.Pointer(b)), C.int(N))
// }
// 
// func (d *MultiGpu) madd(a uintptr, cnst float32, b uintptr, N int) {
// 	C.gpu_madd((*C.float)(unsafe.Pointer(a)), C.float(cnst), (*C.float)(unsafe.Pointer(b)), C.int(N))
// }
// 
// func (d *MultiGpu) linearCombination(a, b uintptr, weightA, weightB float32, N int) {
// 	C.gpu_linear_combination((*C.float)(unsafe.Pointer(a)), (*C.float)(unsafe.Pointer(b)), C.float(weightA), C.float(weightB), C.int(N))
// }
// 
// func (d *MultiGpu) addConstant(a uintptr, cnst float32, N int) {
// 	C.gpu_add_constant((*C.float)(unsafe.Pointer(a)), C.float(cnst), C.int(N))
// }
// 
// func (d *MultiGpu) reduce(operation int, input, output uintptr, buffer *float32, blocks, threads, N int) float32 {
// 	return float32(C.gpu_reduce(C.int(operation), (*C.float)(unsafe.Pointer(input)), (*C.float)(unsafe.Pointer(output)), (*C.float)(unsafe.Pointer(buffer)), C.int(blocks), C.int(threads), C.int(N)))
// }
// 
// func (d *MultiGpu) normalize(m uintptr, N int) {
// 	C.gpu_normalize_uniform((*C.float)(unsafe.Pointer(m)), C.int(N))
// }
// 
// func (d *MultiGpu) normalizeMap(m, normMap uintptr, N int) {
// 	C.gpu_normalize_map((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(normMap)), C.int(N))
// }
// 
// func (d *MultiGpu) deltaM(m, h uintptr, alpha, dtGilbert float32, N int) {
// 	C.gpu_deltaM((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(h)), C.float(alpha), C.float(dtGilbert), C.int(N))
// }
// 
// func (d *MultiGpu) semianalStep(m, h uintptr, dt, alpha float32, order, N int) {
// 	switch order {
// 	default:
// 		panic(fmt.Sprintf("Unknown semianal order:", order))
// 	case 0:
// 		C.gpu_anal_fw_step_unsafe((*C.float)(unsafe.Pointer(m)), (*C.float)(unsafe.Pointer(h)), C.float(dt), C.float(alpha), C.int(N))
// 	}
// }
// 
// 
// func (d *MultiGpu) kernelMul(mx, my, mz, kxx, kyy, kzz, kyz, kxz, kxy uintptr, kerneltype, nRealNumbers int) {
// 	switch kerneltype {
// 	default:
// 		panic(fmt.Sprintf("Unknown kernel type:", kerneltype))
// 	case 6:
// 		C.gpu_kernelmul6(
// 			(*C.float)(unsafe.Pointer(mx)), (*C.float)(unsafe.Pointer(my)), (*C.float)(unsafe.Pointer(mz)),
// 			(*C.float)(unsafe.Pointer(kxx)), (*C.float)(unsafe.Pointer(kyy)), (*C.float)(unsafe.Pointer(kzz)),
// 			(*C.float)(unsafe.Pointer(kyz)), (*C.float)(unsafe.Pointer(kxz)), (*C.float)(unsafe.Pointer(kxy)),
// 			C.int(nRealNumbers))
// 	}
// }
// 
// 
// func (d *MultiGpu) copyPadded(source, dest uintptr, sourceSize, destSize []int, direction int) {
// 	switch direction {
// 	default:
// 		panic(fmt.Sprintf("Unknown padding direction:", direction))
// 	case CPY_PAD:
// 		C.gpu_copy_pad((*C.float)(unsafe.Pointer(source)), (*C.float)(unsafe.Pointer(dest)),
// 			C.int(sourceSize[0]), C.int(sourceSize[1]), C.int(sourceSize[2]),
// 			C.int(destSize[0]), C.int(destSize[1]), C.int(destSize[2]))
// 	case CPY_UNPAD:
// 		C.gpu_copy_unpad((*C.float)(unsafe.Pointer(source)), (*C.float)(unsafe.Pointer(dest)),
// 			C.int(sourceSize[0]), C.int(sourceSize[1]), C.int(sourceSize[2]),
// 			C.int(destSize[0]), C.int(destSize[1]), C.int(destSize[2]))
// 	}
// }
// 
// 
// func (d *MultiGpu) newFFTPlan(dataSize, logicSize []int) uintptr {
// 	Csize := (*C.int)(unsafe.Pointer(&dataSize[0]))
// 	CpaddedSize := (*C.int)(unsafe.Pointer(&logicSize[0]))
// 	return uintptr(unsafe.Pointer(C.new_gpuFFT3dPlan_padded(Csize, CpaddedSize)))
// }
// 
// 
// func (d *MultiGpu) fft(plan uintptr, in, out uintptr, direction int) {
// 	switch direction {
// 	default:
// 		panic(fmt.Sprintf("Unknown FFT direction:", direction))
// 	case FFT_FORWARD:
// 		C.gpuFFT3dPlan_forward((*C.gpuFFT3dPlan)(unsafe.Pointer(plan)), (*C.float)(unsafe.Pointer(in)), (*C.float)(unsafe.Pointer(out)))
// 	case FFT_INVERSE:
// 		C.gpuFFT3dPlan_inverse((*C.gpuFFT3dPlan)(unsafe.Pointer(plan)), (*C.float)(unsafe.Pointer(in)), (*C.float)(unsafe.Pointer(out)))
// 	}
// }
// 
//

//func (d *MultiGpu) newArray(nFloats int) uintptr {
//	d.curraddr++
//	fakeaddr := d.curraddr
//
//	d.mmap[fakeaddr] = make([]uintptr, d.NDev())
//	d.msize[fakeaddr] = nFloats
//
//	subaddr := d.mmap[fakeaddr]
//	assert(nFloats%d.NDev() == 0)
//	subsize := nFloats / d.NDev()
//	for i := range subaddr {
//		subaddr[i] = func() uintptr {
//			//runtime.LockOSThread()
//			GPU.setDevice(d.gpuid[i])
//			return GPU.newArray(subsize)
//		}()
//	}
//
//	return fakeaddr
//}

// func (d *MultiGpu) freeArray(ptr uintptr) {
// 	C.free_gpu_array((*C.float)(unsafe.Pointer(ptr)))
// }
// 
// func (d *MultiGpu) memcpy(source, dest uintptr, nFloats, direction int) {
// 	C.memcpy_gpu_dir((*C.float)(unsafe.Pointer(source)), (*C.float)(unsafe.Pointer(dest)), C.int(nFloats), C.int(direction))
// }
// 
// 
// func (d *MultiGpu) arrayOffset(array uintptr, index int) uintptr {
//   size := d.msize[array]
//   assert(index < size)
//   
//   dev := (index * d.NDev()) / size
//   devidx := (index * d.NDev()) % size
//   
//   return uintptr(d.mmap[array][dev] + uintptr(SIZEOF_CFLOAT * index))
// }
// 
// func (d *MultiGpu) Stride() int {
// 	return int(C.gpu_stride_float())
// }
// 
// func (d *MultiGpu) overrideStride(nFloats int) {
// 	C.gpu_override_stride(C.int(nFloats))
// }
// 
// func (d *MultiGpu) zero(data uintptr, nFloats int) {
// 	C.gpu_zero((*C.float)(unsafe.Pointer(data)), C.int(nFloats))
// }
// 
// func (d *MultiGpu) UsedMem() uint64 {
// 	return uint64(C.gpu_usedmem())
// }
// 
// func (d *MultiGpu) PrintProperties() {
// 	C.gpu_print_properties_stdout()
// }
// 
// 
// func (d *MultiGpu) String() string {
// 	return "GPU"
// }
// 
// func (d *MultiGpu) TimerPrintDetail() {
// 	C.timer_printdetail()
// }
