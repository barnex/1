/*
 *  This file is part of MuMax, a high-performance micromagnetic simulator.
 *  Copyright 2010  Arne Vansteenkiste, Ben Van de Wiele.
 *  Use of this source code is governed by the GNU General Public License version 3
 *  (as published by the Free Software Foundation) that can be found in the license.txt file.
 *
 *  Note that you are welcome to modify this code under condition that you do not remove any 
 *  copyright notices and prominently state that you modified it, giving a relevant date.
 */

#include "gpu_conf.h"
#include "gpu_properties.h"
#include "../macros.h"
#include <assert.h>

#ifdef __cplusplus
extern "C" {
#endif

void check3dconf(dim3 gridSize, dim3 blockSize){

  debugvv( printf("check3dconf((%d, %d, %d),(%d, %d, %d))\n", gridSize.x, gridSize.y, gridSize.z, blockSize.x, blockSize.y, blockSize.z) );
  
  cudaDeviceProp* prop = (cudaDeviceProp*)gpu_getproperties();
  int maxThreadsPerBlock = prop->maxThreadsPerBlock;
  int* maxBlockSize = prop->maxThreadsDim;
  int* maxGridSize = prop->maxGridSize;
  
  assert(gridSize.x > 0);
  assert(gridSize.y > 0);
  assert(gridSize.z > 0);
  
  assert(blockSize.x > 0);
  assert(blockSize.y > 0);
  assert(blockSize.z > 0);
  
  assert(blockSize.x <= maxBlockSize[X]);
  assert(blockSize.y <= maxBlockSize[Y]);
  assert(blockSize.z <= maxBlockSize[Z]);
  
  assert(gridSize.x <= maxGridSize[X]);
  assert(gridSize.y <= maxGridSize[Y]);
  assert(gridSize.z <= maxGridSize[Z]);
  
  assert(blockSize.x * blockSize.y * blockSize.z <= maxThreadsPerBlock);
}

void check1dconf(int gridsize, int blocksize){
  assert(gridsize > 0);
  assert(blocksize > 0);
  assert(blocksize <= ((cudaDeviceProp*)gpu_getproperties())->maxThreadsPerBlock);
}

int _gpu_max_threads_per_block = 0;

int gpu_maxthreads(){
  if(_gpu_max_threads_per_block <= 0){
    cudaDeviceProp* prop = (cudaDeviceProp*)gpu_getproperties();
    _gpu_max_threads_per_block = prop->maxThreadsPerBlock;
  }
  return _gpu_max_threads_per_block;
}

void gpu_setmaxthreads(int max){
  _gpu_max_threads_per_block = max;
}

void make1dconf(int N, dim3* gridSize, dim3* blockSize){

//   debugvv( printf("make1dconf(%d)\n", N) );
  
  cudaDeviceProp* prop = (cudaDeviceProp*)gpu_getproperties();
  int maxBlockSize = gpu_maxthreads();
//   if(maxBlockSize > 128){
//     fprintf(stderr, "WARNING: using 128 as max block size! \n");
//     maxBlockSize = 128;
//   }
  int maxGridSize = prop->maxGridSize[X];

  (*blockSize).x = maxBlockSize;
  (*blockSize).y = 1;
  (*blockSize).z = 1;
  
  int N2 = divUp(N, maxBlockSize); // N2 blocks left
  
  int NX = divUp(N2, maxGridSize);
  int NY = divUp(N2, NX);

  (*gridSize).x = NX;
  (*gridSize).y = NY;
  (*gridSize).z = 1;

  assert((*gridSize).x * (*gridSize).y * (*gridSize).z * (*blockSize).x * (*blockSize).y * (*blockSize).z >= N);
  //assert((*gridSize).x * (*gridSize).y * (*gridSize).z * (*blockSize).x * (*blockSize).y * (*blockSize).z < N + maxBlockSize); ///@todo remove this assertion for very large problems
  
  check3dconf(*gridSize, *blockSize);
}

#ifdef __cplusplus
}
#endif
