package sim

import(
  "tensor"
)

// Field contains everything neccesary to calculate the effective field H_eff
type Field struct{
  Magnet
  
  *Conv
  Hext []float
  
  // Exchange
  // Anis
  // External
}

// Takes the parameters from a Magnet struct and
// initializes everything.
func NewField(dev Backend, mag *Magnet) *Field{
  field := new(Field)
  
  field.Magnet = *mag
  field.Hext = nil
  demag := FaceKernel(field.Size(), field.CellSize())
  exch := Exch6NgbrKernel(field.Size(), field.CellSize())
  kernel := toSymmetric(tensor.Buffer(tensor.Add(demag, exch)))
  field.Conv = NewConv(dev, field.Size(), kernel)
  
  return field
}


// Calculates the effective field of m and stores it in h
func(f *Field) CalcHeff(m, h *Tensor){
  Debugvv("Field.CalcHeff()")
  f.Convolve(m, h)
  
  if f.Hext != nil{
    for i:=range f.hComp{
      f.AddConstant(f.hComp[i], f.Hext[i])
    }
  }
} 


func(f *Field) String() string{
  return "Field:\n" + f.Magnet.String()
}

