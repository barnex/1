//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.

package sim

// This file implements the main() for mumax running in master mode.
// Master mode starts sub-processes:
// 	* A slave mumax sub-process that will do the actual simulation.
//    Its stderr is tee'ed to a log file and possible the terminal,
//	  making sure all output is logged even it crashes ungracefully.
//  * Possibly a python/java/... subprocess to interpret input files
//    written in those languages. The master connects them to the mumax
//    slave with pipes and makes sure their output gets logged as well. 
//
// TODO: master could have have the ability to automatically select between GPU/CPU
import (
	"flag"
	"os"
	"exec"
	"iotool"
	"path"
	"fmt"
)

const WELCOME = `
  MuMax 0.4.1747
  (c) Arne Vansteenkiste & Ben Van de Wiele,
      DyNaMat/EELAB UGent
  This version is meant for internal testing purposes only,
  please contact the authors if you like to distribute this program.
  
`

// Recognized input file extensions
var known_extensions []string = []string{".in", ".py"}

// returns true if the extension (e.g. ".in") is recognized
func is_known_extension(ext string) bool {
	for _, e := range known_extensions {
		if e == ext {
			return true
		}
	}
	return false
}

// returns true if the filename (e.g. "file.in") has a recognized extension
func has_known_extension(filename string) bool {
	return is_known_extension(path.Ext(filename))
}


// Start a mumax/python/... slave subprocess and tee its output
func main_master() {

	if !*silent {
		fmt.Println(WELCOME)
		PrintInfo()
	}

	if flag.NArg() == 0 {
		NoInputFiles()
		os.Exit(-1)
	}

	// Process all input files
	for i := 0; i < flag.NArg(); i++ {
		infile := flag.Arg(i)
		extension := path.Ext(infile)
		switch extension {
		default:
			UnknownFileFormat(extension)
			os.Exit(ERR_UNKNOWN_FILE_FORMAT)
		case ".in":
			main_raw_input(infile)
		case ".py":
			main_python(infile)
		}
	}
}

// Main for raw input ".in" files
func main_raw_input(infile string) {

	args := passthrough_cli_args()
	args = append(args, "--slave", infile)
	cmd, err := subprocess(os.Getenv(SIMROOT)+"/"+SIMCOMMAND, args, exec.DevNull, exec.Pipe, exec.Pipe)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(ERR_SUBPROCESS)
	} else {
		if !*silent {
			fmt.Println("Child process PID ", cmd.Pid)
		}
		go Pipe(cmd.Stdout, os.Stdout) // TODO: logging etc
		go Pipe(cmd.Stderr, os.Stderr)
		_, errwait := cmd.Wait(0) // Wait for exit
		if errwait != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(ERR_SUBPROCESS)
		}
	}
}

// Main for python ".py" input files
func main_python(infile string) {

	outdir := RemoveExtension(infile) + ".out"
	fname_to_py := outdir + "/" + ".fifo-to-python.py"
	syscommand("mkfifo", []string{fname_to_py})
    fifo_to_py := iotool.MustOpenWRONLY(fname_to_py)


	py_args := []string{fname_to_py}
	py_bin, errlook := exec.LookPath("python")
	Check(errlook, ERR_SUBPROCESS)
	python, errpy := subprocess(py_bin, py_args, exec.DevNull, exec.Pipe, exec.Pipe)
	Check(errpy, ERR_SUBPROCESS)
	go Pipe(python.Stdout, os.Stdout) // TODO: logging etc
	go Pipe(python.Stderr, os.Stderr)

	fmt.Fprintln(fifo_to_py, "print(1+1)\n")

	_, errwait := python.Wait(0) // Wait for exit
	Check(errwait, ERR_SUBPROCESS)
}
