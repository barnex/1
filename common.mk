# Common code for all makefiles
# Should be included in each makefile

# The C compiler
CC=gcc

# The C++ compiler
CPP=g++

# The CUDA compiler
NVCC=nvcc

# Flags to be passed to CC and CPP
CFLAGS+=\
  -Wall\
  -fPIC\
  -O3\
  -Werror\

# Flags to be passed to NVCC
NVCCFLAGS+=\
  --compiler-options -Werror\
  --compiler-options -fPIC\
  --use_fast_math\
  --compiler-options -O3\
  -arch=sm_20
#  -G\
# --compiler-options -DNDEBUG\
# -DNDEBUG disables all assert() statements

# Cuda libraries
#CUDALIBS= -l:libcudart.so -l:libcufft.so -l:libcurand.so
#CUDALIBS= -lcudart -lcufft
CUDALIBS= -lcudart -lcufft -lcurand

