//  This file is part of MuMax, a high-performance micromagnetic simulator
//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any
//  copyright notices and prominently state that you modified it, giving a relevant date.

// odttool is a general-purpose manipulator for .odt files.
// 
// General usage:
// odttool --command="arg1,arg2" ... infiles outfile
//
//
package main


import (
	. "mumax/common"
	"mumax/omf"
	"refsh"
	"fmt"
	"os"
)


// Stores the currently loaded odt file.
var (
	filename string
	table    *omf.Table // the currently opened file
)


// If we have already output something by the end of the program, quit.
// Otherwise, output the newly constructed table.
var haveOutput bool

// Stores the table being built
var (
	newtable omf.Table
)

func init() {
	newtable.Init()
}


// CLI args consist of flags (starting with --) and files.
// They are passed like this:
// --command="arg1, arg2" ... file1 file2 ...
// The command is executed on each of the files
func main() {
	sh := refsh.New()
	sh.AddFunc("getdesc", GetDesc)
	sh.AddFunc("peak", Peak)
	sh.AddFunc("peakcount", PeakCount)
	sh.AddFunc("header", Header)
	sh.AddFunc("cat", Cat)
	sh.AddFunc("getcol", GetCol)
	sh.AddFunc("matrix", Matrix)
	sh.AddFunc("meshdom", Meshdom)
	sh.AddFunc("diff", Diff)
	sh.AddFunc("diff2", Diff2)
	sh.AddFunc("avgdiff2", AvgDiff2)
	sh.AddFunc("avgdiff2nopeak", AvgDiff2NoPeak)
	sh.AddFunc("inplanerms", InplaneRMS)
	cmd, args, files := refsh.ParseFlags2()

	// Each file is read and stored in "data".
	// Then, all commands are executed on that data.

	if len(files) == 0 {
		fmt.Fprintln(os.Stderr, "No input files")
		os.Exit(-1)
	}

	for _, file := range files {
		fmt.Fprintln(os.Stderr, file)
		table = omf.ReadTable(MustOpenRDONLY(file))
		filename = file

		if len(cmd) == 0 {
			fmt.Fprintln(os.Stderr, "No commands")
			os.Exit(-1)
		}

		for i := range cmd {
			sh.Call(cmd[i], args[i])
		}
	}
	if !haveOutput {
		newtable.WriteTo(os.Stdout)
	}
}
