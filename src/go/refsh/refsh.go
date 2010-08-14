package refsh

import (
	. "reflect"
	"fmt"
	"os"
	"io"
)

// Maximum number of functions.
// TODO use a vector to make this unlimited.
const CAPACITY = 100


type Refsh struct {
	funcnames    []string
	funcs        []Caller
	CrashOnError bool
}

func NewRefsh() *Refsh {
	refsh := new(Refsh)
	refsh.funcnames = make([]string, CAPACITY)[0:0]
	refsh.funcs = make([]Caller, CAPACITY)[0:0]
	refsh.CrashOnError = true
	return refsh
}

func New() *Refsh {
	return NewRefsh()
}

// Adds a function to the list of known commands.
// example: refsh.Add("exit", Exit)
func (r *Refsh) AddFunc(funcname string, f interface{}) {
	function := NewValue(f)
	if r.resolve(funcname) != nil {
		fmt.Fprintln(os.Stderr, "Aldready defined:", funcname)
		os.Exit(-4)
	}
	r.funcnames = r.funcnames[0 : len(r.funcnames)+1]
	r.funcnames[len(r.funcnames)-1] = funcname
	r.funcs = r.funcs[0 : len(r.funcs)+1]
	r.funcs[len(r.funcs)-1] = (*FuncWrapper)(function.(*FuncValue))
}

func (r *Refsh) AddMethod(funcname string, function *FuncValue) {
	if r.resolve(funcname) != nil {
		fmt.Fprintln(os.Stderr, "Aldready defined:", funcname)
		os.Exit(-4)
	}
	r.funcnames = r.funcnames[0 : len(r.funcnames)+1]
	r.funcnames[len(r.funcnames)-1] = funcname
	r.funcs = r.funcs[0 : len(r.funcs)+1]
	r.funcs[len(r.funcs)-1] = (*FuncWrapper)(function)
}

// parses and executes the commands read from in
// bash-like syntax:
// command arg1 arg2
// command arg1
func (refsh *Refsh) Exec(in io.Reader) {
	for line, eof := ReadNonemptyLine(in); !eof; line, eof = ReadNonemptyLine(in) {
		cmd := line[0]
		args := line[1:]
		refsh.Call(cmd, args)
	}
}

const prompt = ">> "

// starts an interactive command line
// TODO: exit should stop this refsh, not exit the entire program
func (refsh *Refsh) Interactive() {
	in := os.Stdin
	fmt.Print(prompt)
	line, eof := ReadNonemptyLine(in)
	for !eof {
		cmd := line[0]
		args := line[1:]
		refsh.Call(cmd, args)
		fmt.Print(prompt)
		line, eof = ReadNonemptyLine(in)
	}
}

func exit() {
	os.Exit(0)
}


// Executes the command line arguments. They should have a syntax like:
// --command1 arg1 arg2 --command2 --command3 arg1
func (refsh *Refsh) ExecFlags() {
	commands, args := ParseFlags()
	for i := range commands {
		//fmt.Fprintln(os.Stderr, commands[i], args[i]);
		refsh.Call(commands[i], args[i])
	}
}


// Calls a function. Function name and arguments are passed as strings.
// The function name should first have been added by refsh.Add();
func (refsh *Refsh) Call(fname string, argv []string) {
	function := refsh.resolve(fname)
	if function == nil {
		fmt.Fprintln(os.Stderr, "Unknown command:", fname, "Options are:", refsh.funcnames)
		if refsh.CrashOnError {
			os.Exit(-5)
		}
	} else {
		args := refsh.parseArgs(fname, argv)
		function.Call(args)
	}
}


func (r *Refsh) resolve(funcname string) Caller {
	for i := range r.funcnames {
		if r.funcnames[i] == funcname {
			return r.funcs[i]
		}
	}
	return nil
}


/*

func main(){
  refsh := NewRefsh();
  refsh.Add("test", NewValue(SayHello));
  refsh.ExecFlags();
}

func SayHello(i int){
  fmt.Println("Hello reflection!", i);
}*/
