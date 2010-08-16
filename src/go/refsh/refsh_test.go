package refsh

import (
	"testing"
	//"os"
	"fmt"
)

func TestRefsh(test *testing.T) {
	//   in, err := os.Open("test.in", os.O_RDONLY, 0666)
	//   if err != nil{ test.Fail(); return }
	//

	refsh := NewRefsh()
	refsh.AddFunc("hello", Hello)
	refsh.AddFunc("echo", Echo)

	refsh.AddAllMethods(&St{1})

	refsh.CrashOnError = false
	refsh.Interactive()

}

type St struct {
	It int
}

func (s *St) Method() int {
	return s.It
}

func (s *St) private() int {
	return 3
}

func Hello() {
	fmt.Println("Hello world!")
}

func Echo(i int) {
	fmt.Println(i)
}
