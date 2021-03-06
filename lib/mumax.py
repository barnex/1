#  This file is part of MuMax, a high-performance micromagnetic simulator.
#  Copyright 2011  Arne Vansteenkiste, Ben Van de Wiele.
#  Use of this source code is governed by the GNU General Public License version 3
#  (as published by the Free Software Foundation) that can be found in the license.txt file.
#  Note that you are welcome to modify this code under the condition that you send not remove any 
#  copyright notices and prominently state that you modified it, giving a relevant date.

# @author Arne Vansteenkiste, Ben Van de Wiele

## @package mumax
# MuMax Python API documentation.


from sys import stdin
from sys import stderr
from sys import stdout

## Infinity
inf = float("inf")

# Material parameters

## Sets the saturation magnetization in A/m
def msat(m):
	send1("msat", m)

## Sets the exchange constant in J/m
def aexch(a):
	send1("aexch", a)

## Sets the damping parameter
def alpha(a):
	send1("alpha", a)

## Sets the anisotropy constant K1.
def k1(k):
	send1("k1", k)

## Sets the anisotropy constant K2.
def k2(k):
	send1("k2", k)

## Defines the uniaxial anisotropy axis.
def anisUniaxial(ux, uy, uz):
	send3("anisuniaxial", ux, uy, uz)


## Defines the uniaxial anisotropy axis.
def anisCubic(u1x, u1y, u1z, u2x, u2y, u2z):
	send("aniscubic", [u1x, u1y, u1z, u2x, u2y, u2z])


## Defines the spin polarization for spin-transfer torque
def spinPolarization(p):
	send1("spinpolarization", p)

## Defines the non-adiabaticity for spin-transfer torque
def xi(xi):
	send1("xi", xi)

## Sets the temperature in Kelvin
def temperature(T):
	send1("temperature", T)


# Geometry

## Sets the number of FD cells
def gridSize(nx, ny, nz):
	send3("gridsize", nx, ny, nz)

## Sets the size of the magnet, in meters
def partSize(x, y, z):
	send3("partsize", x, y, z)

## Sets the cell size, in meters
def cellSize(x, y, z):
	send3("cellsize", x, y, z)

## Sets the maximum cell size, in meters
def maxCellSize(x, y, z):
	send3("maxcellsize", x, y, z)

## Sets periodic boundary conditions.
# The magnetic is repeated nx, ny, nz times in the x,y,z direction (to the left and to the rigth), respectively.
# A value of 0 means no periodicity in that direction. Big values of nx,ny,nz lead to slow initialization,
# but only the first time a simulation with these parameters is run.
def periodic(nx, ny, nz):
	send3('periodic', nx, ny, nz)

## Make the geometry an ellipsoid with specified semi-axes.
# Use inf to make it a cyliner along that direction.
def ellipsoid(rx, ry, rz):
	send3("ellipsoid", rx, ry, rz)

## only for geometry definition (normalized Msat is 0 or 1), .png format
def mask(file):
	send1("mask", file)


## Sets the reduced saturation magnetization of cell with integer index x,y,z
def setMsat(x, y, z, msat):
	send('setmsat', [x, y, z, msat])

## Sets the reduced saturation magnetization of a cell in the integer range [x1,y1,z1] -> [x2,y2,z2]
def setMsatRange(x1, y1, z1, x2, y2, z2, msat):
  send('SetMsatRange', [x1, y1, z1, x2, y2, z2, msat])

## Sets the reduced saturation magnetization of an ellips-shaped region with center [cx, cy] and radii [rx, ry]
def setMsatEllips(cx, cy, rx, ry, msat):
  send('SetMsatEllips', [cx, cy, rx, ry, msat])

## Sets the alpha multiplier of cell with integer index x,y,z.
# The damping of that cell will be alpha*alphaMul.
def setAlpha(x, y, z, alphaMul):
	send('setalpha', [x, y, z, alphaMul])

## Sets the alpha multiplier of a cell in the integer range [x1,y1,z1] -> [x2,y2,z2]
# The damping of that cell will be alpha*alphaMul.
def setAlphaRange(x1, y1, z1, x2, y2, z2, alpha):
  send('SetAlphaRange', [x1, y1, z1, x2, y2, z2, alpha])


# Initial magnetization

## Loads the magnetization state from a .omf file
def loadm(filename):
	send1("loadm", filename)

## Sets the magnetization to the uniform state (mx, my, mz)
def uniform(mx, my, mz):
	send3("uniform", mx, my, mz)

## Adds random noise to the magnetization
def addNoise(amplitude):
	send1("addnoise", amplitude)

## Initializes the magnetization to a random state
def setRandom():
	send0("setrandom")

## Sets the magnetization to a vortex state
def vortex(circulation, polarization):
	send2("vortex", circulation, polarization)
	
## Sets a vortex state with ellips shape having semi-axes [sx, sy] and center [cx, cy] with a certain circulation and polarization
def setVortexEllips(cx, cy, sx, sy, circulation, polarization):
  send("SetVortexEllips", [cx, cy, sx, sy, circulation, polarization])

## Sets a vortex state with rectangular shape having edges [sx, sy] and center [cx, cy] with a certain circulation and polarization
def setVortexEllips(cx, cy, sx, sy, circulation, polarization):
  send("SetVortexEllips", [cx, cy, sx, sy, circulation, polarization])

## Sets a vortex in an array
#def vortexInArray(i, j, unit_size, separation, circulation, polarization):
  #send("Vortex_in_array", [i, j, unit_size, separation, circulation, polarization])
def vortexInArray(i, j, unit_size_x, unit_size_y, separation_x, separation_y, circulation, polarization):
  send("VortexInArray", [i, j, unit_size_x, unit_size_y, separation_x, separation_y, circulation, polarization])
 
## Sets a mask for dot/vortex array (r: dot size in meters, sep: separation in meter, n: max[#dots in x-dir, #dots in y-dir])
def	dotArray(r, sep, n):
	send3("DotArray", r, sep, n)

## Sets a mask for antidot array with rectangular holes.
def dotArrayRectangle(unit_size_x, unit_size_y, separation_x, separation_y, Nx, Ny):
  send("DotArrayRectangle", [unit_size_x, unit_size_y, separation_x, separation_y, Nx, Ny])

## Sets a mask for antidot array with ellipsoidal holes.
def dotArrayEllips(unit_size_x, unit_size_y, separation_x, separation_y, Nx, Ny):
  send("DotArrayEllips", [unit_size_x, unit_size_y, separation_x, separation_y, Nx, Ny])

## Sets a mask for antidot array with rectangular holes.
def antiDotArrayRectangle(unit_size_x, unit_size_y, separation_x, separation_y, Nx, Ny):
  send("AntiDotArrayRectangle", [unit_size_x, unit_size_y, separation_x, separation_y, Nx, Ny])

## Sets a mask for antidot array with ellipsoidal holes.
def antiDotArrayEllips(unit_size_x, unit_size_y, separation_x, separation_y, Nx, Ny):
  send("AntiDotArrayEllips", [unit_size_x, unit_size_y, separation_x, separation_y, Nx, Ny])



#def SBW():
#  send0("SBW")
#
#def SNW():
#  send0("SNW")
#
#def ABW():
#  send0("ABW")
#
#def ANW():
#  send0("ANW")

# Sets the magnetization in cell with index i,j,k to (mx, my, mz)
def setmCell(i, j, k, mx, my, mz):
	send("setmcell", [i, j, k, mx, my, mz])

## Sets the magnetization in cell with index i,j,k to (mx, my, mz)
#def setmcell(i, j, k, mx, my, mz):
  #send_3ints_3floats("setmcell", i, j, k, mx, my, mz)

## Like setmcell but for a range of cells between x1,y1,z1 (inclusive) and x2,y2,z2 (inclusive)
def setmRange(x1, y1, z1, x2, y2, z2, mx, my, mz):
	send("setmrange", [x1, y1, z1, x2, y2, z2, mx, my, mz])

### Sets the magnetization in cell position x, y, z (in meters) to (mx, my, mz)
#def setm(x, y, z, mx, my, mz):
#	send("setm", [x, y, z, mx, my, mz])

## Sets the magnetization to a random state
def setRandom():
	send0("setrandom")

## Sets the random number seed
def seed(s):
	send1("seed", s)

# Output

## Single-time save with automatic file name
# Format = text | binary
def save(what, format):
	send2("save", what, format)

## Single save of the magnetization to a specified file (.omf)
def savem(filename, format):
	send2("savem", filename, format)

## Single save of the effective field to a specified file (.omf)
def saveh(filename, format):
	send2("saveh", filename, format)

## Periodic auto-save
def autosave(what, format, periodicity):
	send3("autosave", what, format, periodicity)

## Determine what should be saved in the datatable
# E.g.: autosave('m', True)
def tabulate(what, want):
	send2("tabulate", what, want)

## Reduce the resolution of saved output by a factor to save disk space.
def subsampleOutput(factor):
	send1("subsampleoutput", factor)


# Solver

## Overrides the solver type. E.g.: rk32, rk12, semianal...
def solvertype(solver):
	send1("solvertype", solver)

## Sets the maximum tolerable estimated error per solver step
def maxError(error):
	send1("maxerror", error)

## Sets the maximum time step in seconds
def maxdt(dt):
	send1("maxdt", dt)

## Sets the minimum time step in seconds
def mindt(dt):
	send1("mindt", dt)

## Sets the maximum magnetization step 
def maxdm(dm):
	send1("maxdm", dm)

## Sets the minimum magnetization step 
def mindm(dm):
	send1("mindm", dm)

# Excitation


## Apply a field/current density defined by a custom function.
# E.g.:
# def myfield(t):
# 	return 0, 0, A*sin(omega*t)
#
# applyfunction('field', myfield, 1e-9, 10e-12)
#
# this applies the field for 1ns, sampled every 10ps with linear interpolation between the samples.
def applyFunction(what, func, duration, timestep):
	t=0
	while t<=duration:
		bx,by,bz = func(t)
		applyPointwise(what, t, bx, by, bz)
		t+=timestep

## Apply a pointwise-defined field/current defined by a number of time + field points
# The field is linearly interpolated between the defined points
# E.g.:
#  applypointwise('field', 0,       0,0,0) 
#  applypointwise('field', 1e-9, 1e-3,0,0) 
# Sets up a linear ramp in 1ns form 0 to 1mT along X.
# Arbitrary functions can be well approximated by specifying a large number of time+field combinations.
def applyPointwise(what, time, bx, by, bz):
	send("applypointwise", [what, time, bx, by, bz])


## Set a space-dependent mask to be multiplied pointwise by the current density.
#  This allows for space-dependent current densities to be defined.
#  filename is an .omf file that defines the mask.
#  J(r,t) = (jx(t) * mask_x(r), jy(t) * mask_y(r), jz(t) * mask_z(r))
def currentMask(filename):
	send1("currentmask", filename)

## Set a space-dependent mask to be multiplied pointwise by the applied magnetic field
#  This allows for space-dependent fields to be defined.
#  filename is an .omf file that defines the mask.
#  B(r,t) = (bx(t) * mask_x(r), by(t) * mask_y(r), bz(t) * mask_z(r))
def fieldMask(filename):
	send1("fieldmask", filename)

## Apply a static field/current
def applyStatic(what, bx, by, bz):
	send("applystatic", [what, bx, by, bz])

## Apply an RF field/current
def applyRF(what, bx, by, bz, freq):
	send("applyrf", [what, bx, by, bz, freq])

### Apply an RF field/current, slowly ramped in
#def applyRFRamp(what, bx, by, bz, freq, ramptime):
#	send("applyrframp", [what, bx, by, bz, freq, ramptime])
#
### Apply a rotating field/current
#def applyRotating(what, bx, by, bz, freq, phaseX, phaseY, phaseZ):
#	send("applyrotating", [what, bx, by, bz, freq, phaseX, phaseY, phaseZ])
#
### Apply a pulsed field/current
#def applyPulse(what, bx, by, bz, risetime):
#	send("applypulse", [what, bx, by, bz, risetime])
#
### Apply a sawtooth field/current
#def applySawTooth(what, bx, by, bz, freq):
#	send("applysawtooth", [what, bx, by, bz, freq])
#
### Apply a rotating RF burst field/current
#def applyRotatingBurst(what, b, freq, phase, risetime, duration):
#	send("applyrotatingburst", [what, b, freq, phase, risetime, duration])

# Run

## Relaxes the magnetization up to the specified maximum residual torque
# @warning This function does not work very well yet.
def relax():
	send0("relax")

## Runs for the time specified in seconds
def run(time):
	send1("run", time)

## Takes one time step
def step():
	send0("step")

## Takes n time steps
def steps(n):
	send1("steps", n)


# Misc

## Adds a description tag
def desc(key, value):
	send2("desc", key, value)	

## Save benchmark info to file
def saveBenchmark(file):
	send1("savebenchmark", file)


# Recieve feedback from mumax

## Retrieves an average magnetization component (0=x, 1=y, 2=z).
def getm(component):
	send1("getm", component)
	return recv()

## Retrieves a magnetization component (0=mx, 1=my, 2=mz) at position x,y,z.
def getmPos(component, x, y, z):
	send("getmPos", [component, x, y, z])
	return recv()

## Retrieves the maximum value of a magnetization component (0=x, 1=y, 2=z).
def getMaxm(component):
	send1("getmaxm", component)
	return recv()

## Retrives the vortex core position in meters, center = 0,0
def getCorepos():
	send0("getcorepos")
	return recv(), recv()

## Retrieves the minimum value of a magnetization component (0=x, 1=y, 2=z).
def getMinm(component):
	send1("getminm", component)
	return recv()

## Retrieves the maximum torque in units gamma*Msat
def getMaxTorque():
	send0("getmaxtorque")
	return recv()

# Retrieves the total energy in SI units
def getE():
  send0("getE")
  return recv()

# Retrieves the time in seconds
def getTime():
  send0("getTime")
  return recv()

## Debug and fine-tuning

## @internal Override whether the exchange interaction is included in the magnetostatic convolution.
# @note internal use only
def exchInConv(b):
	send1("exchinconv", b)

## @internal Set the exchange type (number of neighbors)
# @note internal use only
def exchType(t):
	send1("exchtype", t)

## @internal Override the subcommand for calculating the magnetostatic kernel
# @note internal use only
def kernelType(cmd):
	send1("kerneltype", cmd)

## @internal Override whether or not (true/false) the magnetostatic field should be calculated
# @note internal use only
def demag(b):
	send1("demag", cmd)

# @internal Override whether or not (true/false) the energy should be calculated
# @note internal use only
def energy(b):
	send1("energy", b)


## @internal
# @note internal use only
def recv():
	#stderr.write("py_recv: ") #debug
	data = stdin.readline()
	while len(data) == 0 or data[0] != "%":	# skip lines not starting with the % prefix
		stderr.write("py recv():" + data + "\n") #debug
		exit(10)
		data = stdin.readline()
	#stderr.write(data + "\n") #debug
	return float(data[1:])

## @internal : version of print() that flushes (critical to avoid communication deadlock)
# @note internal use only
def myprint(x):
	#stderr.write("py_send: " + str(x) + "\n") #debug
	#stderr.flush()
	stdout.write(x)
	stdout.write("\n")
	stdout.flush()

## @internal. Shorthand for running a command with one argument
# @note internal use only
def send0(command):
	myprint(command)

## @internal. Shorthand for running a command with one argument
# @note internal use only
def send1(command, arg):
	myprint(command + " " + str(arg))

## @internal. Shorthand for running a command with two arguments
# @note internal use only
def send2(command, arg1, arg2):
	myprint(command + " " + str(arg1) + " " + str(arg2))

## @internal. Shorthand for running a command with three arguments
# @note internal use only
def send3(command, arg1, arg2, arg3):
	myprint(command + " " + str(arg1) + " " + str(arg2) + " " + str(arg3))

## @internal. Shorthand for running a command with arguments
# @note internal use only
def send(command, args):
	for a in args:
		command += " " + str(a)
	myprint(command)
		
