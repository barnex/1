/**
* This application runs the convolution unit tests and illustrates the usage of conv_gpu
*/
#include "conv_gpu.h"
#include "tensor.h"
#include "math.h"
#include <assert.h>

float sqr(float x){
  return x*x;
}

int main(int argc, char** argv){
  printf("conv_test:\n");
  
  int N0 = 128, N1 = 128, N2 = 2048; 
  int* size = new int[3];
  size[0] = N0; size[1] = N1, size[2] = N2;
  
  tensor* m = new_tensor(4, 3, N0, N1, N2);
  tensor* h = new_tensor(4, 3, N0, N1, N2);
  
  for(int i=0; i<tensor_length(m); i++){
    m->list[i] = (rand()%1000 + 1)/1000.0;
  }
  
  tensor* kernel = new_tensor(5, 3, 3, 2*N0, 2*N1, 2*N2);
  // unit kernel:
  for(int s=0; s<3; s++){
    *tensor_get(kernel, 5, s, s, 0, 0, 0) = 1.0;
  }
  
  convplan* plan = new_convplan(N0, N1, N2, kernel->list);

  //format_tensor(kernel, stdout);
  printf("M\n\n");
  format_tensor(m, stdout);
  
  conv_execute(plan, m->list, h->list);
  
  printf("H\n\n");
  format_tensor(h, stdout);
  
  delete_convplan(plan);

  double maxerror = 0.;
  for(int i=0; i<tensor_length(m); i++){
    if(abs(m->list[i] - h->list[i]) > maxerror){
      maxerror = abs(m->list[i] - h->list[i]);
    }
    assert(m->list[i] != 0.); // it's really easy to make such a mistake that both m and h contain only zero's. 
  }
  printf("unit convolution max error = %lf\n", maxerror);
  assert(maxerror < 1E-5);
  
  printf("PASS\n");
  return 0;
}