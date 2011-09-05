//  This file is part of MuMax, a high-performance micromagnetic simulator.
//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.

// This file implements mumax error types.
// InputErr: illegal input, e.g. in the input file.
// IOErr: I/O error, e.g. file not found
// Bug: this is not the user's fault. A crash report should be generated.

package common

import (
	"os"
	"fmt"
)

// We define different error types so a recover() after
// panic() can determine (with a type assertion)
// what kind of error happened. 
// Only a Bug error causes a bug report and stack dump,
// other errors are the user's fault and do not trigger
// a stack dump.

// The input file contains illegal input
type InputErr string

func (e InputErr) String() string {
	return string(e)
}

// A file could not be read/written
type IOErr string

func (e IOErr) String() string {
	return string(e)
}

// An unexpected error occurred which should be reported
type Bug string

func (e Bug) String() string {
	return string(e)
}

// Exits with the exit code if the error is not nil.
// TODO: rename CheckErr
func CheckErr(err os.Error, code int) {
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(code)
	}
}

// Exit error code
const (
	ERR_INPUT               = 1
	ERR_IO                  = 2
	ERR_UNKNOWN_FILE_FORMAT = 3
	ERR_SUBPROCESS          = 4

	ERR_BUG = 255
)
