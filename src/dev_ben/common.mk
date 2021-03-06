# Common code for all makefiles
# Should be included in each makefile

CC=gcc
CPP=g++
NVCC=nvcc

CFLAGS+=\
  -Wall\
  -Werror\
  -fPIC\
  -g\


NVCCFLAGS+=\
  --compiler-options -Werror\
  --compiler-options -fPIC\
  --compiler-options -g\
#  -G\
#  --device-emulation\
# --compiler-options -DNDEBUG\


# -DNDEBUG disables all assert() statements
# --device-emulation allows to run it on a CPU, requires "emu" to be appended to all cuda library names (e.g. -lcudartemu)


# append "emu" to each lib when using device emulation
CUDALIBS= -lcudart -lcufft