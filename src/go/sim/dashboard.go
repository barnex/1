//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.

package sim

import (
	"fmt"
	"os"
	"time"
)

var (
	lastDashUpdate       int64 = 0
	UpdateDashboardEvery int64 = 25 * 1000 * 1000 // in ns
	dashboardNeedsUp     bool  = false
	dashstart            int64 = 0
)

func updateDashboard(sim *Sim) {

	if sim.silent {
		return
	}

	// 	fmt.Print(HIDECURSOR)

	T := sim.UnitTime()

	nanotime := time.Nanoseconds()
	if (nanotime - lastDashUpdate) < UpdateDashboardEvery {
		return // too soon to update display yet
	}
	lastDashUpdate = nanotime

	if dashstart == 0 {
		dashstart = nanotime
	}

	//fmt.Print(HIDECURSOR)
	// Walltime
	time := time.Seconds() - sim.starttime
	fmt.Printf(
		BOLD+"running:"+RESET+"%3dd:%02dh:%02dm:%02ds",
		time/DAY, (time/HOUR)%24, (time/MINUTE)%60, time%60)
	erase()
	fmt.Println()

	t := (nanotime - dashstart) + 1 // add 1ns to avoid dividing by zero
	stepsPerS := float64(sim.steps) / (float64(t) / 1e9)
	realTime := sim.UnitTime() * float32(sim.time) / (float32(t) / 1e9)

	// Time stepping
	fmt.Printf(
		BOLD+"step: "+RESET+"%-11d "+
			BOLD+"time: "+RESET+"%.4es      "+
			BOLD+"Δt:   "+RESET+" %.3es",
		sim.steps, float32(sim.time)*T, sim.dt*T)
	erase()
	fmt.Println()

	fmt.Print(BOLD+"IO: "+RESET, sim.autosaveIdx)
	erase()
	fmt.Println()

	fmt.Print(BOLD+"GPU mem: "+RESET, sim.UsedMem()/MiB, " MiB")
	eraseln()

	// Conditions
	fmt.Printf(BOLD+"torque:    "+RESET+"%.5e", sim.torque)
	erase()
	fmt.Println()

	// performance
	fmt.Print("steps/s: ", RESET, stepsPerS, BOLD, " sim/real time: ", RESET, realTime)
	erase()
	fmt.Println()

	up()
	up()
	up()
	up()
	up()
	up()
}

func (s *Sim) printMem() {
	// SEGFAULTS !
	//fmt.Println("s", s)
	//   fmt.Println("GPU memory used: ", s.UsedMem()/MiB, " MiB")
}

func erase() {
	fmt.Fprint(os.Stdout, ERASE)
}

func eraseln() {
	fmt.Fprintln(os.Stdout, ERASE)
}

func up() {
	fmt.Printf(LINEUP)
}

func down() {
	fmt.Printf(LINEDOWN)
}


// ANSI escape sequences
const (
	ESC = "\033["
	// Erase rest of line
	ERASE = "\033[K"
	// Restore cursor position
	RESET = "\033[0m"
	// Bold
	BOLD = "\033[1m"
	// Line up
	LINEUP = "\033[1A"
	// Line down
	LINEDOWN = "\033[1B"
	// Hide cursor
	HIDECURSOR = "\033[?25l"
	// Show cursor
	SHOWCURSOR = "\033[?25h"

	RED = "\033[31m"
)

// Time units expressed in seconds
const (
	MINUTE = 60
	HOUR   = 60 * MINUTE
	DAY    = 24 * HOUR
)

const (
	MiB = 1024 * 1024
)
