#include "conv_gpu.h"
#include "tensor.h"
#include <stdio.h>
#include <assert.h>

/** Should be wrapped around all cudaXXX() functions, it will abort the program when a CUDA error is returned. */
void safe(int status){
  if(status != 0){
    fprintf(stderr, "received CUDA error: %d\n", status);
    abort();
  }
}

void conv_execute(convplan* p, float* m_list, float* h_list){
  tensor* m = as_tensor(m_list, 4, 3, p->size[0], p->size[1], p->size[2]);
  tensor* h = as_tensor(h_list, 4, 3, p->size[0], p->size[1], p->size[2]);
  
  // shorthand notations
  tensor* ft_h      = p->ft_h;
  tensor* ft_m_i    = p->ft_m_i;
  int*    size      = p->size;			// note: m->size == {3, N0, N1, N2}, size = {N0, N1, N2};
  
  // Zero-out field (h) components
  for(int i = 0; i < tensor_length(ft_h); i++){  ft_h->list[i] = 0.;  }
  
  // transform and convolve per magnetization component m_i
  for(int i = 0; i < 3; i++){
    
    // zero-out the padded magnetization buffer first
    for(int j = 0; j < tensor_length(ft_m_i); j++){  ft_m_i->list[j] = 0.;  }
    
     //copy the current magnetization component into the padded magnetization buffer
     // we convert real to complex format
     for(int i_= 0; i_< size[0]; i_++){
      for(int j_= 0; j_< size[1]; j_++){
	for(int k_= 0; k_< size[2]; k_++){
	  *tensor_get(ft_m_i, 3, i_, j_, 2 * k_) = *tensor_get(m, 4, i, i_, j_, k_);
	}
      }
     }
     //format_tensor(ft_m_i, stdout);
     gpu_exec_c2c(p->c2c_plan, ft_m_i, CUFFT_FORWARD);
     //format_tensor(ft_m_i, stdout);

     // apply kernel multiplication to FFT'ed magnetization and add to FFT'ed H-components
     for(int j=0; j<3; j++){
	float* ft_h_j = p->ft_h_comp[j]->list; //tensor_component(ft_h, j)->list;
	for(int e=0; e<tensor_length(ft_m_i); e+=2){
	  float rea = ft_m_i->list[e];
	  float reb = p->ft_kernel_comp[i][j]->list[e]; //tensor_component(tensor_component(ft_kernel, i), j)->list[e];
	  float ima = ft_m_i->list[e + 1];
	  float imb = p->ft_kernel_comp[i][j]->list[e + 1]; //tensor_component(tensor_component(ft_kernel, i), j)->list[e + 1];
	  ft_h_j[e] 	+=  rea*reb - ima*imb;
	  ft_h_j[e + 1] +=  rea*imb + ima*reb;
	}
     }
  }
  
  for(int i=0; i<3; i++){
    // Inplace backtransform of each of the padded H-buffers
    //tensor* ft_h_i = tensor_component(ft_h, i);
    gpu_exec_c2c(p->c2c_plan, p->ft_h_comp[i], CUFFT_INVERSE);
    // Copy region of interest (non-padding space) to destination
    for(int i_= 0; i_< size[0]; i_++){
      for(int j_= 0; j_< size[1]; j_++){
	for(int k_= 0; k_< size[2]; k_++){
	  *tensor_get(h, 4, i, i_, j_, k_) = *tensor_get(p->ft_h_comp[i], 3, i_, j_, 2*k_);
	}
      }
     }
     
     //debug
//      printf("H%d:\n", i);
//      format_tensor(tensor_component(h, i), stdout);
     
  }

}


convplan* new_convplan(int N0, int N1, int N2, float* kernel_list){
  convplan* plan = (convplan*) malloc(sizeof(convplan));
  
  plan->size[0] = N0;
  plan->size[1] = N1;
  plan->size[2] = N2;
  
  plan->paddedSize[0] = 2 * plan->size[0];
  plan->paddedSize[1] = 2 * plan->size[1];
  plan->paddedSize[2] = 2 * plan->size[2];
  
  plan->paddedComplexSize[0] =     plan->paddedSize[0];
  plan->paddedComplexSize[1] =     plan->paddedSize[1];
  plan->paddedComplexSize[2] = 2 * plan->paddedSize[2];
  
  tensor* kernel = as_tensor(kernel_list, 5, 3, 3, plan->paddedSize[0], plan->paddedSize[1], plan->paddedSize[2]);
  
  // DEBUG
//   for(int s = 0; s<3; s++){
//     for(int d = 0; d < 3; d++){
//       printf("K%d%d:\n", s, d);
//       format_tensor(tensor_component(tensor_component(kernel, s), d), stdout);
//     }
//   }
  
  plan->ft_m_i = new_tensorN(3, plan->paddedComplexSize);
  
  plan->ft_h = new_tensor(4, 3, plan->paddedComplexSize[0], plan->paddedComplexSize[1], plan->paddedComplexSize[2]);
  plan->ft_h_comp = (tensor**)calloc(3, sizeof(tensor*));
  for(int i=0; i<3; i++){
    plan->ft_h_comp[i] = tensor_component(plan->ft_h, i);
  }
  
  plan->ft_kernel = new_tensor(5, 3, 3, plan->paddedComplexSize[0], plan->paddedComplexSize[1], plan->paddedComplexSize[2]);
  plan->ft_kernel_comp = (tensor***)calloc(3, sizeof(tensor**));
  for(int i=0; i<3; i++){
    plan->ft_kernel_comp[i] = (tensor**)calloc(3, sizeof(tensor*));
    tensor* ft_kernel_comp_i = tensor_component(plan->ft_kernel, i);
    for(int j=0; j<3; j++){
      plan->ft_kernel_comp[i][j] = tensor_component(ft_kernel_comp_i, j);
    }
  }
  
  plan->c2c_plan = gpu_init_c2c(plan->paddedSize);
  
  _init_kernel(plan, kernel);
      
  return plan;
}


void _init_kernel(convplan* plan, tensor* kernel){
  tensor* ft_kernel = plan->ft_kernel;
  int* size = plan->size;
  int* paddedSize = plan->paddedSize;
  float norm = paddedSize[0] * paddedSize[1] * paddedSize[2];
  
  for(int s=0; s<3; s++){
    for(int d=0; d<3; d++){
      
      for(int i_= 0; i_< size[0]; i_++){
	for(int j_= 0; j_< size[1]; j_++){
	  for(int k_= 0; k_< size[2]; k_++){
	    *tensor_get(ft_kernel, 5, s, d, i_, j_, 2 * k_) = *tensor_get(kernel, 5, s, d, i_, j_, k_) / norm;
	  }
	}
      }
      
      tensor* k_sd = tensor_component(tensor_component(ft_kernel, s), d);
      
//       // DEBUG
//       printf("K_complex%d%d:\n", s, d);
//       format_tensor(tensor_component(tensor_component(ft_kernel, s), d), stdout);
      
      gpu_exec_c2c(plan->c2c_plan, k_sd, CUFFT_FORWARD);
      // todo: free tensor components.
      
//       //DEBUG
//        printf("FT_K%d%d:\n", s, d);
//       format_tensor(k_sd, stdout);
    }
  }
  
    // DEBUG
//   for(int s = 0; s<3; s++){
//     for(int d = 0; d < 3; d++){
//       printf("FT_K%d%d:\n", s, d);
//       format_tensor(tensor_component(tensor_component(ft_kernel, s), d), stdout);
//     }
//   }
  
}


void delete_convplan(convplan* plan){
  
  free(plan);
}

/////////////////////////////////////////////////////////////////////////////////////////////////////// FFT


cuda_c2c_plan* gpu_init_c2c(int* size){
  cuda_c2c_plan* plan = (cuda_c2c_plan*) malloc(sizeof(cuda_c2c_plan));
  safe( cufftPlan3d(&(plan->handle), size[0], size[1], size[2], CUFFT_C2C) );
  
  //float* device_list;
  safe( cudaMalloc((void**)&(plan->device_buffer), (size[0]*size[1]*size[2]) * 2*sizeof(float)) );
  //plan->device_data = as_tensor(device_list, 3, size[0], size[1], size[2]);
  return plan;
}


void gpu_exec_c2c(cuda_c2c_plan* plan, tensor* data, int direction){
//   // DEBUG
//   printf("\nFFT input:\n");
//   format_tensor(data, stdout);
  
  int N = tensor_length(data);
  safe( cudaMemcpy(plan->device_buffer, data->list, N*sizeof(float), cudaMemcpyHostToDevice) );
  safe( cufftExecC2C(plan->handle, (cufftComplex*)plan->device_buffer, (cufftComplex*)plan->device_buffer, direction) );
  safe( cudaMemcpy(data->list, plan->device_buffer, N*sizeof(float), cudaMemcpyDeviceToHost) );
  
//   // DEBUG
//   printf("\nFFT output:\n");
//   format_tensor(data, stdout);
  
}