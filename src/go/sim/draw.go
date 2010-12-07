//  Copyright 2010  Arne Vansteenkiste
//  Use of this source code is governed by the GNU General Public License version 3
//  (as published by the Free Software Foundation) that can be found in the license.txt file.
//  Note that you are welcome to modify this code under the condition that you do not remove any 
//  copyright notices and prominently state that you modified it, giving a relevant date.

package sim

import (
	"tensor"
	. "image"
	"image/png"
	"math"
	"io"
)

// Writes as png
// TODO: rename
func PNG(out io.Writer, t tensor.Interface) {
	err := png.Encode(out, DrawTensor(t))
	if err != nil {
		panic(err)
	}
}

// Draws rank 4 tensor (3D vector field) as image
// averages data over X (usually thickness of thin film)
func DrawTensor(t tensor.Interface) *NRGBA {
	switch tensor.Rank(t) {
	case 4:
		return DrawTensor4(tensor.ToT4(t))
	case 3:
		return DrawTensor3(tensor.ToT3(t))
	default:
		panic("Illegal argument")
	}
	return nil
}


// Draws rank 4 tensor (3D vector field) as image
// averages data over X (usually thickness of thin film)
func DrawTensor4(t *tensor.T4) *NRGBA {
	assert(tensor.Rank(t) == 4)

	h, w := t.Size()[2], t.Size()[3]
	img := NewNRGBA(w, h)
	arr := t.Array()
	for i := 0; i < h; i++ {
		for j := 0; j < w; j++ {
			var x, y, z float32 = 0., 0., 0.
			for k := 0; k < t.Size()[1]; k++ {
				x += arr[X][k][i][j]
				y += arr[Y][k][i][j]
				z += arr[Z][k][i][j]
			}
			x /= float32(t.Size()[1])
			y /= float32(t.Size()[1])
			z /= float32(t.Size()[1])
			img.Set(j, (h-1)-i, HSLMap(z, y, x)) // TODO: x is thickness for now...
		}
	}
	return img
}


// Draws rank 3 tensor (3D scalar field) as image
// averages data over X (usually thickness of thin film)
func DrawTensor3(t *tensor.T3) *NRGBA {
	assert(tensor.Rank(t) == 3)

	h, w := t.Size()[1], t.Size()[2]
	img := NewNRGBA(w, h)
	arr := t.Array()
	for i := 0; i < h; i++ {
		for j := 0; j < w; j++ {
			var x float32 = 0.
			for k := 0; k < t.Size()[1]; k++ {
				x += arr[k][i][j]

			}
			x /= float32(t.Size()[0])
			img.Set(j, (h-1)-i, GreyMap(0., 1., x))
		}
	}
	return img
}


func GreyMap(min, max, value float32) NRGBAColor {
	color := (value - min) / (max - min)
	if color > 1. {
		color = 1.
	}
	if color < 0. {
		color = 0.
	}
	color8 := uint8(255 * color)
	return NRGBAColor{color8, color8, color8, 255}
}

func HSLMap(x, y, z float32) NRGBAColor {
	s := fsqrt(x*x + y*y + z*z)
	l := 0.5*z + 0.5
	h := float32(math.Atan2(float64(y), float64(x)))
	return HSL(h, s, l)
}

func fsqrt(number float32) float32 {
	return float32(math.Sqrt(float64(number)))
}

// h = 0..2pi, s=0..1, l=0..1
func HSL(h, s, l float32) NRGBAColor {
	if s > 1 {
		s = 1
	}
	if l > 1 {
		l = 1
	}
	for h < 0 {
		h += 2 * math.Pi
	}
	for h > 2*math.Pi {
		h -= math.Pi
	}
	h = h * (180.0 / math.Pi / 60.0)

	// chroma
	var c float32
	if l <= 0.5 {
		c = 2 * l * s
	} else {
		c = (2 - 2*l) * s
	}

	x := c * (1 - abs(fmod(h, 2)-1))

	var (
		r, g, b float32
	)

	switch {
	case 0 <= h && h < 1:
		r, g, b = c, x, 0.
	case 1 <= h && h < 2:
		r, g, b = x, c, 0.
	case 2 <= h && h < 3:
		r, g, b = 0., c, x
	case 3 <= h && h < 4:
		r, g, b = 0, x, c
	case 4 <= h && h < 5:
		r, g, b = x, 0., c
	case 5 <= h && h < 6:
		r, g, b = c, 0., x
	default:
		r, g, b = 0., 0., 0.
	}

	m := l - 0.5*c
	r, g, b = r+m, g+m, b+m

	if r > 1. {
		r = 1.
	}
	if g > 1. {
		g = 1.
	}
	if b > 1. {
		b = 1.
	}

	if r < 0. {
		r = 0.
	}
	if g < 0. {
		g = 0.
	}
	if b < 0. {
		b = 0.
	}

	R, G, B := uint8(255*r), uint8(255*g), uint8(255*b)
	return NRGBAColor{R, G, B, 255}
}

// modulo
func fmod(number, mod float32) float32 {
	for number < mod {
		number += mod
	}
	for number >= mod {
		number -= mod
	}
	return number
}

func abs(number float32) float32 {
	if number < 0 {
		return -number
	} // else
	return number
}
