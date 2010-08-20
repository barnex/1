package sim

// This file implements methods for generating
// initial magnetization configurations like
// vortices, Landau patterns, etc.

import (
	"tensor"
	"rand"
	"os"
)

// INTERNAL: to be called before setting a magnetization state,
// ensures local memory for m has been allocated already
func (s *Sim) ensure_m() {
	if s.m == nil {
		s.m = tensor.NewTensor4([]int{3, s.size[X], s.size[Y], s.size[Z]})
	}
}

// Make the magnetization uniform.
// (mx, my, mz) needs not to be normalized.
func (s *Sim) Uniform(mx, my, mz float) {
	s.ensure_m()
	a := s.m.Array()
	for i := range a[0] {
		for j := range a[0][i] {
			for k := range a[0][i][j] {
				a[X][i][j][k] = mx
				a[Y][i][j][k] = my
				a[Z][i][j][k] = mz
			}
		}
	}
	s.invalidate() // todo: we do not need to invalidate everything here!
}

// Make the magnetization a vortex with given
// in-plane circulation (-1 or +1)
// and core polarization (-1 or 1)
func (s *Sim) Vortex(circulation, polarization int) {
	s.ensure_m()
	cy, cx := s.size[1]/2, s.size[2]/2
	a := s.m.Array()
	for i := range a[0] {
		for j := range a[0][i] {
			for k := range a[0][i][j] {
				y := j - cy
				x := k - cx
				a[X][i][j][k] = 0
				a[Y][i][j][k] = float(x * circulation)
				a[Z][i][j][k] = float(-y * circulation)
			}
		}
		a[Z][i][cy][cx] = 0.
		a[Y][i][cy][cx] = 0.
		a[X][i][cy][cx] = float(polarization)
	}
	normalize(a)
	s.invalidate()
}


func (s *Sim) Load(file string){
   in, err := os.Open(file, os.O_RDONLY, 0666)
   defer in.Close()
   if err != nil{
    panic(err)
   }
   //TODO this allocates too much buffers!
   tensor.CopyTo(tensor.Buffer(tensor.Resample(tensor.Read(in), s.m.Size())), s.m)
   s.invalidate()
}

// Adds noise with the specified amplitude
// to the magnetization state.
// Handy to break the symmetry.
func (s *Sim) AddNoise(amplitude float) {
	s.ensure_m()
	amplitude *= 2
	list := s.m.List()
	for i := range list {
		list[i] += amplitude * (rand.Float() - 0.5)
	}
	normalize(s.m.Array())
	s.invalidate()
}

//INTERNAL
func normalize(a [][][][]float) {
	for i := range a[0] {
		for j := range a[0][i] {
			for k := range a[0][i][j] {
				x := a[X][i][j][k]
				y := a[Y][i][j][k]
				z := a[Z][i][j][k]

				norm := 1. / fsqrt(x*x+y*y+z*z)

				a[X][i][j][k] *= norm
				a[Y][i][j][k] *= norm
				a[Z][i][j][k] *= norm
			}
		}
	}
}
// TODO: we are in trouble here if we have automatic transpose of the geometry for performance
// X needs to be the out-of-plane direction
