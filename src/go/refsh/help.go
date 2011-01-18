//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.
// like AddMethod but with a Help string

package refsh

// Self-documenting capabilities

func (r *Refsh) AddMethodHelp(funcname string, reciever interface{}, methodname string, help string) {
	r.AddMethod(funcname, reciever, methodname)
	r.help[funcname] = help
}

// like AddFunc but with a Help string
func (r *Refsh) AddFuncHelp(funcname string, reciever interface{}, help string) {
	r.AddFunc(funcname, reciever)
	r.help[funcname] = help
}

func PrintHelp(){

}
