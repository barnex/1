//  This file is part of MuMax, a high-performance micromagnetic simulator
//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.

package common

import (
	"strconv"
)

// Safe wrappers for strconv, panic on illegal input

// Safe strconv.Atof32
func Atof32(s string) float32 {
	f, err := strconv.Atof32(s)
	if err != nil {
		panic(InputErr(err.String()))
	}
	return f
}

// Safe strconv.Atoi
func Atoi(s string) int {
	i, err := strconv.Atoi(s)
	if err != nil {
		panic(InputErr(err.String()))
	}
	return i
}
