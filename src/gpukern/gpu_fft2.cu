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


void print(char* tag, float* data, int N0, int N1, int N2){
  printf("%s\n", tag);
  for(int i=0; i<N0; i++){
    for(int j=0; j<N1; j++){
      for(int k=0; k<N2; k++){
        fprintf(stdout, "%g\t", gpu_array_get(data, i*N1*N2 + j*N2 + k));
      }
      printf("\n");
    }
    printf("\n");
  }
}


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
  gpu_safefft( cufftPlan1d(&(plan->invPlanZ), plan->paddedComplexSize[Z], CUFFT_C2R, size[X] * size[Y]) );
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

  print("input", input, size[X], size[Y], size[Z]);
  
  // (1) Zero-padding in Z direction
  /// @todo: only if necessary
  timer_start("copy_pad_1");
  gpu_copy_pad(input, buffer1, size[X], size[Y], size[Z], size[X], size[Y], paddedSize[Z]);
  cudaThreadSynchronize();
  timer_stop("copy_pad_1");

  print("buffer1", buffer1, size[X], size[Y], paddedSize[Z]);
    
  // (2) Out-of-place R2C FFT Z
  timer_start("FFT_R2C");
  gpu_safefft( cufftExecR2C(plan->fwPlanZ, (cufftReal*)buffer1,  (cufftComplex*)buffer2) );
  cudaThreadSynchronize();
  timer_stop("FFT_R2C");

  print("buffer2", buffer2, size[X], size[Y], paddedComplexSize[Z]);
  
  // (3) transpose Y-Z
  timer_start("transposeYZ");
  gpu_transposeYZ_complex(buffer2, buffer2t, size[X], size[Y], paddedComplexSize[Z]);
  cudaThreadSynchronize();
  timer_stop("transposeYZ");


  print("buffer2t", buffer2t, size[X], paddedComplexSize[Z], size[Y]);
    
  // (4) Zero-padding in Z'
  timer_start("copy_pad_2");
  gpu_copy_pad(buffer2t, buffer3, size[X], paddedComplexSize[Z], size[Y], size[X], paddedComplexSize[Z], paddedSize[Y]);
  cudaThreadSynchronize();
  timer_stop("copy_pad_2");

  print("buffer3", buffer3, size[X], paddedComplexSize[Z], paddedSize[Y]);
  
  // (5) In-place C2C FFT Y
  timer_start("FFT_Y");
  gpu_safefft( cufftExecC2C(plan->planY, (cufftComplex*)buffer3,  (cufftComplex*)buffer3, CUFFT_FORWARD) );
  cudaThreadSynchronize();
  timer_stop("FFT_Y");

  print("buffer3", buffer3, size[X], paddedComplexSize[Z], paddedSize[Y]);
  
  ///@todo stop here in the 2D case, make sure the data goes to output and not buffer3
  
  // (6) Transpose X-Z
  timer_start("transposeXZ");
  gpu_transposeXZ_complex(buffer3, buffer3t, size[X], paddedComplexSize[Z], paddedSize[Y]);
  cudaThreadSynchronize();
  timer_stop("transposeXZ");

  print("buffer3t", buffer3t, paddedSize[Y], paddedComplexSize[Z], size[X]);
  
  // (7) Zero-padding in Z''
  timer_start("copy_pad_3");
  gpu_copy_pad(buffer3t, output, paddedSize[Y], paddedComplexSize[Z], size[X], paddedSize[Y], paddedComplexSize[Z], paddedSize[X]);
  cudaThreadSynchronize();
  timer_stop("copy_pad_3");

  print("output", output, paddedSize[Y], paddedComplexSize[Z], paddedSize[X]);
    
  // (8) In-place C2C FFT X
  timer_start("FFT_X");
  gpu_safefft( cufftExecC2C(plan->planX, (cufftComplex*)output,  (cufftComplex*)output, CUFFT_FORWARD) );
  cudaThreadSynchronize();
  timer_stop("FFT_X");

  print("output", output, paddedSize[Y], paddedComplexSize[Z], paddedSize[X]);
  
}




void gpuFFT3dPlan_inverse(gpuFFT3dPlan* plan, float* input, float* output){

int* size = plan->size;
  int* paddedSize = plan->paddedSize;
  int* paddedComplexSize = plan->paddedComplexSize;
  float* buffer1 = plan->buffer1;
  float* buffer2 = plan->buffer2;
  float* buffer2t = plan->buffer2t;
  float* buffer3 = plan->buffer3;
  float* buffer3t = plan->buffer3t;
  
  // (8) In-place C2C FFT X
  timer_start("-FFT_X");
  gpu_safefft( cufftExecC2C(plan->planX, (cufftComplex*)input,  (cufftComplex*)input, CUFFT_INVERSE) );
  cudaThreadSynchronize();
  timer_stop("-FFT_X");
  
  // (7) Zero-padding in Z''
  timer_start("-copy_pad_3");
  gpu_copy_unpad(input, buffer3t,   paddedSize[Y], paddedComplexSize[Z], paddedSize[X],   paddedSize[Y], paddedComplexSize[Z], size[X]);
  cudaThreadSynchronize();
  timer_stop("-copy_pad_3");

  // (6) Transpose X-Z
  timer_start("-transposeXZ");
  gpu_transposeXZ_complex(buffer3t, buffer3, paddedSize[Y], paddedComplexSize[Z], size[X]);
  cudaThreadSynchronize();
  timer_stop("-transposeXZ");

  // (5) In-place C2C FFT Y
  timer_start("-FFT_Y");
  gpu_safefft( cufftExecC2C(plan->planY, (cufftComplex*)buffer3,  (cufftComplex*)buffer3, CUFFT_INVERSE) );
  cudaThreadSynchronize();
  timer_stop("-FFT_Y");

  // (4) Zero-padding in Z'
  timer_start("-copy_pad_2");
  gpu_copy_unpad(buffer3, buffer2t,   size[X], paddedComplexSize[Z], paddedSize[Y],    size[X], paddedComplexSize[Z], size[Y]);
  cudaThreadSynchronize();
  timer_stop("-copy_pad_2");

  // (3) transpose Y-Z
  timer_start("-transposeYZ");
  gpu_transposeYZ_complex(buffer2t, buffer2,   size[X], paddedComplexSize[Z], size[Y]);
  cudaThreadSynchronize();
  timer_stop("-transposeYZ");


  // (2) Out-of-place R2C FFT Z
  timer_start("-FFT_C2R");
  gpu_safefft( cufftExecC2R(plan->invPlanZ, (cufftComplex*)buffer2,  (cufftReal*)buffer1) );
  cudaThreadSynchronize();
  timer_stop("-FFT_C2R");

  // (1) Zero-padding in Z direction
  timer_start("-copy_pad_1");
  gpu_copy_unpad(buffer1, output,   size[X], size[Y], paddedSize[Z],   size[X], size[Y], size[Z]);
  cudaThreadSynchronize();
  timer_stop("-copy_pad_1");


}


int gpuFFT3dPlan_normalization(gpuFFT3dPlan* plan){
  return plan->paddedSize[X] * plan->paddedSize[Y] * plan->paddedSize[Z];
}


#ifdef __cplusplus
}
#endif