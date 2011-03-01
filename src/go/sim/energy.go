//  This file is part of MuMax, a high-performance micromagnetic simulator
//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.

package sim

// This file implements functions for calculating the energy.

import (
	//. "mumax/common"
	"mumax/tensor"
)


// Calculates the demag + exchange energy, requiring a convolution.
// When needed at every step, there are faster (but less flexible)
// methods.
func (s *Sim) calcEDensDemagExch(m, h, phi *DevTensor){
	s.calcHDemagExch(m, h)
	s.ScaledDotProduct(phi, m, h, -1./2.)
}

func (s *Sim) calcEDemagExch(m, h *DevTensor) float32{
	s.initEDens()
	phi := s.phiDev
	s.calcEDensDemagExch(m, h, phi)
	totalEnergy := s.sumPhi.Reduce(phi)	
	return totalEnergy
}

func (s *Sim) calcEnergy(m, h *DevTensor) float32{
	return s.calcEDemagExch(m, h) // TODO: add other contributions
}

func (s *Sim) GetEnergy() float32{
	s.init()
	return s.calcEnergy(s.mDev, s.hDev)
}

func (s *Sim) initEDens() {
	if s.phiDev == nil{
		s.init()
		s.phiDev = NewTensor(s.Backend, s.size3D)
		s.phiLocal = tensor.NewT3(s.size3D)
		s.sumPhi.InitSum(s.Backend, tensor.Prod(s.size3D))
	}
}
