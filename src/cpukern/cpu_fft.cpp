#include "cpu_fft.h"
#include "cpu_mem.h"
#include "fftw3.h"
#include "../macros.h"
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

///@todo cleanup

/**
 * @internal 
 * Creates a new FFT plan for transforming the magnetization. 
 * Zero-padding in each dimension is optional, and rows with
 * only zero's are not transformed.
 * @todo on compute capability < 2.0, the first step is done serially...
 * @todo rename kernelsize -> paddedsize
 */
cpuFFT3dPlan* new_cpuFFT3dPlan_padded(int* size, int* paddedSize, float* source, float* dest){
  
  int N0 = size[X];
  int N1 = size[Y];
  int N2 = size[Z];
  
  assert(paddedSize[X] > 0);
  assert(paddedSize[Y] > 1);
  assert(paddedSize[Z] > 1);
  
  cpuFFT3dPlan* plan = (cpuFFT3dPlan*)malloc(sizeof(cpuFFT3dPlan));
  
  plan->size = (int*)calloc(3, sizeof(int));
  plan->paddedSize = (int*)calloc(3, sizeof(int));
  
  plan->size[0] = N0; 
  plan->size[1] = N1; 
  plan->size[2] = N2;
  
  plan->paddedSize[X] = paddedSize[X];
  plan->paddedSize[Y] = paddedSize[Y];
  plan->paddedSize[Z] = paddedSize[Z];
  
//   plan->paddedStorageSize[X] = plan->paddedSize[X];
//   plan->paddedStorageSize[Y] = plan->paddedSize[Y];
//   plan->paddedStorageSize[Z] = cpu_pad_to_stride( plan->paddedSize[Z] + 2 );
//   plan->paddedStorageN = paddedStorageSize[X] * paddedStorageSize[Y] * paddedStorageSize[Z];

  ///@todo Check for NULL return value: plan could not be created
  plan->fwPlan = fftwf_plan_dft_r2c_3d(paddedSize[X], paddedSize[Y], paddedSize[Z], source, (complex_t*)dest, FFTW_ESTIMATE); // replace by FFTW_PATIENT for super-duper performance
  plan->bwPlan = fftwf_plan_dft_c2r_3d(paddedSize[X], paddedSize[Y], paddedSize[Z], (complex_t*)source, dest, FFTW_ESTIMATE);
  
  ///@todo check these sizes !
//   cpu_safe( cufftPlan1d(&(plan->fwPlanZ), plan->paddedSize[Z], CUFFT_R2C, 1) );
//   cpu_safe( cufftPlan1d(&(plan->planY), plan->paddedSize[Y], CUFFT_C2C, paddedStorageSize[Z] * size[X] / 2) );          // IMPORTANT: the /2 is necessary because the complex transforms have only half the amount of elements (the elements are now complex numbers)
//   cpu_safe( cufftPlan1d(&(plan->planX), plan->paddedSize[X], CUFFT_C2C, paddedStorageSize[Z] * paddedSize[Y] / 2) );
//   cpu_safe( cufftPlan1d(&(plan->invPlanZ), plan->paddedSize[Z], CUFFT_C2R, 1) );
//   
//   plan->transp = new_cpu_array(plan->paddedStorageN);
  
  return plan;
}

void delete_cpuFFT3dPlan(cpuFFT3dPlan* plan){
  //TODO
}

cpuFFT3dPlan* new_cpuFFT3dPlan_outplace(int* datasize, int* paddedSize){
  int paddedN = paddedSize[X] * paddedSize[Y] * (paddedSize[Z]+2);
  float* in = new_cpu_array(paddedN);
  float* out = new_cpu_array(paddedN);
  cpuFFT3dPlan* plan = new_cpuFFT3dPlan_padded(datasize, paddedSize, in, out);
  free_cpu_array(in);
  free_cpu_array(out);
  return plan;
}


cpuFFT3dPlan* new_cpuFFT3dPlan_inplace(int* datasize, int* paddedSize){
  int paddedN = paddedSize[X] * paddedSize[Y] * (paddedSize[Z]+2);
  float* in = new_cpu_array(paddedN);
  cpuFFT3dPlan* plan = new_cpuFFT3dPlan_padded(datasize, paddedSize, in, in);
  free_cpu_array(in);
  return plan;
}
                                      
// cpuFFT3dPlan* new_cpuFFT3dPlan(int* size){
//   return new_cpuFFT3dPlan_padded(size, size); // when size == paddedsize, there is no padding
// }


// void cpuFFT3dPlan_forward(cpuFFT3dPlan* plan, tensor* input, tensor* output){
//   assertDevice(input->list);
//   assertDevice(output->list);
//   assert(input->list == output->list); ///@todo works only in-place for now
//   assert(input->rank == 3);
//   assert(output->rank == 3);
//   for(int i=0; i<3; i++){
//     assert( input->size[i] == plan->paddedStorageSize[i]);
//     assert(output->size[i] == plan->paddedStorageSize[i]);
//   }
//   
//   cpuFFT3dPlan_forward_unsafe(plan, input->list, output->list);
// }


void cpuFFT3dPlan_forward(cpuFFT3dPlan* plan, float* input, float* output){
  fftwf_execute_dft_r2c((fftwf_plan) plan->fwPlan, input, (complex_t*)output);

}


// void cpuFFT3dPlan_inverse(cpuFFT3dPlan* plan, tensor* input, tensor* output){
//   assertDevice(input->list);
//   assertDevice(output->list);
//   assert(input->list == output->list); ///@todo works only in-place for now
//   assert(input->rank == 3);
//   assert(output->rank == 3);
//   for(int i=0; i<3; i++){
//     assert( input->size[i] == plan->paddedStorageSize[i]);
//     assert(output->size[i] == plan->paddedStorageSize[i]);
//   }
//   cpuFFT3dPlan_inverse_unsafe(plan, input->list, output->list);
// }

void cpuFFT3dPlan_inverse(cpuFFT3dPlan* plan, float* input, float* output){
  fftwf_execute_dft_c2r((fftwf_plan) plan->bwPlan, (complex_t*)input, output);
}


// int cpuFFT3dPlan_normalization(cpuFFT3dPlan* plan){
//   return plan->paddedSize[X] * plan->paddedSize[Y] * plan->paddedSize[Z];
// }
// 


// //_____________________________________________________________________________________________ exec plan
// 
// void cpu_plan3d_real_input_forward(cpu_plan3d_real_input* plan, float* data){
//   timer_start("cpu_plan3d_real_input_forward_exec");
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
//       cpu_safe( cufftExecR2C(plan->fwPlanZ, (cufftReal*)row,  (cufftComplex*)row) ); // all stays in data
//     }
//   }
//   cudaThreadSynchronize();
//   
//   cpu_transposeYZ_complex(data, data2, N0, N1, N2*N3);                   // it's now in data2
//   cpu_safe( cufftExecC2C(plan->planY, (cufftComplex*)data2,  (cufftComplex*)data2, CUFFT_FORWARD) ); // it's now again in data
//   cudaThreadSynchronize();
//   
//   cpu_transposeXZ_complex(data2, data, N0, N2, N1*N3); // size has changed due to previous transpose! // it's now in data2
//   cpu_safe( cufftExecC2C(plan->planX, (cufftComplex*)data,  (cufftComplex*)data, CUFFT_FORWARD) ); // it's now again in data
//   cudaThreadSynchronize();
//   
//   timer_stop("cpu_plan3d_real_input_forward_exec");
// }
// 
// void cpu_plan3d_real_input_inverse(cpu_plan3d_real_input* plan, float* data){
//   
// }
// 
// void delete_cpu_plan3d_real_input(cpu_plan3d_real_input* plan){
//   
//  cpu_safe( cufftDestroy(plan->fwPlanZ) );
//  cpu_safe( cufftDestroy(plan->invPlanZ) );
//  cpu_safe( cufftDestroy(plan->planY) );
//  cpu_safe( cufftDestroy(plan->planX) );
// 
//  cpu_safe( cudaFree(plan->transp) );
//  cpu_safe( cudaFree(plan->size) );
//  cpu_safe( cudaFree(plan->paddedSize) );
//  cpu_safe( cudaFree(plan->paddedStorageSize) );
//  free(plan);
// 
// }



#ifdef __cplusplus
}
#endif
