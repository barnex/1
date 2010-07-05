package sim

import(
)


// 1st order Euler method
type Euler struct{
  Solver
}

func(this *Euler) String() string{
  return "Euler" + this.Solver.String() + "--\n"
}

func NewEuler(dev Backend, mag *Magnet, dt float) *Euler{
  euler := new(Euler)
  
  euler.Solver = *NewSolver(dev, mag)
  euler.dt = dt
  
  return euler
}

func (this *Euler) Step(){
  Debugvv( "Euler.Step()" )
  m, h := this.m, this.h
  alpha, dt := this.Alpha, this.dt

  this.Normalize(m)
  this.CalcHeff(this.m, this.h)
  this.Torque(m, h, dt/(1+alpha*alpha))
  torque := h

  this.Add(m, torque)
  this.Normalize(m)
}


// embedding tree:

// Simulation{ ? to avoid typing backend backend backend...(but sim. sim. sim.)
// Euler{
//   Solver{
//     Field{
//       Material;
//       Conv{
//         FFT{
//           size
//           Device{  //sim.Device or cpu.Device
//             // low-level, unsafe simulation primitives
//             NewTensor
//             FFT,
//             Copy,
//             Torque,
//             ...
//           }
//         }
//       }
//     }
//   }
// }
//}
