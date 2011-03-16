//  This file is part of MuMax, a high-performance micromagnetic simulator.
//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.

package common

import (
	"math"
	"path"
)

// Size, in bytes, of a C single-precision float
const SIZEOF_CFLOAT = 4

// Go equivalent of &array[index] (for a float array).
func ArrayOffset(array uintptr, index int) uintptr {
	return uintptr(array + uintptr(SIZEOF_CFLOAT*index))
}

// True if not infinite and not NaN
func IsReal(f float32) bool {
	if math.IsInf(float64(f), 0) {
		return false
	}
	return !math.IsNaN(float64(f))
}

// True if not infinite, not NaN and not zero
func IsFinite(f float32) bool {
	if math.IsInf(float64(f), 0) {
		return false
	}
	if math.IsNaN(float64(f)) {
		return false
	}
	return f != 0
}

func IsInf(f float32) bool {
	return math.IsInf(float64(f), 0)
}

// replaces the extension of filename by a new one.
func ReplaceExt(filename, newext string) string {
	extension := path.Ext(filename)
	return filename[:len(filename)-len(extension)] + newext
}


// Absolute value
func Abs(x float32) float32 {
	if x < 0 {
		return -x
	}
	return x
}

func Sqrt32(x float32) float32 {
	return float32(math.Sqrt(float64(x)))
}
