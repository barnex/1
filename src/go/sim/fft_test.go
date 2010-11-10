//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.

package sim

import (
	"testing"
	"tensor"
	"fmt"
	"os"
	"rand"
)

var backend = GPU

var fft_test_sizes [][]int = [][]int{
	[]int{1, 8, 8}}//,
//   []int{2, 4, 8},
//   []int{1, 32, 64}}


func TestFFTPadded(t *testing.T) {
/*
	for _, size := range fft_test_sizes {

		paddedsize := padSize(size)

		fft := NewFFTPadded(backend, size, paddedsize)
		fftP := NewFFT(backend, paddedsize) // with manual padding

		fmt.Println(fft)
		fmt.Println(fftP)

		outsize := fftP.PhysicSize()

		dev, devT, devTT := NewTensor(backend, size), NewTensor(backend, outsize), NewTensor(backend, size)
		devP, devPT, devPTT := NewTensor(backend, paddedsize), NewTensor(backend, outsize), NewTensor(backend, paddedsize)

		host, hostT, hostTT := tensor.NewT(size), tensor.NewT(outsize), tensor.NewT(size)
		hostP, hostPT, hostPTT := tensor.NewT(paddedsize), tensor.NewT(outsize), tensor.NewT(paddedsize)

   host.List()[0] = 1.
		for i := 0; i < size[0]; i++ {
			for j := 0; j < size[1]; j++ {
				for k := 0; k < size[2]; k++ {
					//host.List()[i*size[1]*size[2]+j*size[2]+k] = 1. //rand.Float() //1.
					hostP.List()[i*paddedsize[1]*paddedsize[2]+j*paddedsize[2]+k] = host.List()[i*size[1]*size[2]+j*size[2]+k]
				}
			}
		}

		TensorCopyTo(host, dev)
		TensorCopyTo(hostP, devP)

		fft.Forward(dev, devT)
		TensorCopyFrom(devT, hostT)

		fftP.Forward(devP, devPT)
		TensorCopyFrom(devPT, hostPT)

		fft.Inverse(devT, devTT)
		TensorCopyFrom(devTT, hostTT)

		fftP.Inverse(devPT, devPTT)
		TensorCopyFrom(devPTT, hostPTT)

    fmt.Println("in:")
    host.WriteTo(os.Stdout)


    fmt.Println("out(padded):")
    hostT.WriteTo(os.Stdout)


    fmt.Println("backtransformed:")
    hostTT.WriteTo(os.Stdout)

  
    
		var (
			errorTT  float32 = 0
			errorPTT float32 = 0
			errorTPT float32 = 0
		)
		fmt.Println("normalization:", fft.Normalization(), fftP.Normalization())
		for i := range hostTT.List() {
			hostTT.List()[i] /= float32(fft.Normalization())
			if abs(host.List()[i]-hostTT.List()[i]) > errorTT {
				errorTT = abs(host.List()[i] - hostTT.List()[i])
			}
		}
		for i := range hostPTT.List() {
			hostPTT.List()[i] /= float32(fftP.Normalization())
			if abs(hostP.List()[i]-hostPTT.List()[i]) > errorPTT {
				errorPTT = abs(hostP.List()[i] - hostPTT.List()[i])
			}
		}
		for i := range hostPT.List() {
			if abs(hostPT.List()[i]-hostT.List()[i]) > errorTPT {
				errorTPT = abs(hostPT.List()[i] - hostT.List()[i])
			}
		}
		//tensor.Format(os.Stdout, host2)
		fmt.Println("transformed² FFT error:                    ", errorTT)
		fmt.Println("padded+transformed² FFT error:             ", errorPTT)
		fmt.Println("transformed - padded+transformed FFT error:", errorTPT)
		if errorTT > 1E-4 || errorTPT > 1E-4 || errorPTT > 1E-4 {
			t.Fail()
		}
	}*/

}


func TestFFT(t *testing.T) {


  for _, size := range fft_test_sizes {


    fft := NewFFT(backend, size)
    fmt.Println(fft)
    outsize := fft.PhysicSize()

    dev, devT, devTT := NewTensor(backend, size), NewTensor(backend, outsize), NewTensor(backend, size)

    host, hostT, hostTT := tensor.NewT(size), tensor.NewT(outsize), tensor.NewT(size)


    for i := 0; i < size[0]; i++ {
      for j := 0; j < size[1]; j++ {
        for k := 0; k < size[2]; k++ {
          host.List()[i*size[1]*size[2]+j*size[2]+k] = 1. + 0.*(rand.Float32()-.5) //1.
        }
      }
    }
       host.List()[0] = 1.

    TensorCopyTo(host, dev)

    fft.Forward(dev, devT)
    TensorCopyFrom(devT, hostT)

    fft.Inverse(devT, devTT)
    TensorCopyFrom(devTT, hostTT)


    fmt.Println("in:")
    host.WriteTo(os.Stdout)


    fmt.Println("out:")
    hostT.WriteTo(os.Stdout)


    fmt.Println("backtransformed:")
    hostTT.WriteTo(os.Stdout)


    var (
      errorTT  float32 = 0
    )

   fmt.Println("Normalization: ", fft.Normalization())
    for i := range hostTT.List() {
      hostTT.List()[i] /= float32(fft.Normalization())
      if abs(host.List()[i]-hostTT.List()[i]) > errorTT {
        errorTT = abs(host.List()[i] - hostTT.List()[i])
      }
    }
    //tensor.Format(os.Stdout, host2)
    fmt.Println("transformed² FFT error:                    ", errorTT)
    if errorTT > 1E-4  {
      t.Fail()
    }
  }

}


// func abs(r float32) float32 {
// 	if r < 0 {
// 		return -r
// 	}
// 	//else
// 	return r
// }
