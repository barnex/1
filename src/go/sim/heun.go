package sim

import ()


type Heun struct {
	*Sim
	m1est *DevTensor
	t0    *DevTensor
}


func NewHeun(f *Sim) *Heun {
	this := new(Heun)
	this.Sim = f
	this.m1est = NewTensor(f.Backend, Size4D(f.size[0:]))
	this.t0 = NewTensor(f.Backend, Size4D(f.size[0:]))
	return this
}


func (s *Heun) Step() {
	gilbertDt := s.dt / (1 + s.alpha*s.alpha)
	m := s.mDev
	m1est := s.m1est

	s.calcHeff(m, s.h)
	s.DeltaM(m, s.h, s.alpha, gilbertDt)
	TensorCopyOn(s.h, s.t0)
	TensorCopyOn(m, m1est)
	s.Add(m1est, s.t0)
	s.Normalize(m1est)

	s.calcHeff(s.m1est, s.h)
	s.DeltaM(s.m1est, s.h, s.alpha, gilbertDt)
	tm1est := s.h
	t := tm1est
	s.LinearCombination(t, s.t0, 0.5, 0.5)
	s.Add(m, t)

	s.Normalize(m)
}


func (this *Heun) String() string {
	return "Heun"
}
