#include "gpufft2.h"
#include "gpufft.h"
#include "gputil.h"
#include "timer.h"
#include <stdio.h>
#include <assert.h>

#ifdef __cplusplus
extern "C" {
#endif


/**
 * Creates a new FFT plan for transforming the magnetization. 
 * Zero-padding in each dimension is optional, and rows with
 * only zero's are not transformed.
 * @todo on compute capability < 2.0, the first step is done serially...
 * @todo rename kernelsize -> paddedsize
 */
gpuFFT3dPlan* new_gpuFFT3dPlan_padded(int* size, int* paddedSize){
  
  int N0 = size[X];
  int N1 = size[Y];
  int N2 = size[Z];
  
  assert(paddedSize[X] > 0);
  assert(paddedSize[Y] > 1);
  assert(paddedSize[Z] > 1);
  
  gpuFFT3dPlan* plan = (gpuFFT3dPlan*)malloc(sizeof(gpuFFT3dPlan));
  
  plan->size = (int*)calloc(3, sizeof(int));    ///@todo not int* but int[3]
  plan->paddedSize = (int*)calloc(3, sizeof(int));
  plan->paddedStorageSize = (int*)calloc(3, sizeof(int));
  
//   int* paddedSize = plan->paddedSize;
  int* paddedStorageSize = plan->paddedStorageSize;
  
  plan->size[0] = N0; 
  plan->size[1] = N1; 
  plan->size[2] = N2;
  plan->N = N0 * N1 * N2;
  
  plan->paddedSize[X] = paddedSize[X];
  plan->paddedSize[Y] = paddedSize[Y];
  plan->paddedSize[Z] = paddedSize[Z];
  plan->paddedN = plan->paddedSize[0] * plan->paddedSize[1] * plan->paddedSize[2];
  
  plan->paddedStorageSize[X] = plan->paddedSize[X];
  plan->paddedStorageSize[Y] = plan->paddedSize[Y];
  plan->paddedStorageSize[Z] = gpu_pad_to_stride( plan->paddedSize[Z] + 2 );
  plan->paddedStorageN = paddedStorageSize[X] * paddedStorageSize[Y] * paddedStorageSize[Z];
  
  ///@todo check these sizes !
  gpu_safe( cufftPlan1d(&(plan->fwPlanZ), plan->paddedSize[Z], CUFFT_R2C, 1) );
  gpu_safe( cufftPlan1d(&(plan->planY), plan->paddedSize[Y], CUFFT_C2C, paddedStorageSize[Z] * size[X] / 2) );          // IMPORTANT: the /2 is necessary because the complex transforms have only half the amount of elements (the elements are now complex numbers)
  gpu_safe( cufftPlan1d(&(plan->planX), plan->paddedSize[X], CUFFT_C2C, paddedStorageSize[Z] * paddedSize[Y] / 2) );
  gpu_safe( cufftPlan1d(&(plan->invPlanZ), plan->paddedSize[Z], CUFFT_C2R, 1) );
  
  plan->transp = new_gpu_array(plan->paddedStorageN);
  
  return plan;
}


gpuFFT3dPlan* new_gpuFFT3dPlan(int* size){
  return new_gpuFFT3dPlan_padded(size, size); // when size == paddedsize, there is no padding
}


void gpuFFT3dPlan_forward(gpuFFT3dPlan* plan, tensor* input, tensor* output){
  assertDevice(input->list);
  assertDevice(output->list);
  assert(input->list == output->list); ///@todo works only in-place for now
  assert(input->rank == 3);
  assert(output->rank == 3);
  for(int i=0; i<3; i++){
    assert( input->size[i] == plan->paddedStorageSize[i]);
    assert(output->size[i] == plan->paddedStorageSize[i]);
  }
  
  gpuFFT3dPlan_forward_unsafe(plan, input->list, output->list);
}


void gpuFFT3dPlan_forward_unsafe(gpuFFT3dPlan* plan, float* input, float* output){

  int* size = plan->size;
  int* pSSize = plan->paddedStorageSize;
  int N0 = pSSize[X];
  int N1 = pSSize[Y];
  int N2 = pSSize[Z]/2; // we treat the complex data as an N0 x N1 x N2 x 2 array
  int N3 = 2;
  int N = N0*N1*N2*N3;
  float* transp = plan->transp;

  timer_start("FFT_z");
  for(int i=0; i<size[X]; i++){
    for(int j=0; j<size[Y]; j++){
      float* rowIn  = &( input[i * pSSize[Y] * pSSize[Z] + j * pSSize[Z]]);
      float* rowOut = &(output[i * pSSize[Y] * pSSize[Z] + j * pSSize[Z]]);
      gpu_safe( cufftExecR2C(plan->fwPlanZ, (cufftReal*)rowIn,  (cufftComplex*)rowOut) );
    }
  }
  cudaThreadSynchronize();
  timer_stop("FFT_z");

  gpu_transposeYZ_complex(output, transp, N0, N1, N2*N3);
  memcpy_gpu_to_gpu(transp, input, N);

  timer_start("FFT_y");
  gpu_safe( cufftExecC2C(plan->planY, (cufftComplex*)input,  (cufftComplex*)output, CUFFT_FORWARD) );
  cudaThreadSynchronize();
  timer_stop("FFT_y");

  // support for 2D transforms: do not transform if first dimension has size 1
  if(N0 > 1){
    gpu_transposeXZ_complex(output, transp, N0, N2, N1*N3); // size has changed due to previous transpose!
    memcpy_gpu_to_gpu(transp, input, N);
    timer_start("FFT_x");
    gpu_safe( cufftExecC2C(plan->planX, (cufftComplex*)input,  (cufftComplex*)output, CUFFT_FORWARD) );
    cudaThreadSynchronize();
    timer_stop("FFT_x");
  }

}


void gpuFFT3dPlan_inverse(gpuFFT3dPlan* plan, tensor* input, tensor* output){
  assertDevice(input->list);
  assertDevice(output->list);
  assert(input->list == output->list); ///@todo works only in-place for now
  assert(input->rank == 3);
  assert(output->rank == 3);
  for(int i=0; i<3; i++){
    assert( input->size[i] == plan->paddedStorageSize[i]);
    assert(output->size[i] == plan->paddedStorageSize[i]);
  }
  gpuFFT3dPlan_inverse_unsafe(plan, input->list, output->list);
}

void gpuFFT3dPlan_inverse_unsafe(gpuFFT3dPlan* plan, float* input, float* output){
  
  int* size = plan->size;
  int* pSSize = plan->paddedStorageSize;
  int N0 = pSSize[X];
  int N1 = pSSize[Y];
  int N2 = pSSize[Z]/2; // we treat the complex data as an N0 x N1 x N2 x 2 array
  int N3 = 2;
  int N = N0*N1*N2*N3;
  float* transp = plan->transp;

  if (N0 > 1){
    // input data is XZ transposed
    timer_start("FFT_x");
    gpu_safe( cufftExecC2C(plan->planX, (cufftComplex*)input,  (cufftComplex*)output, CUFFT_INVERSE) );
    cudaThreadSynchronize();
    timer_stop("FFT_x");
    gpu_transposeXZ_complex(output, transp, N1, N2, N0*N3); // size has changed due to previous transpose!
    memcpy_gpu_to_gpu(transp, input, N);
  }

  timer_start("FFT_y");
	gpu_safe( cufftExecC2C(plan->planY, (cufftComplex*)input,  (cufftComplex*)output, CUFFT_INVERSE) );
  cudaThreadSynchronize();
  timer_stop("FFT_y");
  
  gpu_transposeYZ_complex(output, transp, N0, N2, N1*N3);
  memcpy_gpu_to_gpu(transp, input, N);

  timer_start("FFT_z");
	for(int i=0; i<size[X]; i++){
    for(int j=0; j<size[Y]; j++){
      float* rowIn  = &( input[i * pSSize[Y] * pSSize[Z] + j * pSSize[Z]]);
      float* rowOut = &(output[i * pSSize[Y] * pSSize[Z] + j * pSSize[Z]]);
      gpu_safe( cufftExecC2R(plan->invPlanZ, (cufftComplex*)rowIn, (cufftReal*)rowOut) ); 
    }
  }
  cudaThreadSynchronize();
  timer_stop("FFT_z");
}


int gpuFFT3dPlan_normalization(gpuFFT3dPlan* plan){
  return plan->paddedSize[X] * plan->paddedSize[Y] * plan->paddedSize[Z];
}

//_____________________________________________________________________________________________ transpose

void gpu_tensor_transposeYZ_complex(tensor* source, tensor* dest){
	
  assert(source != dest);                       // must be out-of-place
  assert(source->rank == 3);
  assert(dest->rank == 3);
  assert(dest->size[Y] == source->size[Z]/2);   // interleaved complex format
  assert(dest->size[Z] == source->size[Y]*2);
  
  timer_start("transposeYZ");
  
  // we treat the complex array as a N0 x N1 x N2 x 2 real array
  // after transposing it becomes N0 x N2 x N1 x 2
  int N0 = source->size[X];
  int N1 = source->size[Y];
  int N2 = source->size[Z] / 2;
  //int N3 = 2; // not used
  
  dim3 gridsize(N0, N1, 1);  ///@todo generalize!
  dim3 blocksize(N2, 1, 1);
  gpu_checkconf(gridsize, blocksize);
  _gpu_transposeYZ_complex<<<gridsize, blocksize>>>(source->list, dest->list, N0, N1, N2);
  cudaThreadSynchronize();
  
  timer_stop("transposeYZ");
}

void gpu_tensor_transposeXZ_complex(tensor* source, tensor* dest){
  assert(source != dest);                       // must be out-of-place
  assert(source->rank == 3);
  assert(dest->rank == 3);
  assert(dest->size[X] == source->size[Z]/2);   // interleaved complex format
  assert(dest->size[Z] == source->size[X]*2);
  
  timer_start("transposeXZ");
  
  // we treat the complex array as a N0 x N1 x N2 x 2 real array
  // after transposing it becomes N0 x N2 x N1 x 2
  int N0 = source->size[X];
  int N1 = source->size[Y];
  int N2 = source->size[Z] / 2;
  //int N3 = 2; // not used
  
  dim3 gridsize(N0, N1, 1);  ///@todo generalize!
  dim3 blocksize(N2, 1, 1);
  gpu_checkconf(gridsize, blocksize);
  _gpu_transposeXZ_complex<<<gridsize, blocksize>>>(source->list, dest->list, N0, N1, N2);
  cudaThreadSynchronize();
  
  timer_stop("transposeXZ");
}


//Copied from gpufft by Ben ***********************************************************************
void gpu_transposeXZ_complex(float* source, float* dest, int N0, int N1, int N2){
  timer_start("transposeXZ"); /// @todo section is double-timed with FFT exec

  if(source != dest){ // must be out-of-place

  // we treat the complex array as a N0 x N1 x N2 x 2 real array
  // after transposing it becomes N0 x N2 x N1 x 2
  N2 /= 2;  ///@todo: should have new variable here!
  //int N3 = 2;

  dim3 gridsize(N0, N1, 1); ///@todo generalize!
  dim3 blocksize(N2, 1, 1);
  gpu_checkconf(gridsize, blocksize);
  _gpu_transposeXZ_complex<<<gridsize, blocksize>>>(source, dest, N0, N1, N2);
  cudaThreadSynchronize();

  }
/*  else{
    gpu_transposeXZ_complex_inplace(source, N0, N1, N2*2); ///@todo see above
  }*/
  timer_stop("transposeXZ");
}

__global__ void _gpu_transposeXZ_complex(float* source, float* dest, int N0, int N1, int N2){
    // N0 <-> N2
    // i  <-> k
    int N3 = 2;

    int i = blockIdx.x;
    int j = blockIdx.y;
    int k = threadIdx.x;

    dest[k*N1*N0*N3 + j*N0*N3 + i*N3 + 0] = source[i*N1*N2*N3 + j*N2*N3 + k*N3 + 0];
    dest[k*N1*N0*N3 + j*N0*N3 + i*N3 + 1] = source[i*N1*N2*N3 + j*N2*N3 + k*N3 + 1];
}


void gpu_transposeYZ_complex(float* source, float* dest, int N0, int N1, int N2){
  timer_start("transposeYZ");

  if(source != dest){ // must be out-of-place

  // we treat the complex array as a N0 x N1 x N2 x 2 real array
  // after transposing it becomes N0 x N2 x N1 x 2
  N2 /= 2;
  //int N3 = 2;

  dim3 gridsize(N0, N1, 1); ///@todo generalize!
  dim3 blocksize(N2, 1, 1);
  gpu_checkconf(gridsize, blocksize);
  _gpu_transposeYZ_complex<<<gridsize, blocksize>>>(source, dest, N0, N1, N2);
  cudaThreadSynchronize();
  }
/*  else{
    gpu_transposeYZ_complex_inplace(source, N0, N1, N2*2); ///@todo see above
  }*/
  timer_stop("transposeYZ");
}

__global__ void _gpu_transposeYZ_complex(float* source, float* dest, int N0, int N1, int N2){
    // N1 <-> N2
    // j  <-> k

    int N3 = 2;

        int i = blockIdx.x;
    int j = blockIdx.y;
    int k = threadIdx.x;

//      int index_dest = i*N2*N1*N3 + k*N1*N3 + j*N3;
//      int index_source = i*N1*N2*N3 + j*N2*N3 + k*N3;


    dest[i*N2*N1*N3 + k*N1*N3 + j*N3 + 0] = source[i*N1*N2*N3 + j*N2*N3 + k*N3 + 0];
    dest[i*N2*N1*N3 + k*N1*N3 + j*N3 + 1] = source[i*N1*N2*N3 + j*N2*N3 + k*N3 + 1];
/*    dest[index_dest + 0] = source[index_source + 0];
    dest[index_dest + 1] = source[index_source + 1];*/
}



// //_____________________________________________________________________________________________ exec plan
// 
// void gpu_plan3d_real_input_forward(gpu_plan3d_real_input* plan, float* data){
//   timer_start("gpu_plan3d_real_input_forward_exec");
// 
//   int* size = plan->size;
//   int* pSSize = plan->paddedStorageSize;
//   int N0 = pSSize[X];
//   int N1 = pSSize[Y];
//   int N2 = pSSize[Z]/2; // we treat the complex data as an N0 x N1 x N2 x 2 array
//   int N3 = 2;
//   
//   float* data2 = plan->transp; // both the transpose and FFT are out-of-place between data and data2
//   
//   for(int i=0; i<size[X]; i++){
//     for(int j=0; j<size[Y]; j++){
//       float* row = &(data[i * pSSize[Y] * pSSize[Z] + j * pSSize[Z]]);
//       gpu_safe( cufftExecR2C(plan->fwPlanZ, (cufftReal*)row,  (cufftComplex*)row) ); // all stays in data
//     }
//   }
//   cudaThreadSynchronize();
//   
//   gpu_transposeYZ_complex(data, data2, N0, N1, N2*N3);					// it's now in data2
//   gpu_safe( cufftExecC2C(plan->planY, (cufftComplex*)data2,  (cufftComplex*)data2, CUFFT_FORWARD) ); // it's now again in data
//   cudaThreadSynchronize();
//   
//   gpu_transposeXZ_complex(data2, data, N0, N2, N1*N3); // size has changed due to previous transpose! // it's now in data2
//   gpu_safe( cufftExecC2C(plan->planX, (cufftComplex*)data,  (cufftComplex*)data, CUFFT_FORWARD) ); // it's now again in data
//   cudaThreadSynchronize();
//   
//   timer_stop("gpu_plan3d_real_input_forward_exec");
// }
// 
// void gpu_plan3d_real_input_inverse(gpu_plan3d_real_input* plan, float* data){
//   
// }
// 
// void delete_gpu_plan3d_real_input(gpu_plan3d_real_input* plan){
//   
// 	gpu_safe( cufftDestroy(plan->fwPlanZ) );
// 	gpu_safe( cufftDestroy(plan->invPlanZ) );
// 	gpu_safe( cufftDestroy(plan->planY) );
// 	gpu_safe( cufftDestroy(plan->planX) );
// 
// 	gpu_safe( cudaFree(plan->transp) ); 
// 	gpu_safe( cudaFree(plan->size) );
// 	gpu_safe( cudaFree(plan->paddedSize) );
// 	gpu_safe( cudaFree(plan->paddedStorageSize) );
// 	free(plan);
// 
// }


#ifdef __cplusplus
}
#endif