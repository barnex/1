#ifdef __cplusplus
extern "C" {
#endif

#include "param.h"
#include "../macros.h"


param* new_param(){
  param* p = (param*)malloc(sizeof(param));
  
  p->aexch = 0.;
  p->msat = 0.;
  p->mu0 = 4.0E-7 * PI;
  p->gamma0 = 2.211E5;
  p->alpha = 0.;

  p->anisType = NONE;
  p->anisK = NULL;
  p->anisN = 0;

  for(int i=0; i<3; i++){
    p->size[i] = 0;
    p->cellSize[i] = 0.;
    p->demagPeriodic[i] = 0;
    p->demagCoarse[i] = 1;
    p->hExt[i] = 0;
    p->diffHExt[i] = 0;
    p->exchInConv[i] = -1;
  }

  p->solverType = NONE;
  p->maxDt = 0.;
  p->maxDelta = 0.;
  p->maxError = 0.;

  p->normalizeEvery = 1;
  p->msatMap = NULL;
  
  p->exchType = NONE;
  
  
  return p;
}

void check_param(param *p){

  // there must be a valid unit system
  assert(p->msat > 0.);
  assert(p->aexch > 0.);
  assert(p->mu0 > 0.);
  assert(p->gamma0 > 0.);
  
  // no negative damping
  assert(p->alpha >= 0.);
  
  // thickness 1 only allowed in x-direction
  assert(p->size[X]>0);
  assert(p->size[Y]>1);
  assert(p->size[Z]>1);
  
  assert(p->exchType != NONE);
  
  // checks related with convolution ________________________________________________
  if (p->kernelType==KERNEL_MICROMAG3D)
    for (int i=0; i<3; i++){
      assert( p->cellSize[i]>0.0f);
      assert( p->demagCoarse[i]>0);
        // the coarse level mesh should fit the low level mesh:
      assert( p->size[i]>=p->demagCoarse[i] && p->size[i]%p->demagCoarse[i] == 0);
    }
  if (p->kernelType==KERNEL_MICROMAG2D){
    assert(p->size[X]==1);
    assert(p->kernelSize[X]==1);
    for (int i=1; i<3; i++){
      assert( p->cellSize[i]>0.0f);
      assert( p->demagCoarse[i]>0);
      assert( p->size[i]>=p->demagCoarse[i] && p->size[i]%p->demagCoarse[i] == 0);            // the coarse level mesh should fit the low level mesh:
    }
    if (p->cellSize[X]!=0.0f)   fprintf(stderr,"parameter cellSize[X] = %g is ignored in this 2D simulation\n", p->cellSize[X]);
    if (p->demagCoarse[X]!=1)   fprintf(stderr,"parameter demagCoarse[X] = %d is ignored in this 2D simulation\n", p->demagCoarse[X]);
    if (p->demagPeriodic[X]!=0) fprintf(stderr,"parameter demagPeriodic[X] = %d is ignored in this 2D simulation\n", p->demagPeriodic[X]);
    if (p->exchInConv[X]!=0)    fprintf(stderr,"parameter exchInConv[X] = %d is ignored in this 2D simulation\n", p->exchInConv[X]);
  }
  // ________________________________________________________________________________


  // only 1 (possibly coarse level) cell thickness in x-direction combined with periodicity in this direction is not allowed.
  assert(  !(p->size[X]/p->demagCoarse[X]==1 && p->demagPeriodic[X])  );

  assert(p->normalizeEvery > 0);
  if(p->msatMap != NULL){
    assert(p->msatMap->rank == 3);
    for(int i=0; i<3; i++){
      assert(p->msatMap->size[i] == p->size[i]);
    }
  }
  
    
  return;
}

double unitlength(param* p){
  return sqrt(2. * p->aexch / (p->mu0 * p->msat*p->msat) );
}

double unittime(param* p){
  return 1.0 / (p->gamma0 * p->msat);
}

double unitfield(param* p){
  return p->mu0 * p->msat;
}

double unitenergy(param* p){
  return p->aexch * unitlength(p);
}

void param_print(FILE* out, param* p){

  fprintf(out, "\n*** Simulation parameters ***\n");

  fprintf(out, "msat         :\t%g A/m\n",   p->msat);
  fprintf(out, "aexch        :\t%g J/m\n",   p->aexch);
  fprintf(out, "mu0          :\t%g N/A^2\n", p->mu0);
  fprintf(out, "gamma0       :\t%g m/As\n",  p->gamma0);
  fprintf(out, "alpha        :\t%g\n",       p->alpha);

  fprintf(out, "anisType     :\t%d\n",       p->anisType);
  fprintf(out, "anisK        :\t[");
  for(int i=0; i<p->anisN; i++){
    fprintf(out, "%g ", p->anisK[i]);
  }
  fprintf(out, "]\n");

  double L = unitlength(p);
  fprintf(out, "size         :\t[%d x %d x %d] cells\n", p->size[X], p->size[Y], p->size[Z]);
  fprintf(out, "cellsize     :\t[%g m x %g m x %g m]\n", p->cellSize[X]*L, p->cellSize[Y]*L, p->cellSize[Z]*L);

  fprintf(out, "kernelType   :\t%d\n",       p->kernelType);
  fprintf(out, "demagPeriodic:\t[%d, %d, %d] repeats\n", p->demagPeriodic[X], p->demagPeriodic[Y], p->demagPeriodic[Z]);
  fprintf(out, "demagCoarse  :\t[%d x %d x %d] cells\n", p->demagCoarse[X], p->demagCoarse[Y], p->demagCoarse[Z]);
  fprintf(out, "demagKernel  :\t[%d x %d x %d] cells\n", p->kernelSize[X], p->kernelSize[Y], p->kernelSize[Z]);

  fprintf(out, "exchType     :\t%d\n",       p->exchType);
  fprintf(out, "exchInConv   :\t[%d, %d, %d]\n", p->exchInConv[X], p->exchInConv[Y], p->exchInConv[Z]);

  double T = unittime(p);
  fprintf(out, "solverType   :\t%d\n",       p->solverType);
  fprintf(out, "maxDt        :\t%g s\n",     p->maxDt * T);
  fprintf(out, "maxDelta     :\t%g\n",       p->maxDelta);
  fprintf(out, "maxError     :\t%g\n",       p->maxError);

  double B = unitfield(p);
  fprintf(out, "hExt         :\t[%g, %g, %g] T\n", p->hExt[X]*B, p->hExt[Y]*B, p->hExt[Z]*B);
  fprintf(out, "diffHExt     :\t[%g, %g, %g] T/s\n", p->diffHExt[X]*(B/T), p->diffHExt[Y]*(B/T), p->diffHExt[Z]*(B/T));

  fprintf(out, "msatMap      :\t%p\n",       p->msatMap);
  
  fprintf(out, "unitlength   :\t%g m\n",     unitlength(p));
  fprintf(out, "unittime     :\t%g s\n",     unittime(p));
  fprintf(out, "unitenergy   :\t%g J\n",     unitenergy(p));
  fprintf(out, "unitfield    :\t%g T\n",     unitfield(p));

  return;
}



#ifdef __cplusplus
}
#endif