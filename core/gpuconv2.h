/**
 * @file
 * A smarter vector convolution plan on the GPU:
 * real-to-complex FFT's.
 * The redundant zero's in the padded magnetization buffers are ignored.
 * The zero's in the micromagnetic kernel are ignored.
 * Care is taken to align CUDA memory access.
 *
 * The interface is flexible: gpuconv2_exec(m, h) can be called on any 
 * magnetization and field array that match the size of the plan. 
 * m and h are thus not stored in the plan itself. 
 * This is handy for higher order solvers that keep multiple versions of m and h.
 *
 * @todo 
  TODO voor convolutie (Ben)
 *
 *1.  Greense functies 
 *	-> 	dienen gegenereerd te worden in strided formaat
 *	-> 	is symmetrische rank 4 tensor (vb: gxy = gyx, gxz = gzx, ..., slechts 2/3 van geheugen nodig)
 *	->	Enkel reeel deel in Fourier domein (halveert geheugen vereisten)
 * ->  implementatie algemene Greense tensor nodig met als input te gebruiken Greense functie 
 *	->  Er dient rekening gehouden te worden met mogelijke periodiciteit
 *
 *2.  seriele berekening veldwaarden gunstiger
 *	-> 	beter seriele berekening van H_x, H_y, H_z als
 *				a. H^FFT = g^FFT_xx* m^FFT_x + g^FFT_xy* m^FFT_y + g^FFT_xz* m^FFT_z
 *				b. H_x = inv_FFT(H^FFT)
 *				c. H^FFT = g^FFT_xy* m^FFT_x + g^FFT_yy* m^FFT_y + g^FFT_yz* m^FFT_z
 *				d. H_y = inv_FFT(H^FFT)
 *				e. H^FFT = g^FFT_xz* m^FFT_x + g^FFT_yz* m^FFT_y + g^FFT_zz* m^FFT_z
 *				f. H_z = inv_FFT(H^FFT)
 *			Op die manier enkel geheugen nodig voor H^FFT (en niet voor elke component H^FFT_x, H^FFT_y, H^FFT_z)
 *			Antw: Ik denk dat ik nu slechts even veel geheugen gebruik: Ik houd 3 H^FFT componenten in het geheugen,
 *			maar slechts één m^FFT component, jij één H^FFT maar 3 m^FFT's. Of heb ik het mis op? (Arne.)
 *			Opm: misschien kunnen we wel één buffer uitsparen door eerst alle m_i te FFT-en en dan een "in-place"
 *			kernel vermenigvuldiging te doen. Per element wordt dan m_x[i], m_y[i], m_z[i] gebufferd in
 *			locale variablen, daarna wordt m^FFT element per element overschreven door H^FFT...
 *			
 *	->  H^FFT dient dezelfde dimensies te hebben als andere strided FFT tensoren 
 *
 *3.  Transponeren matrices
 *	->  is versnelling mogelijk door nullen niet te transponeren?
 *	->  In place transponeren

 *4.  Omtrent de FFT routines
 *	-> Waarschijnlijk beter om FFT routines in een aparte bibliotheek te steken wegens mogelijk gebruik in andere convoluties
 *	-> implementatie 2D varianten:
 *				Uitbreiding van de huidige routines of aparte routines? mogelijkheden:
 *				a. Aparte routines voor 3D en 2D: bij aanroepen if constructies nodig (if 3D, if 2D)
 *				b. uitbreiding routines:
 *						- extra argument 2D of 3D, met daarna daarna twee totaal verschillende code blokken
 *						- geen extra argumenten, maar op basis van dimensies in argument.
 *
 *
 * @see gpuconv1, new_gpuconv2, gpuconv2_exec
 *
 * @todo when NO=1, gxy and gxz are zero
 *
 * @author Arne Vansteenkiste
 * @author Ben Van de Wiele
 */
#ifndef GPUCONV2_H
#define GPUCONV2_H

#include "tensor.h"
#include "gputil.h"
#include <cufft.h>
#include "gpufft2.h"

#ifdef __cplusplus
extern "C" {
#endif


///@internal
typedef struct{
   
  gpuFFT3dPlan* fftplan;
  
  tensor* m;               ///< no space is allocated for m, this is just a pointer the m being convolved at the moment. It's mainly used to store the size of m.
  tensor* mComp[3];        ///< points to mx, my, mz. again, no space is allocated as this just points into m. each time m->list is set, mComp needs to be updated as well...
  
  tensor* h;               ///< no space is allocated for h, this is just a pointer the h being convolved at the moment. It's mainly used to store the size of h.
  tensor* hComp[3];        ///< points to hx, hy, hz. again, no space is allocated as this just points into h. each time h->list is set, hComp needs to be updated as well...

  int* paddedSize;         ///< logical size of the zero-padded data. No tensor actually has this size: fftXComp has about paddedSize, but plus one stride in the Z dimension.
  
  tensor* fft1;            ///< buffer to store and transform the zero-padded magnetization and field
  tensor* fft1Comp[3];
  
  tensor* fft2;            ///< second fft buffer. By default, this one points to fft1, so everything is in-place. However, it can also be separatly allocated so that the FFT's 
  tensor* fft2Comp[3];

  tensor* fftKernel[3][3]; ///< not stored as a rank 5 kernel because the underlying storage is not neccessarily contiguous: we can exploit the kernel symmetry and make K[X][Y] point to K[Y][X], etc.
  
}gpuconv2;



/**
 * New convolution plan with given size of the source vector field and kernel.
 * If the kernel size is larger than the vector field, the field is zero-padded
 * in the respective dimension to fit the size of the kernel.
 * @note After construction, a kernel should still be loaded.
 */
gpuconv2* new_gpuconv2(int* size,                 ///< X Y and Z size of the magnetization vector field
                       int* kernelSize            ///< convolution kernel size of at least the size of the vector field
                       );

/**
 * Loads a kernel into the convolution.
 * The kernel is not yet FFTed and stored in the 5-dimensional format:
 * Kernel[SourceDir][DestDir][X][Y][Z].
 * The kernel is assumed to be symmetric in the first two indices.
 * @note for use with Arne's kernels.
 */
void gpuconv2_loadkernel5DSymm(gpuconv2* conv,
                               tensor* kernel5D     ///< Kernel on Host, not yet normalized
                               );

/**
 * Loads a kernel into the convolution.
 * The kernel is FFTed and stored in a 2-dimensional format:
 * Kernel[SourceDir][index].
 * The kernel has the format discribed in gpukernel1.h
 * @see gpukernel1.h
 * @note for use with Ben's kernels
 * @todo not yet implemented
 */                               
void gpuconv2_loadkernel2DSymm(gpuconv2* conv,
                               tensor* kernel2D     ///< Kernel on Device, normalized
                               );

/**
 * Executes the convolution plan: convolves the source data with the stored kernel and stores the result in the destination pointer.
 */
void gpuconv2_exec(gpuconv2* plan, 				///< the plan to execute 
		   tensor* source, 	           				///< the input vector field (magnetization)
		   tensor* dest		             				///< the destination vector field (magnetic field) to store the result in
		   );

/**
 * Loads a kernel. Automatically called during new_gpuconv2(), but could be used to change the kernel afterwards.
 * @see new_gpuconv2
 */
void gpuconv2_loadkernel(gpuconv2* plan,	///< plan to load the kernel into
			 tensor* kernel		                  ///< kernel to load (should match the plan size)
			 );

/**
 * Pointwise multiplication of arrays of complex numbers. ft_h_comp_j += ft_m_i * ft_kernel_comp_ij. Runs on the GPU.
 * Makes use of kernel symmetry
 * @note DO NOT store in texture memory! This would be a bit faster on older devices, but actually slower on Fermi cards!
 */
void gpu_kernel_mul2(float* ft_m_i,		    ///< multiplication input 1
		     float* ft_kernel_comp_ij,      	///< multiplication input 2
		     float* ft_h_comp_j, 	            ///< multiplication result gets added to this array
		     int nRealNumbers									///< the number of floats(!) in each of the arrays, thus twice the number of complex's in them.
		     );

             
///@internal
void gpu_kernel_mul_complex_inplace_symm(float* fftMx,  float* fftMy,  float* fftMz,
                                         float* fftKxx, float* fftKyy, float* fftKzz,
                                         float* fftKyz, float* fftKxz, float* fftKxy,
                                         int nRealNumbers);

             
/**
 * @internal
 * Copies 3D data to a zero-padded, strided destination. Runs on the GPU.
 */
void gpuconv2_copy_pad(gpuconv2* conv, 		///< this convolution plan contains the sizes of both arrays
		       float* source,   							///< source data on GPU, should have size: conv->size
		       float* dest										///< destination data on GPU, should have size: conv->paddedStorageSize
		       );

/**
 * @internal
 * Copies 3D data from a zero-padded and strided destination. Runs on the GPU
 */
void gpuconv2_copy_unpad(gpuconv2* conv,	///< this convolution plan contains the sizes of both arrays
			 float* source,  										///< destination data on GPU, should have size: conv->paddedStorageSize
			 float* dest	 											///< source data on GPU, should have size: conv->size
			 );


#ifdef __cplusplus
}
#endif
#endif