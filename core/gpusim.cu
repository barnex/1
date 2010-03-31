#include "gpusim.h"
#include <stdio.h>
#include <assert.h>

#ifdef __cplusplus
extern "C" {
#endif

void print(const char* msg, tensor* t){
  printf("%s:\n", msg);
  format_tensor(t, stdout);
}

//_____________________________________________________________________________________________ sim

void gpusim_updateh(gpusim* sim){
  fprintf(stderr, "updateh\n");
  gpu_zero(sim->h, sim->len_h);								// zero-out field (h) components
  //for(int i=0; i<3; i++){								// transform and convolve per magnetization component m_i
    gpu_zero(sim->ft_m_i, sim->len_ft_m_i);						// zero-out the padded magnetization buffer first
    gpu_copy_pad_r2c(sim->m_comp[0], sim->ft_m_i, sim->size[0], sim->size[1], sim->size[2]);	//copy mi into the padded magnetization buffer, converting to complex format
  //}
}

// Ni: logical size of m
__global__ void _gpu_copy_pad_r2c(float* source, float* dest, int N0, int N1, int N2){
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  int j = blockIdx.y * blockDim.y + threadIdx.y;
  int k = blockIdx.z * blockDim.z + threadIdx.z;
  
  int destN0 = 2*N0;	//padded complex
  int destN1 = 2*N1;
  int destN2 = 2*2*N2;
  
  dest[i*destN1*destN2 + j*destN2 + 2*k    ] = 3.;//source[i*N1*N2 + j*N2 + k];
  dest[i*destN1*destN2 + j*destN2 + 2*k + 1] = 4.;
  
}

void gpu_copy_pad_r2c(float* source, float* dest, int N0, int N1, int N2){
  /*
   * Note: the block size must be 2 dimensional (A x B x 1), despite being of type dim3.
   */
  fprintf(stderr, "gpu_copy_pad_r2c\n");
  assert(N0 % 16 == 0);
  assert(N1 % 16 == 0);
  
  dim3 threadsPerBlock(8, 8, 1);
  dim3 numBlocks(N0 / threadsPerBlock.x, N1 / threadsPerBlock.y, N2 / threadsPerBlock.z);
  fprintf(stderr, "numBlocks %d %d %d\n", numBlocks.x, numBlocks.y, numBlocks.z);
  assert(numBlocks.x != 0); assert(numBlocks.y != 0); assert(numBlocks.z != 0); 
  
  gpu_checkconf(numBlocks, threadsPerBlock);
  //_gpu_copy_pad_r2c<<<numBlocks, threadsPerBlock>>>(source, dest, N0, N1, N2);
  _gpu_copy_pad_r2c<<<2, threadsPerBlock>>>(source, dest, N0, N1, N2);

}

//_____________________________________________________________________________________________ load / store data

void gpusim_checksize_m(gpusim* sim, tensor* m){
   // m should be a rank 4 tensor with size 3 x N0 x N1 x N2
  assert(m->rank == 4);
  assert(m->size[0] == 3); 
  for(int i=0; i<3; i++){ assert(m->size[i+1] == sim->size[i]); }
}

void gpusim_loadm(gpusim* sim, tensor* m){
  gpusim_checksize_m(sim, m); 
  memcpy_to_gpu(m->list, sim->m, sim->len_m);
}

void gpusim_storem(gpusim* sim, tensor* m){
   gpusim_checksize_m(sim, m);
   memcpy_from_gpu(sim->m, m->list, sim->len_m);
}

//_____________________________________________________________________________________________ kernel

void gpusim_checksize_kernel(gpusim* sim, tensor* kernel){
  // kernel should be rank 5 tensor with size 3 x 3 x 2*N0 x 2xN1 x 2xN2 (could be reduced a bit)
  assert(kernel->rank == 5);
  assert(kernel->size[0] == 3);
  assert(kernel->size[1] == 3);
  for(int i=0; i<3; i++){ assert(kernel->size[i+2] == 2 * sim->size[i]); }
}

void gpusim_alloc_ft_kernel(gpusim* sim){
  sim->ft_kernel = (float***)calloc(3, sizeof(float**));
  for(int i=0; i<3; i++){ 
    sim->ft_kernel[i] = (float**)calloc(3, sizeof(float*));
    for(int j=0; j<3; j++){
      sim->ft_kernel[i][j] = new_gpu_array(sim->len_ft_kernel_ij);
    }
  }
}

void gpusim_loadkernel(gpusim* sim, tensor* kernel){
  gpusim_checksize_kernel(sim, kernel);
  gpusim_c2cplan* plan = new_gpusim_c2cplan(kernel->size[2], kernel->size[3], kernel->size[4]);
  float* complex_kernel_ij = new_ram_array(sim->len_ft_kernel_ij);
  for(int i=0; i<3; i++){
      for(int j=0; j<3; j++){
	memcpy_r2c(tensor_get(kernel, 5, i, j, 0, 0, 0), complex_kernel_ij, sim->len_kernel_ij);
	memcpy_to_gpu(complex_kernel_ij, sim->ft_kernel[i][j], sim->len_ft_kernel_ij);
	gpusim_c2cplan_exec(plan, sim->ft_kernel[i][j], CUFFT_FORWARD);
    }
  }
  free(complex_kernel_ij);
  delete_gpusim_c2cplan(plan);
}

//_____________________________________________________________________________________________ new

gpusim* new_gpusim(int N0, int N1, int N2, tensor* kernel){
  gpusim* sim = (gpusim*)malloc(sizeof(gpusim));
  
  // init sizes
  sim->size = (int*)calloc(3, sizeof(int));
  sim->size[0] = N0; sim->size[1] = N1; sim->size[2] = N2;
  sim->N = N0 * N1 * N2;
  
  sim->paddedSize = (int*)calloc(3, sizeof(int));
  sim->paddedSize[0] = 2 * N0; sim->paddedSize[1] = 2 * N1; sim->paddedSize[2] = 2 * N2;
  sim->paddedN = sim->paddedSize[0] * sim->paddedSize[1] * sim->paddedSize[2];
  
  sim->paddedComplexSize = (int*)calloc(3, sizeof(int));
  sim->paddedComplexSize[0] = 2 * N0; sim->paddedComplexSize[1] = 2 * N1; sim->paddedComplexSize[2] = 2 * 2 * N2;
  sim->paddedComplexN = sim->paddedComplexSize[0] * sim->paddedComplexSize[1] * sim->paddedComplexSize[2];
  
  
  // init kernel
  assert(kernel->size[2] == sim->paddedSize[0]);
  assert(kernel->size[3] == sim->paddedSize[1]);
  assert(kernel->size[4] == sim->paddedSize[2]);
  sim->len_kernel_ij = sim->paddedN;		//the length of each kernel component K[i][j] (eg: Kxy)
  sim->len_ft_kernel_ij = sim->paddedComplexN;	//the length of each FFT'ed kernel component ~K[i][j] (eg: ~Kxy)
  gpusim_alloc_ft_kernel(sim);
  gpusim_loadkernel(sim, kernel);
  
  // init magnetization arrays
  sim->len_m = 3 * sim->N;
  sim->m = new_gpu_array(sim->len_m);
  sim->len_m_comp = sim->N; 
  sim->m_comp = (float**)calloc(3, sizeof(float*));
  for(int i=0; i<3; i++){ 			// slice the contiguous m array in 3 equal pieces, one for each component
    sim->m_comp[i] = &(sim->m[i * sim->len_m_comp]); 
  }
  sim->len_ft_m_i = sim->paddedComplexN;
  sim->ft_m_i = new_gpu_array(sim->len_ft_m_i);
  
  // init h
  sim->len_h = sim->len_m;
  sim->h = new_gpu_array(sim->len_h);
  sim->len_h_comp = sim->len_m_comp; 
  sim->h_comp = (float**)calloc(3, sizeof(float*));
  for(int i=0; i<3; i++){ 
    sim->h_comp[i] = &(sim->h[i * sim->len_h_comp]); // slice the contiguous h array in 3 equal pieces, one for each component
  }
  sim->len_ft_h_i = sim->len_ft_m_i;
  sim->ft_h_i = new_gpu_array(sim->len_ft_h_i);
  
  return sim;
}

//_____________________________________________________________________________________________ FFT

gpusim_c2cplan* new_gpusim_c2cplan(int N0, int N1, int N2){
  gpusim_c2cplan* plan = (gpusim_c2cplan*) malloc(sizeof(gpusim_c2cplan));
  gpusim_safe( cufftPlan3d(&(plan->handle), N0, N1, N2, CUFFT_C2C) );
  return plan;
}

void gpusim_c2cplan_exec(gpusim_c2cplan* plan, float* data, int direction){
  gpusim_safe( 
    cufftExecC2C(plan->handle, (cufftComplex*)data, (cufftComplex*)data, direction) 
  );
}

void delete_gpusim_c2cplan(gpusim_c2cplan* plan){
  //gpusim_safe( cudaFree(plan->gpudata) );
  // TODO: free handle
  free(plan);
}

//_____________________________________________________________________________________________ data management


int gpu_len(int size){
  assert(size > 0);
  int gpulen = ((size-1)/threadsPerBlock + 1) * threadsPerBlock;
  assert(gpulen % threadsPerBlock == 0);
  assert(gpulen > 0);
  return gpulen;
}

__global__ void _gpu_zero(float* list){
  int i = (blockIdx.x * blockDim.x) + threadIdx.x;
  list[i] = 0.;
}


void gpu_zero(float* data, int nElements){
  assert(nElements > 0);
  int blocks = nElements / threadsPerBlock;
  gpu_checkconf_int(blocks, threadsPerBlock);
  _gpu_zero<<<blocks, threadsPerBlock>>>(data);
}

void memcpy_to_gpu(float* source, float* dest, int nElements){
  assert(nElements > 0);
  int status = cudaMemcpy(dest, source, nElements*sizeof(float), cudaMemcpyHostToDevice);
  if(status != cudaSuccess){
    fprintf(stderr, "CUDA could not copy %d floats from host addres %p to device addres %p\n", nElements, source, dest);
    gpusim_safe(status);
  }
}


void memcpy_from_gpu(float* source, float* dest, int nElements){
  assert(nElements > 0);
  int status = cudaMemcpy(dest, source, nElements*sizeof(float), cudaMemcpyDeviceToHost);
  if(status != cudaSuccess){
    fprintf(stderr, "CUDA could not copy %d floats from device addres %p to host addres %p\n", nElements, source, dest);
    gpusim_safe(status);
  }
}

// does not seem to work.. 
void memcpy_gpu_to_gpu(float* source, float* dest, int nElements){
  assert(nElements > 0);
  int status = cudaMemcpy(dest, source, nElements*sizeof(float), cudaMemcpyHostToHost);
  if(status != cudaSuccess){
    fprintf(stderr, "CUDA could not copy %d floats from host addres %p to host addres %p\n", nElements, source, dest);
    gpusim_safe(status);
  }
}

// todo: we need cudaMalloc3D for better alignment!
float* new_gpu_array(int size){
  assert(size > 0);
  assert(size % threadsPerBlock == 0);
  float* array = NULL;
  int status = cudaMalloc((void**)(&array), size * sizeof(float));
  if(status != cudaSuccess){
    fprintf(stderr, "CUDA could not allocate %d floats\n", size);
    gpusim_safe(status);
  }
  //assert(array != NULL); // strange: it seems cuda can return 0 as a valid address?? 
  if(array == 0){
    fprintf(stderr, "cudaMalloc(%p, %ld) returned null without error status, retrying...\n", (void**)(&array), size * sizeof(float));
    abort();
  }
  return array;
}

float* new_ram_array(int size){
  assert(size > 0);
  float* array = (float*)calloc(size, sizeof(float));
  if(array == NULL){
    fprintf(stderr, "could not allocate %d floats in main memory\n", size);
    abort();
  }
  return array;
}

void memcpy_r2c(float* source, float* dest, int nReal){
  for(int i=0; i<nReal; i++){
    dest[2*i]     = source[i];
    dest[2*i + 1] = 0.;
  }
}

//_____________________________________________________________________________________________ misc

#define MAX_THREADS_PER_BLOCK 512
#define MAX_BLOCKSIZE_X 512
#define MAX_BLOCKSIZE_Y 512
#define MAX_BLOCKSIZE_Z 64

#define MAX_GRIDSIZE_Z 1

void gpu_checkconf(dim3 gridsize, dim3 blocksize){
  assert(blocksize.x * blocksize.y * blocksize.z <= MAX_THREADS_PER_BLOCK);
  assert(blocksize.x * blocksize.y * blocksize.z >  0);
  
  assert(blocksize.x <= MAX_BLOCKSIZE_X);
  assert(blocksize.y <= MAX_BLOCKSIZE_Y);
  assert(blocksize.z <= MAX_BLOCKSIZE_Z);
  
  assert(gridsize.z <= MAX_GRIDSIZE_Z);
  assert(gridsize.x > 0);
  assert(gridsize.y > 0);
  assert(gridsize.z > 0);
}

void gpu_checkconf_int(int gridsize, int blocksize){
  assert(blocksize <= MAX_BLOCKSIZE_X);
  assert(gridsize > 0);
}

void gpusim_safe(int status){
  if(status != cudaSuccess){
    fprintf(stderr, "received CUDA error: %s\n", cudaGetErrorString((cudaError_t)status));
    abort();
  }
}

#ifdef __cplusplus
}
#endif