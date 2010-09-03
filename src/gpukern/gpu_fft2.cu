#include "gpu_fft2.h"
#include "../macros.h"
#include "gpu_transpose.h"
#include "gpu_safe.h"
#include "gpu_conf.h"
#include "gpu_mem.h"
#include "gpu_zeropad.h"
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
 * @TODO interleave with streams: fft_z(MX), transpose(MX) async, FFT_z(MY), transpose(MY) async, ... threadsync, FFT_Y(MX)...
 */
gpuFFT3dPlan* new_gpuFFT3dPlan_padded(int* size, int* paddedSize){
  
  int N0 = size[X];
  int N1 = size[Y];
  int N2 = size[Z];
  
  assert(paddedSize[X] > 0);
  assert(paddedSize[Y] > 1);
  assert(paddedSize[Z] > 1);
  
  gpuFFT3dPlan* plan = (gpuFFT3dPlan*)malloc(sizeof(gpuFFT3dPlan));
  
  plan->size = (int*)calloc(3, sizeof(int));
  plan->paddedSize = (int*)calloc(3, sizeof(int));
  plan->paddedComplexSize = (int*)calloc(3, sizeof(int));
  int* paddedComplexSize = plan->paddedComplexSize;
  
  plan->size[0] = N0; 
  plan->size[1] = N1; 
  plan->size[2] = N2;
  //plan->N = N0 * N1 * N2;
  
  plan->paddedSize[X] = paddedSize[X];
  plan->paddedSize[Y] = paddedSize[Y];
  plan->paddedSize[Z] = paddedSize[Z];
  plan->paddedN = plan->paddedSize[0] * plan->paddedSize[1] * plan->paddedSize[2];

  /* We do not use additional padding to match the GPU stride, as the CUFFT R2C/C2R transforms always "break" the alignment anyway.
   * Rather, the first transform is out-of-place so that at least the input data is aligned. After transposing, the alignment is OK again.
   */
  plan->paddedComplexSize[X] = plan->paddedSize[X];
  plan->paddedComplexSize[Y] = plan->paddedSize[Y];
  plan->paddedComplexSize[Z] = plan->paddedSize[Z] + 2;
  plan->paddedComplexN = paddedComplexSize[X] * paddedComplexSize[Y] * paddedComplexSize[Z];
  

  gpu_safefft( cufftPlan1d(&(plan->fwPlanZ),  plan->paddedSize[Z], CUFFT_R2C, size[X] * size[Y]) );
  gpu_safefft( cufftPlan1d(&(plan->invPlanZ), plan->paddedSize[Z], CUFFT_C2R, size[X] * size[Y]) );
  gpu_safefft( cufftPlan1d(&(plan->planY), plan->paddedSize[Y], CUFFT_C2C, paddedComplexSize[Z] * size[X] / 2) ); // IMPORTANT: the /2 is necessary because the complex transforms have only half the amount of elements (the elements are now complex numbers)
  gpu_safefft( cufftPlan1d(&(plan->planX), plan->paddedSize[X], CUFFT_C2C, paddedComplexSize[Z] * paddedSize[Y] / 2) );
  
  plan->buffer1  = new_gpu_array(size[X] * size[Y] * paddedSize[Z]);               // padding in Z direction
  plan->buffer2  = new_gpu_array(size[X] * size[Y] * paddedComplexSize[Z]);        // half complex
  plan->buffer2t = new_gpu_array(size[X] * paddedComplexSize[Z] * size[Y]);        // transposed @todo: get rid of: combine transpose+pad in one operation
  plan->buffer3  = new_gpu_array(size[X] * paddedComplexSize[Z] * paddedSize[Y]);  //transposed and padded
  plan->buffer3t = new_gpu_array(paddedSize[Y] * paddedComplexSize[Z] * size[X]);  //transposed @todo: get rid of: combine transpose+pad in one operation
  //output size  :               paddedSize[Y] * paddedComplexSize[Z] * paddedSize[X]
  
  return plan;
}


gpuFFT3dPlan* new_gpuFFT3dPlan(int* size){
  return new_gpuFFT3dPlan_padded(size, size); // when size == paddedsize, there is no padding
}

void gpuFFT3dPlan_forward(gpuFFT3dPlan* plan, float* input, float* output){
  
  int* size = plan->size;
  int* paddedSize = plan->paddedSize;
  int* paddedComplexSize = plan->paddedComplexSize;
  float* buffer1 = plan->buffer1;
  float* buffer2 = plan->buffer2;
  float* buffer2t = plan->buffer2t;
  float* buffer3 = plan->buffer3;
  float* buffer3t = plan->buffer3t;
  
//   int* complexSize = plan->paddedComplexSize;
//   int N0 = complexSize[X];
//   int N1 = complexSize[Y];
//   int N2 = complexSize[Z]/2; // we treat the complex data as an N0 x N1 x N2 x 2 array
//   int N3 = 2;

  // (1) Zero-padding in Z direction
  /// @todo: only if necessary
  timer_start("copy_pad_1");
  gpu_copy_pad(input, buffer1, size[X], size[Y], size[Z], size[X], size[Y], paddedSize[Z]);
  cudaThreadSynchronize();
  timer_stop("copy_pad_1");

  // (2) Out-of-place R2C FFT
  timer_start("FFT_R2C");
  gpu_safefft( cufftExecR2C(plan->fwPlanZ, (cufftReal*)buffer1,  (cufftComplex*)buffer2) );
  cudaThreadSynchronize();
  timer_stop("FFT_R2C");

  // (3) transpose Y-Z
  timer_start("transposeYZ");
  gpu_transposeYZ_complex(buffer2, buffer2t, size[X], size[Y], paddedComplexSize[Z]);
  cudaThreadSynchronize();
  timer_stop("transposeYZ");

  // (4) Zero-padding in Z'
  timer_start("copy_pad_2");
  gpu_copy_pad(buffer2t, buffer3, size[X], paddedComplexSize[Z], size[Y], size[X], paddedComplexSize[Z], paddedSize[Y]);
  cudaThreadSynchronize();
  timer_stop("copy_pad_2");

  // (5) In-place C2C FFT
  timer_start("FFT_Y");
  gpu_safefft( cufftExecR2C(plan->fwPlanY, (cufftComplex*)buffer3,  (cufftComplex*)buffer3) );
  cudaThreadSynchronize();
  timer_stop("FFT_Y");

  ///@todo stop here in the 2D case, make sure the data goes to output and not buffer3
  
  // (6) Transpose X-Z
  timer_start("transposeXZ");
  gpu_transposeXZ_complex(buffer3, buffer3t, size[X], paddedComplexSize[Z], paddedSize[Y]);
  cudaThreadSynchronize();
  timer_stop("transposeXZ");

  // (7) Zero-padding in Z''
  timer_start("copy_pad_3");
  gpu_copy_pad(buffer3t, output, paddedSize[Y], paddedComplexSize[Z], size[X], paddedSize[Y], paddedComplexSize[Z], paddedSize[X]);
  cudaThreadSynchronize();
  timer_stop("copy_pad_3");
  
 /* 
  timer_start("FFT_Y");
  gpu_safefft( cufftExecC2C(plan->planY, (cufftComplex*)data2,  (cufftComplex*)data2, CUFFT_FORWARD) ); 
  cudaThreadSynchronize();
  timer_stop("FFT_Y");

  // support for 2D transforms: do not transform if first dimension has size 1
  if(N0 > 1){
    gpu_transposeXZ_complex(data2, data, N0, N2, N1*N3); // size has changed due to previous transpose! // it's now in data2
    timer_start("FFT_X");
    gpu_safefft( cufftExecC2C(plan->planX, (cufftComplex*)data,  (cufftComplex*)output, CUFFT_FORWARD) ); // it's now again in data
    timer_stop("FFT_X");
    cudaThreadSynchronize();
  }
  else
    memcpy_on_gpu(data2, data, plan->paddedComplexN);             // for N0=1, it's now again in data

  cudaThreadSynchronize();*/
}




void gpuFFT3dPlan_inverse(gpuFFT3dPlan* plan, float* input, float* output){

/*  
  int* size = plan->size;
  int* pSSize = plan->paddedComplexSize;
  int N0 = pSSize[X];
  int N1 = pSSize[Y];
  int N2 = pSSize[Z]/2; // we treat the complex data as an N0 x N1 x N2 x 2 array
  int N3 = 2;
  
  float* data = input;
  float* data2 = plan->transp; // both the transpose and FFT are out-of-place between data and data2

  if (N0 > 1){
    // input data is XZ transposed and stored in data, FFTs on X-arrays out of place towards data2
    timer_start("FFT_X");
    gpu_safefft( cufftExecC2C(plan->planX, (cufftComplex*)data,  (cufftComplex*)data2, CUFFT_INVERSE) ); // it's now in data2
    cudaThreadSynchronize();
    timer_stop("FFT_X");
    gpu_transposeXZ_complex(data2, data, N1, N2, N0*N3); // size has changed due to previous transpose! // it's now in data
  }

  timer_start("FFT_Y");
	gpu_safefft( cufftExecC2C(plan->planY, (cufftComplex*)data,  (cufftComplex*)data2, CUFFT_INVERSE) ); // it's now again in data2
  cudaThreadSynchronize();
  timer_stop("FFT_Y");

  gpu_transposeYZ_complex(data2, data, N0, N2, N1*N3);                 

/*	for(int i=0; i<size[X]; i++){
    for(int j=0; j<size[Y]; j++){
      float* rowIn  = &( input[i * pSSize[Y] * pSSize[Z] + j * pSSize[Z]]);
      float* rowOut = &(output[i * pSSize[Y] * pSSize[Z] + j * pSSize[Z]]);
      gpu_safe( cufftExecC2R(plan->invPlanZ, (cufftComplex*)rowIn, (cufftReal*)rowOut) ); 
    }
  }
  timer_start("FFT_Z");
  for(int i=0; i<size[X]; i++){
    float* rowIn  = &( input[i * pSSize[Y] * pSSize[Z]]);
    float* rowOut = &(output[i * pSSize[Y] * pSSize[Z]]);
    gpu_safefft( cufftExecC2R(plan->invPlanZ, (cufftComplex*)rowIn, (cufftReal*)rowOut) ); 
  }
  cudaThreadSynchronize();
  timer_stop("FFT_Z");*/
}


int gpuFFT3dPlan_normalization(gpuFFT3dPlan* plan){
  return plan->paddedSize[X] * plan->paddedSize[Y] * plan->paddedSize[Z];
}

//_____________________________________________________________________________________________ transpose




// //Copied from gpufft by Ben ***********************************************************************
// void gpu_transposeXZ_complex(float* source, float* dest, int N0, int N1, int N2){
//   timer_start("transposeXZ"); /// @todo section is double-timed with FFT exec
// 
//   if(source != dest){ // must be out-of-place
// 
//   // we treat the complex array as a N0 x N1 x N2 x 2 real array
//   // after transposing it becomes N0 x N2 x N1 x 2
//   N2 /= 2;  ///@todo: should have new variable here!
//   //int N3 = 2;
// 
//   dim3 gridsize(N0, N1, 1); ///@todo generalize!
//   dim3 blocksize(N2, 1, 1);
//   gpu_checkconf(gridsize, blocksize);
//   _gpu_transposeXZ_complex<<<gridsize, blocksize>>>(source, dest, N0, N1, N2);
//   cudaThreadSynchronize();
// 
//   }
// /*  else{
//     gpu_transposeXZ_complex_inplace(source, N0, N1, N2*2); ///@todo see above
//   }*/
//   timer_stop("transposeXZ");
// }
// 
// __global__ void _gpu_transposeXZ_complex(float* source, float* dest, int N0, int N1, int N2){
//     // N0 <-> N2
//     // i  <-> k
//     int N3 = 2;
// 
//     int i = blockIdx.x;
//     int j = blockIdx.y;
//     int k = threadIdx.x;
// 
//     dest[k*N1*N0*N3 + j*N0*N3 + i*N3 + 0] = source[i*N1*N2*N3 + j*N2*N3 + k*N3 + 0];
//     dest[k*N1*N0*N3 + j*N0*N3 + i*N3 + 1] = source[i*N1*N2*N3 + j*N2*N3 + k*N3 + 1];
// }
// 
// 
// void gpu_transposeYZ_complex(float* source, float* dest, int N0, int N1, int N2){
//   timer_start("transposeYZ");
// 
//   if(source != dest){ // must be out-of-place
// 
//   // we treat the complex array as a N0 x N1 x N2 x 2 real array
//   // after transposing it becomes N0 x N2 x N1 x 2
//   N2 /= 2;
//   //int N3 = 2;
// 
//   dim3 gridsize(N0, N1, 1); ///@todo generalize!
//   dim3 blocksize(N2, 1, 1);
//   gpu_checkconf(gridsize, blocksize);
//   _gpu_transposeYZ_complex<<<gridsize, blocksize>>>(source, dest, N0, N1, N2);
//   cudaThreadSynchronize();
//   }
// /*  else{
//     gpu_transposeYZ_complex_inplace(source, N0, N1, N2*2); ///@todo see above
//   }*/
//   timer_stop("transposeYZ");
// }
// 
// __global__ void _gpu_transposeYZ_complex(float* source, float* dest, int N0, int N1, int N2){
//     // N1 <-> N2
//     // j  <-> k
// 
//     int N3 = 2;
// 
//         int i = blockIdx.x;
//     int j = blockIdx.y;
//     int k = threadIdx.x;
// 
// //      int index_dest = i*N2*N1*N3 + k*N1*N3 + j*N3;
// //      int index_source = i*N1*N2*N3 + j*N2*N3 + k*N3;
// 
// 
//     dest[i*N2*N1*N3 + k*N1*N3 + j*N3 + 0] = source[i*N1*N2*N3 + j*N2*N3 + k*N3 + 0];
//     dest[i*N2*N1*N3 + k*N1*N3 + j*N3 + 1] = source[i*N1*N2*N3 + j*N2*N3 + k*N3 + 1];
// /*    dest[index_dest + 0] = source[index_source + 0];
//     dest[index_dest + 1] = source[index_source + 1];*/
// }



// //_____________________________________________________________________________________________ exec plan
// 
// void gpu_plan3d_real_input_forward(gpu_plan3d_real_input* plan, float* data){
//   timer_start("gpu_plan3d_real_input_forward_exec");
// 
//   int* size = plan->size;
//   int* pSSize = plan->paddedComplexSize;
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
// 	gpu_safe( cudaFree(plan->paddedComplexSize) );
// 	free(plan);
// 
// }


#ifdef __cplusplus
}
#endif