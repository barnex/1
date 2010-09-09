package sim

// This file implements the methods for defining
// the applied magnetic field.

// Apply a static field defined in Tesla
// func (s *Sim) AppliedField(hx, hy, hz float) {
// 	Debugv("Applied field:", hx, hy, hz)
// 	s.hext[X] = hx
// 	s.hext[Y] = hy
// 	s.hext[Z] = hz
// 	s.invalidate()
// }

// Control the accuracy of the demag kernel.
// 2^accuracy points are used to integrate the field.
// A high value is accurate and slows down (only) the initialization.
func (s *Sim) DemagAccuracy(accuracy int) {
	Debugv("Demag accuracy:", accuracy)
	s.demag_accuracy = accuracy
	s.invalidate()
}
