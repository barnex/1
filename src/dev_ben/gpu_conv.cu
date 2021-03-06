#include "gpu_conv.h"

#ifdef __cplusplus
extern "C" {
#endif

void evaluate_convolution(tensor *m, tensor *h, conv_data *conv, param *p){

  for (int i=0; i<3; i++)
    if (p->demagCoarse[i]>1){
      fprintf(stderr, "abort: convolution on a coarse grid not yet implemented.\n");
      abort();
    }

  switch (p->kernelType){
    case KERNEL_MICROMAG3D:
      if (p->size[X]/p->demagCoarse[X] > 1)
        evaluate_micromag3d_conv(m, h, conv);
      if (p->size[X]/p->demagCoarse[X] == 1)
        evaluate_micromag3d_conv_Xthickness_1(m, h, conv);
      break;
    case KERNEL_MICROMAG2D:
      evaluate_micromag2d_conv(m, h, conv);
      break;
    default:
      fprintf(stderr, "abort: no valid kernelType\n");
      abort();
  }

  return;
}



void evaluate_micromag3d_conv(tensor *m, tensor *h, conv_data *conv){

  int m_length = m->len/3;
  int N = conv->fft1->len/3;

  float *m_comp[3], *h_comp[3], *fft1_comp[3];
  for (int i=0; i<3; i++){
    fft1_comp[i] = &conv->fft1->list[i*N];
    m_comp[i]    = &m->list[i*m_length];
    h_comp[i]    = &h->list[i*m_length];
  }

  float *fftMx = &conv->fft1->list[0*N];
  float *fftMy = &conv->fft1->list[1*N];
  float *fftMz = &conv->fft1->list[2*N];
  float *fftKxx = &conv->kernel->list[0*N/2];
  float *fftKxy = &conv->kernel->list[1*N/2];
  float *fftKxz = &conv->kernel->list[2*N/2];
  float *fftKyy = &conv->kernel->list[3*N/2];
  float *fftKyz = &conv->kernel->list[4*N/2];
  float *fftKzz = &conv->kernel->list[5*N/2];

    //Fourier transforming of fft_mi
  for(int i=0; i<3; i++){
//    gpuFFT3dPlan_forward(conv->fftplan, m_comp[i], fft1_comp[i]);  ///@todo out-of-place
    gpuFFT3dPlan_forward(conv->fftplan, m_comp[i], fft1_comp[i]);  ///@todo out-of-place
  }
    // kernel multiplication
    gpu_kernelmul6(fftMx, fftMy, fftMz, fftKxx, fftKyy, fftKzz, fftKyz, fftKxz, fftKxy, N);

    //inverse Fourier transforming fft_hi
  for(int i=0; i<3; i++)
//    gpuFFT3dPlan_inverse(conv->fftplan, fft1_comp[i], h_comp[i]);  ///@todo out-of-place
    gpuFFT3dPlan_inverse(conv->fftplan, fft1_comp[i], h_comp[i]);  ///@todo out-of-place

  return;
}

void evaluate_micromag3d_conv_Xthickness_1(tensor *m, tensor *h, conv_data *conv){

  int m_length = m->len/3;
  int N = conv->fft1->len/3;

  float *m_comp[3], *h_comp[3], *fft1_comp[3];
  for (int i=0; i<3; i++){
    fft1_comp[i] = &conv->fft1->list[i*N];
    m_comp[i]    = &m->list[i*m_length];
    h_comp[i]    = &h->list[i*m_length];
  }
  
  float *fftMx = &conv->fft1->list[0*N];
  float *fftMy = &conv->fft1->list[1*N];
  float *fftMz = &conv->fft1->list[2*N];
  float *fftKxx = &conv->kernel->list[0*N/2];
  float *fftKyy = &conv->kernel->list[1*N/2];
  float *fftKyz = &conv->kernel->list[2*N/2];
  float *fftKzz = &conv->kernel->list[3*N/2];


  //Fourier transforming of fft_mi
  for(int i=0; i<3; i++){
//   gpuFFT3dPlan_forward(conv->fftplan, m_comp[i], fft1_comp[i]);  ///@todo out-of-place
    gpuFFT3dPlan_forward(conv->fftplan, m_comp[i], fft1_comp[i]);  ///@todo out-of-place
}
    // kernel multiplication
  gpu_kernelmul4(fftMx, fftMy,  fftMz, fftKxx, fftKyy, fftKzz, fftKyz, N);

    //inverse Fourier transforming fft_hi
  for(int i=0; i<3; i++){
//    gpuFFT3dPlan_inverse(conv->fftplan, fft1_comp[i], h_comp[i]);  ///@todo out-of-place
    gpuFFT3dPlan_inverse(conv->fftplan, fft1_comp[i], h_comp[i]);  ///@todo out-of-place
}

  return;
}

void evaluate_micromag2d_conv(tensor *m, tensor *h, conv_data *conv){

  int m_length = m->len/3;
  int N = conv->fft1->len/2;    // only 2 components need to be convolved!

  float *m_comp[2], *h_comp[2], *fft1_comp[2];
  for (int i=1; i<3; i++){
    fft1_comp[i-1] = &conv->fft1->list[(i-1)*N];
    m_comp[i-1]    = &m->list[i*m_length];
    h_comp[i-1]    = &h->list[i*m_length];
  }

  float *fftMy = &conv->fft1->list[0*N];
  float *fftMz = &conv->fft1->list[1*N];
  float *fftKyy = &conv->kernel->list[0*N/2];
  float *fftKyz = &conv->kernel->list[1*N/2];
  float *fftKzz = &conv->kernel->list[2*N/2];

    //Fourier transforming of fft_mi
  for(int i=0; i<2; i++)
//    gpuFFT3dPlan_forward(conv->fftplan, m_comp[i], fft1_comp[i]);  ///@todo out-of-place
    gpuFFT3dPlan_forward(conv->fftplan, m_comp[i], fft1_comp[i]);  ///@todo out-of-place

    // kernel multiplication
  gpu_kernelmul3(fftMy,  fftMz, fftKyy, fftKzz, fftKyz, N);

    //inverse Fourier transforming fft_hi
  for(int i=0; i<2; i++)
//    gpuFFT3dPlan_inverse(conv->fftplan, fft1_comp[i], h_comp[i]);  ///@todo out-of-place
    gpuFFT3dPlan_inverse(conv->fftplan, fft1_comp[i], h_comp[i]);  ///@todo out-of-place

  return;
}


// ****************************************************************************************************



// functions for copying to and from padded matrix ****************************************************
conv_data *new_conv_data(param *p, tensor *kernel){

  ///@todo add a test that checks if the kernel has been initialized.   
  conv_data *conv = (conv_data *) calloc(1, sizeof(conv));
  int size4d[4] = {0, p->kernelSize[X], p->kernelSize[Y], p->kernelSize[Z]+2};
  
  switch (p->kernelType){
    case KERNEL_MICROMAG3D:
      size4d[0] = 3;
      break;
    case KERNEL_MICROMAG2D:
      size4d[0] = 2;
      break;
    default:
      fprintf(stderr, "abort: no valid kernelType\n");
      abort();
  }

  conv->fft1 = new_gputensor(4, size4d);
  conv->fft2 = conv->fft1;
  conv->fftplan = new_gpuFFT3dPlan_padded(p->size, p->kernelSize);
  conv->kernel = kernel;

  return (conv);
}
// ****************************************************************************************************



#ifdef __cplusplus
}
#endif