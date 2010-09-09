package sim

import ()

// Set the solver type: euler, heun, semianal, ...
func (s *Sim) SolverType(stype string) {
	s.input.solvertype = stype
	s.invalidate()
}
