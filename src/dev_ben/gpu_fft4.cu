#include "gpu_fft4.h"

#ifdef __cplusplus
extern "C" {
#endif



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
  plan->paddedStorageSize[Z] = plan->paddedSize[Z] + 2;
  plan->paddedStorageN = paddedStorageSize[X] * paddedStorageSize[Y] * paddedStorageSize[Z];
  
  gpu_safefft( cufftPlan1d(&(plan->fwPlanZ), plan->paddedSize[Z], CUFFT_R2C, size[X]*size[Y]) );
  gpu_safefft( cufftPlan1d(&(plan->planY), plan->paddedSize[Y], CUFFT_C2C, paddedStorageSize[Z] * size[X] / 2) );          // IMPORTANT: the /2 is necessary because the complex transforms have only half the amount of elements (the elements are now complex numbers)
  gpu_safefft( cufftPlan1d(&(plan->planX), plan->paddedSize[X], CUFFT_C2C, paddedStorageSize[Z] * paddedSize[Y] / 2) );
  gpu_safefft( cufftPlan1d(&(plan->invPlanZ), plan->paddedSize[Z], CUFFT_C2R, size[X]*size[Y]) );
  
  plan->transp = new_gpu_array(plan->paddedStorageN);
  
  return plan;
}

gpuFFT3dPlan* new_gpuFFT3dPlan(int* size){
  return new_gpuFFT3dPlan_padded(size, size); // when size == paddedsize, there is no padding
}


void gpuFFT3dPlan_forward(gpuFFT3dPlan* plan, float* input, float* output){
//   timer_start("gpu_plan3d_real_input_forward_exec");
  
  int* size = plan->size;
  int* pSSize = plan->paddedStorageSize;
  int N0 = pSSize[X];
  int N1 = pSSize[Y];
  int N2 = pSSize[Z]/2; // we treat the complex data as an N0 x N1 x N2 x 2 array
  int N3 = 2;
  
  int half_pSSize = plan->paddedStorageN/2;
  
  //     zero out the output matrix
    gpu_zero(output, plan->paddedStorageN);
  //     padding of the input matrix towards the output matrix
    gpu_copy_to_pad(input, output, size, pSSize);

  
//  float* data = input;
  float* data = output;
  float* data2 = plan->transp; 

  if ( pSSize[X]!=size[X] || pSSize[Y]!=size[Y]){
      // out of place FFTs in Z-direction from the 0-element towards second half of the zeropadded matrix (out of place: no +2 on input!)
    gpu_safefft( cufftExecR2C(plan->fwPlanZ, (cufftReal*)data,  (cufftComplex*) (data + half_pSSize) ) );     // it's in data
    gpu_sync();
      // zero out the input data points at the start of the matrix
    gpu_zero(data, size[X]*size[Y]*pSSize[Z]);
    
      // YZ-transpose within the same matrix from the second half of the matrix towards the 0-element
    yz_transpose_in_place_fw(data, size, pSSize);                                                          // it's in data
    
      // in place FFTs in Y-direction
    gpu_safefft( cufftExecC2C(plan->planY, (cufftComplex*)data,  (cufftComplex*)data, CUFFT_FORWARD) );       // it's in data 
    gpu_sync();
  }
  
  else {          //no zero padding in X- and Y direction (e.g. for Greens kernel computations)
      // in place FFTs in Z-direction (there is no zero space to perform them out of place)
    gpu_safefft( cufftExecR2C(plan->fwPlanZ, (cufftReal*)data,  (cufftComplex*) data ) );                     // it's in data
    gpu_sync();
    
      // YZ-transpose needs to be out of place.
    gpu_transposeYZ_complex(data, data2, N0, N1, N2*N3);                                                   // it's in data2
    
      // perform the FFTs in the Y-direction
    gpu_safefft( cufftExecC2C(plan->planY, (cufftComplex*)data2,  (cufftComplex*)data, CUFFT_FORWARD) );      // it's in data
    gpu_sync();
  }

  if(N0 > 1){    // not done for 2D transforms
      // XZ transpose still needs to be out of place
    gpu_transposeXZ_complex(data, data2, N0, N2, N1*N3);                                                   // it's in data2
    
      // in place FFTs in X-direction
    gpu_safefft( cufftExecC2C(plan->planX, (cufftComplex*)data2,  (cufftComplex*)output, CUFFT_FORWARD) );    // it's in data
    gpu_sync();
  }

//   timer_stop("gpu_plan3d_real_input_forward_exec");
  
  return;
}

void gpuFFT3dPlan_inverse(gpuFFT3dPlan* plan, float* input, float* output){
  
//   timer_start("gpu_plan3d_real_input_inverse_exec");
  
  int* size = plan->size;
  int* pSSize = plan->paddedStorageSize;
  int N0 = pSSize[X];
  int N1 = pSSize[Y];
  int N2 = pSSize[Z]/2; // we treat the complex data as an N0 x N1 x N2 x 2 array
  int N3 = 2;
  
  float* data = input;
  float* data2 = plan->transp; // both the transpose and FFT are out-of-place between data and data2

  if (N0 > 1){
      // out of place FFTs in the X-direction (i.e. no +2 stride on input!)
    gpu_safefft( cufftExecC2C(plan->planX, (cufftComplex*)data,  (cufftComplex*)data2, CUFFT_INVERSE) );      // it's in data2
    gpu_sync();

      // XZ transpose still needs to be out of place
    gpu_transposeXZ_complex(data2, data, N1, N2, N0*N3);                                                   // it's in data
  }
  
  if ( pSSize[X]!=size[X] || pSSize[Y]!=size[Y]){
      // in place FFTs in Y-direction
    gpu_safefft( cufftExecC2C(plan->planY, (cufftComplex*)data,  (cufftComplex*)data, CUFFT_INVERSE) );        // it's in data
    gpu_sync();

      // YZ-transpose within the same matrix from the 0-element towards the second half of the matrix
    yz_transpose_in_place_inv(data, size, pSSize);                                                          // it's in data

      // out of place FFTs in Z-direction from the second half of the matrix towards the 0-element
    gpu_safefft( cufftExecC2R(plan->invPlanZ, (cufftComplex*)(data + N0*N1*N2), (cufftReal*)data ));           // it's in data
    gpu_sync();

  }
  else {          //no zero padding in X- and Y direction (e.g. for Greens kernel computations)
      // out of place FFTs in Y-direction
    gpu_safefft( cufftExecC2C(plan->planY, (cufftComplex*)data,  (cufftComplex*)data2, CUFFT_INVERSE) );       // it's in data
    gpu_sync();
    
      // YZ-transpose needs to be out of place.
    gpu_transposeYZ_complex(data2, data, N0, N2, N1*N3);                                                    // it's in data2   

      // in place FFTs in Z-direction
    gpu_safefft( cufftExecC2R(plan->invPlanZ, (cufftComplex*) data, (cufftReal*) data ));                      // it's in data
    gpu_sync();
  }
  
  gpu_copy_to_unpad(data, output, pSSize, size);
 
//   timer_stop("gpu_plan3d_real_input_inverse_exec");
  
  return;
}


int gpuFFT3dPlan_normalization(gpuFFT3dPlan* plan){
  return plan->paddedSize[X] * plan->paddedSize[Y] * plan->paddedSize[Z];
}


void yz_transpose_in_place_fw(float *data, int *size, int *pSSize){

  int offset = pSSize[X]*pSSize[Y]*pSSize[Z]/2;    //start of second half
  int pSSize_YZ = pSSize[Y]*pSSize[Z];

  if (size[X]!=pSSize[X]){
    for (int i=0; i<size[X]; i++){       // transpose each plane out of place: can be parallellized
      int ind1 = offset + i*size[Y]*pSSize[Z];
      int ind2 = i*pSSize_YZ;
      gpu_transpose_complex_offset(data + ind1, data + ind2, size[Y], pSSize[Z], 0, pSSize[Y]-size[Y]);
    }
    gpu_sync();
    gpu_zero(data + offset, offset);     // possible to delete values in gpu_transpose_complex
  }
  else{     //padding in the y-direction
    for (int i=0; i<size[X]-1; i++){       // transpose all but the last plane out of place: can only partly be parallellized
      int ind1 = offset + i*size[Y]*pSSize[Z];
      int ind2 = i*pSSize_YZ;
      gpu_transpose_complex_offset(data + ind1, data + ind2, size[Y], pSSize[Z], 0, pSSize[Y]-size[Y]);
      gpu_zero(data + offset + i*size[Y]*pSSize[Z], size[Y]*pSSize[Z]);     // deletable
    }
    gpu_transpose_complex_in_plane_fw(data + (size[X]-1)*pSSize_YZ, size[Y], pSSize[Z]);
  }
  

  return;
}

void yz_transpose_in_place_inv(float *data, int *size, int *pSSize){

  int offset = pSSize[X]*pSSize[Y]*pSSize[Z]/2;    //start of second half
  int pSSize_YZ = pSSize[Y]*pSSize[Z];

  if (size[X]!=pSSize[X])
      // transpose each plane out of place: can be parallellized
    for (int i=0; i<size[X]; i++){
      int ind1 = i*pSSize_YZ;
      int ind2 = offset + i*size[Y]*pSSize[Z];
      gpu_transpose_complex_offset(data + ind1, data + ind2, pSSize[Z]/2, 2*size[Y], pSSize[Y]-size[Y], 0);
    }
  else{
      // last plane needs to transposed in plane
    gpu_transpose_complex_in_plane_inv(data + (size[X]-1)*pSSize_YZ, pSSize[Z]/2, 2*size[Y]);
      // transpose all but the last plane out of place: can only partly be parallellized
    for (int i=0; i<size[X]-1; i++){
      int ind1 = i*pSSize_YZ;
      int ind2 = offset + i*size[Y]*pSSize[Z];
      gpu_transpose_complex_offset(data + ind1, data + ind2, pSSize[Z]/2, 2*size[Y], pSSize[Y]-size[Y], 0);

    }
  }
  
  return;
}



// functions for copying to and from padded matrix ****************************************************
/// @internal Does padding and unpadding, not necessarily by a factor 2
__global__ void _gpu_copy_pad(float* source, float* dest, 
                                  int S1, int S2,                  ///< source sizes Y and Z
                                  int D1, int D2                   ///< destination size Y and Z
                                  ){
 int i = blockIdx.x;
 int j = blockIdx.y;
 int k = threadIdx.x;

 dest[(i*D1 + j)*D2 + k] = source[(i*S1 + j)*S2 + k];
 
 return;
}


void gpu_copy_to_pad(float* source, float* dest, int *unpad_size, int *pad_size){          //for padding of the tensor, 2d and 3d applicable
  
  int S0 = unpad_size[0];
  int S1 = unpad_size[1];
  int S2 = unpad_size[2];

  dim3 gridSize(S0, S1, 1); ///@todo generalize!
  dim3 blockSize(S2, 1, 1);
  check3dconf(gridSize, blockSize);
  
  if ( pad_size[0]!=unpad_size[0] || pad_size[1]!=unpad_size[1])
    _gpu_copy_pad<<<gridSize, blockSize>>>(source, dest, S1, S2, S1, pad_size[2]-2);      // for out of place forward FFTs in z-direction, contiguous data arrays
  else
    _gpu_copy_pad<<<gridSize, blockSize>>>(source, dest, S1, S2, S1, pad_size[2]);        // for in place forward FFTs in z-direction, contiguous data arrays

  gpu_sync();
  
  return;
}

void gpu_copy_to_unpad(float* source, float* dest, int *pad_size, int *unpad_size){        //for unpadding of the tensor, 2d and 3d applicable
  
  int D0 = unpad_size[X];
  int D1 = unpad_size[Y];
  int D2 = unpad_size[Z];

  dim3 gridSize(D0, D1, 1); ///@todo generalize!
  dim3 blockSize(D2, 1, 1);
  check3dconf(gridSize, blockSize);

  if ( pad_size[X]!=unpad_size[X] || pad_size[Y]!=unpad_size[Y])
    _gpu_copy_pad<<<gridSize, blockSize>>>(source, dest, D1,  pad_size[Z]-2, D1, D2);       // for out of place inverse FFTs in z-direction, contiguous data arrays
  else
    _gpu_copy_pad<<<gridSize, blockSize>>>(source, dest, D1,  pad_size[Z], D1, D2);         // for in place inverse FFTs in z-direction, contiguous data arrays

    gpu_sync();
  
  return;
}
// ****************************************************************************************************



#ifdef __cplusplus
}
#endif