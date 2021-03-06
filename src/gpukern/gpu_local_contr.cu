/*
 *  This file is part of MuMax, a high-performance micromagnetic simulator.
 *  Copyright 2010  Arne Vansteenkiste, Ben Van de Wiele.
 *  Use of this source code is governed by the GNU General Public License version 3
 *  (as published by the Free Software Foundation) that can be found in the license.txt file.
 *
 *  Note that you are welcome to modify this code under condition that you do not remove any 
 *  copyright notices and prominently state that you modified it, giving a relevant date.
 */

#include "gpu_local_contr.h"
#include "gpu_mem.h"
#include "gpu_conf.h"
#include "../macros.h"

#ifdef __cplusplus
extern "C" {
#endif


__global__ void _gpu_add_local_contr(float* mx, float* my, float* mz,
                                     float* hx, float* hy, float* hz,
                                     float Hax, float Hay, float Haz,
                                     int anisType, dev_par *p_dev, int N){
  
  int i = threadindex;

  if(i < N){
    
    if (anisType == NONE){
      hx[i] += Hax;
      hy[i] += Hay;
      hz[i] += Haz;
    }


    if (anisType == ANIS_UNIAXIAL){
      float projection = 2.0f*p_dev->anisK[0] * (mx[i]*p_dev->anisAxes[X] + my[i]*p_dev->anisAxes[Y] + mz[i]*p_dev->anisAxes[Z]);
      hx[i] += Hax + projection*p_dev->anisAxes[X];
      hy[i] += Hay + projection*p_dev->anisAxes[Y];
      hz[i] += Haz + projection*p_dev->anisAxes[Z];

    }
    

    if (anisType == ANIS_CUBIC){
        //projection of m on cubic anisotropy axes
      float a0 = mx[i]*p_dev->anisAxes[0] + my[i]*p_dev->anisAxes[1] + mz[i]*p_dev->anisAxes[2];
      float a1 = mx[i]*p_dev->anisAxes[3] + my[i]*p_dev->anisAxes[4] + mz[i]*p_dev->anisAxes[5];
      float a2 = mz[i]*p_dev->anisAxes[6] + my[i]*p_dev->anisAxes[7] + mz[i]*p_dev->anisAxes[8];
      
      float a00 = a0*a0;
      float a11 = a1*a1;
      float a22 = a2*a2;
      
        // differentiated energy expressions
      float dphi_0 = p_dev->anisK[0] * (a11+a22) * a0  +  p_dev->anisK[1] * a0  *a11 * a22;
      float dphi_1 = p_dev->anisK[0] * (a00+a22) * a1  +  p_dev->anisK[1] * a00 *a1  * a22;
      float dphi_2 = p_dev->anisK[0] * (a00+a11) * a2  +  p_dev->anisK[1] * a00 *a11 * a2 ;
      
        // adding applied field and cubic axes contribution
      hx[i] += Hax - dphi_0*p_dev->anisAxes[0] - dphi_1*p_dev->anisAxes[3] - dphi_2*p_dev->anisAxes[6];
      hy[i] += Hay - dphi_0*p_dev->anisAxes[1] - dphi_1*p_dev->anisAxes[4] - dphi_2*p_dev->anisAxes[7];
      hz[i] += Haz - dphi_0*p_dev->anisAxes[2] - dphi_1*p_dev->anisAxes[5] - dphi_2*p_dev->anisAxes[8];
    }

  }
  
  return;
}

void gpu_add_local_contr (float *m, float *hint Ntot, float *Hext, int anisType, dev_par *p_dev){

  float *hx = h + X*Ntot;
  float *hy = h + Y*Ntot;
  float *hz = h + Z*Ntot;

  float *mx = m + X*Ntot;
  float *my = m + Y*Ntot;
  float *mz = m + Z*Ntot;

  dim3 gridsize, blocksize;
  make1dconf(Ntot, &gridsize, &blocksize);
  _gpu_add_local_contr<<<gridsize, blocksize>>>(mx, my, mz, hx, hy, hz, Hext[X], Hext[Y], Hext[Z], anisType,  p_dev, Ntot);

}
                            

dev_par* init_par_on_dev(int anisType, float *anisK, float *defAxes)  {
  
  dev_par *p_dev = (dev_par*) malloc(sizeof(dev_par));
  p_dev->anisK = NULL;
  p_dev->anisAxes = NULL;

    //for uniaxial anisotropy
  if (anisType == ANIS_UNIAXIAL){
    p_dev->anisK = new_gpu_array(1);
    printf("strength: %e\n", anisK[0]);
    p_dev->anisK[0] = anisK[0];
    printf("strength assigned\n");
    
    p_dev->anisAxes = new_gpu_array(3);  
    float length = sqrt(defAxes[X]*defAxes[X] + defAxes[Y]*defAxes[Y] + defAxes[Z]*defAxes[Z]);
    p_dev->anisAxes[X] = defAxes[X]/length;
    p_dev->anisAxes[Y] = defAxes[Y]/length;
    p_dev->anisAxes[Z] = defAxes[Z]/length;
  }

    //for cubic anisotropy
  if (anisType == ANIS_CUBIC){
    p_dev->anisK = new_gpu_array(2);
    p_dev->anisK[0] = anisK[0];
    p_dev->anisK[1] = anisK[1];
    
    p_dev->anisAxes = new_gpu_array(9);
    float phi   = defAxes[X];
    float theta = defAxes[Y];
    float psi   = defAxes[Z];
    p_dev->anisAxes[0] = cos(psi)*cos(phi)-cos(theta)*sin(phi)*sin(psi);
    p_dev->anisAxes[1] = cos(psi)*sin(phi)+cos(theta)*cos(phi)*sin(psi);
    p_dev->anisAxes[2] = sin(psi)*sin(theta);
    p_dev->anisAxes[3] = -sin(psi)*cos(phi)-cos(theta)*sin(phi)*cos(psi);
    p_dev->anisAxes[4] = -sin(psi)*sin(phi)+cos(theta)*cos(phi)*cos(psi);
    p_dev->anisAxes[5] = cos(psi)*sin(theta);
    p_dev->anisAxes[6] = sin(theta)*sin(phi);
    p_dev->anisAxes[7] = -sin(theta)*cos(phi);
    p_dev->anisAxes[8] = cos(theta);
  }

  return(p_dev);
}               

void destroy_par_on_dev(dev_par *p_dev, int anisType){

  if (anisType != NONE){
    free_gpu_array(p_dev->anisK);
    free_gpu_array(p_dev->anisAxes);
  }
  
  free (p_dev);
  
  return;
}


#ifdef __cplusplus
}
#endif
