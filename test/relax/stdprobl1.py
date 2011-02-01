from mumax import *

msat(800E3)
aexch(1.3E-11)
alpha(1)
anisuniaxial(1, 0, 0)
k1(500)	
gridsize(256, 128, 1)   
partsize(1000e-9, 500e-9, 40e-9)

vortex(1,1)
addnoise(0.1)
alpha(2)
relax()
save("m", "png")

for i in range(0,100):
	staticfield(i*1.0e-3, 0, 0)
	relax()
	save("m", "text")

