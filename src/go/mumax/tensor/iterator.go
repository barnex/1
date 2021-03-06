//  This file is part of MuMax, a high-performance micromagnetic simulator.
//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.

package tensor


// An iterator for tensors.
//
// Handy to access a tensor when the rank is not known.
// Iterator.Next() iterates to the next element, in row-major oder.
//
// Typical usage:
//
// for i := NewIterator(tensor); i.HasNext(); i.Next(){
//    element := i.Get();
//    current_position = i.Index();
// }
//
type Iterator struct {
	tensor     Interface
	index      []int
	size       []int
	count, max int
}


// New iterator for the tensor,
// starts at 0th element and can not be re-used.
func NewIterator(t Interface) *Iterator {
	return &Iterator{t, make([]int, Rank(t)), t.Size(), 0, Len(t)}
}

// Is a next element still available?
func (it *Iterator) HasNext() bool {
	return it.count < it.max
}

// Gets the current element
func (it *Iterator) Get() float32 {
	return it.tensor.List()[it.count]
}

// Advances to the next element
func (it *Iterator) Next() {
	it.count++
	if it.HasNext() {
		i := len(it.index) - 1
		it.index[i]++
		for it.index[i] >= it.size[i] {
			it.index[i] = 0
			i--
			it.index[i]++
		}
	}
}

// Returns the current N-dimensional index.
func (it *Iterator) Index() []int {
	return it.index
}
