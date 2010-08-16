package refsh

import (
	. "reflect"
	"fmt"
	"os"
	"log"
	"strconv"
	"strings"
)

func (refsh *Refsh) parseArgs(fname string, argv []string) []Value {
	function := refsh.resolve(fname)
	nargs := function.NumIn()

	if nargs != len(argv) {
		fmt.Fprintln(os.Stderr, "Error calling", fname, argv, ": needs", nargs, "arguments.")
		os.Exit(-1)
	}

	args := make([]Value, nargs)
	for i := range args {
		args[i] = parseArg(argv[i], function.In(i))
	}
	return args
}

// TODO: we need to return Value, err
func parseArg(arg string, argtype Type) Value {
	switch argtype.Name() {
	default:
		panic(fmt.Sprint("Do not know how to parse ", argtype))
	case "int":
		return NewValue(parseInt(arg))
	case "float":
		return NewValue(parseFloat(arg))
	case "float64":
		return NewValue(parseFloat64(arg))
	case "string":
		return NewValue(arg)
	}
	log.Crash() // is never reached.
	return NewValue(666)
}


func parseInt(str string) int {
	i, err := strconv.Atoi(str)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Could not parse to int:", str)
		os.Exit(-3)
	}
	return i
}

func parseFloat(str string) float {
	i, err := strconv.Atof(strings.ToLower(str))
	if err != nil {
		fmt.Fprintln(os.Stderr, "Could not parse to float:", str)
		os.Exit(-3)
	}
	return i
}

func parseFloat64(str string) float64 {
	i, err := strconv.Atof64(strings.ToLower(str))
	if err != nil {
		fmt.Fprintln(os.Stderr, "Could not parse to float:", str)
		os.Exit(-3)
	}
	return i
}