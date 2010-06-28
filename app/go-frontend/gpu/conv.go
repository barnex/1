package gpu

import(
  "tensor"
  "unsafe"
  "os"
  "fmt"
)


type Conv struct{
  kernel     [6]*Tensor
  buffer     [3]*Tensor
  mComp      [3]*Tensor
  hComp      [3]*Tensor
  fft       *FFT;

  // transform [3]bool
  // kmul type 9 - 6 - 4 - 3
}


func NewConv(dataSize, kernelSize []int) *Conv{
  assert(len(dataSize) == 3)
  assert(len(kernelSize) == 3)
  for i:=range dataSize{
    assert(dataSize[i] <= kernelSize[i])
  }

  conv := new(Conv)
  conv.fft = NewFFTPadded(dataSize, kernelSize)
  
  ///@todo do not allocate for infinite2D problem
  for i:=0; i<3; i++{
    conv.buffer[i] = NewTensor(conv.PhysicSize())
    conv.mComp[i] = &Tensor{ dataSize, unsafe.Pointer(nil) }
    conv.hComp[i] = &Tensor{ dataSize, unsafe.Pointer(nil) }
  }
  return conv
}


func (conv *Conv) Exec(source, dest *Tensor){

  assert(len(source.size) == 4)             // size checks
  assert(len(  dest.size) == 4)
  for i,s:= range conv.DataSize(){
    assert(source.size[i+1] == s)
    assert(  dest.size[i+1] == s)
  }
  
  // initialize mComp, hComp, re-using them from conv to avoid repeated allocation
  mComp, hComp := conv.mComp, conv.hComp
  buffer := conv.buffer
  kernel := conv.kernel
  mLen := Len(mComp[0].size)
  for i:=0; i<3; i++{
    mComp[i].data = ArrayOffset(source.data, i*mLen)
    hComp[i].data = ArrayOffset(  dest.data, i*mLen)
  }
  
  for i:=0; i<3; i++{
    CopyPad(mComp[i], buffer[i])
//     fmt.Println("mPadded", i)
//     tensor.Format(os.Stdout, buffer[i])
  }

  
  //Sync
  
  for i:=0; i<3; i++{
    conv.fft.Forward(buffer[i], buffer[i]) // should not be asynchronous unless we have 3 fft's (?)
//     fmt.Println("fftm", i)
//     tensor.Format(os.Stdout, buffer[i])
  }
  
  KernelMul(buffer[X].data,  buffer[Y].data,   buffer[Z].data,
            kernel[XX].data, kernel[YY].data, kernel[ZZ].data,
            kernel[YZ].data, kernel[XZ].data, kernel[XY].data,
            Len(buffer[X].size))  // nRealNumbers 

  for i:=0; i<3; i++{
    fmt.Println("mulM", i)
    tensor.Format(os.Stdout, buffer[i])
  }
            
  for i:=0; i<3; i++{
    conv.fft.Inverse(buffer[i], buffer[i]) // should not be asynchronous unless we have 3 fft's (?)
  } 
  
  for i:=0; i<3; i++{
    CopyUnpad(buffer[i], hComp[i])
  }
}


func (conv *Conv) LoadKernel6(kernel []*tensor.Tensor3){
  for _,k:=range kernel{
    if k != nil{
      assert( tensor.EqualSize(k.Size(), conv.KernelSize()) )
    }
  }

  buffer := tensor.NewTensorN(conv.KernelSize())
  devbuf := NewTensor(conv.KernelSize())

  fft := NewFFT(conv.KernelSize())
  N := 1.0 / float(fft.Normalization())
  
  for i:= range conv.kernel{
    if kernel[i] != nil{                    // nil means it would contain only zeros so we don't store it.
      conv.kernel[i] = NewTensor(conv.PhysicSize())

      tensor.CopyTo(kernel[i], buffer)

      for i:=range buffer.List(){
        buffer.List()[i] *= N
      }
      
      TensorCopyTo(buffer, devbuf)
      CopyPad(devbuf, conv.kernel[i])   ///@todo padding should be done on host, not device, to save gpu memory / avoid fragmentation

      fft.Forward(conv.kernel[i], conv.kernel[i])
    }
  }
}



/// size of the magnetization and field, this is the FFT dataSize
func (conv *Conv) DataSize() []int{
  return conv.fft.DataSize()
}


/// size of magnetization + padding zeros, this is the FFT logicSize
func (conv *Conv) KernelSize() []int{
  return conv.fft.LogicSize()
}


/// size of magnetization + padding zeros + striding zeros, this is the FFT logicSize
func (conv *Conv) PhysicSize() []int{
  return conv.fft.PhysicSize()
}

const(
  XX = 0
  YY = 1
  ZZ = 2
  YZ = 3
  XZ = 4
  XY = 5
)



