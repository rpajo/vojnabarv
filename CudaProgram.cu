#include <stdio.h>
#include <curand.h>
//#include <curand_kernel.h>
#include <time.h>
#include <stdlib.h>
#include <math.h>
#include "qdbmp.h"
#include "qdbmp.c"


__global__
void process (int *tabela, int*output, int* random, int vrsta, int pixlov, int iteracije) {
	//__shared__ int tabela[3*vrsta*3];
	int sosedi[3][4];
	int i = 0;
	for(i = 0; i < iteracije; i++) {
		int stBarv=-1;
		int	x =  blockIdx.x*blockDim.x*3 + threadIdx.x*3;
		
		if((x-3) >= 0){
			/* Preberemo RGB vrednosti x-1, y pike */
			stBarv++;
			sosedi[stBarv][0]= tabela[x-3];
			sosedi[stBarv][1]= tabela[x-2];
			sosedi[stBarv][2]= tabela[x-1];
		}
					
		if((x-(vrsta*3)) >= 0){
			stBarv++;
			sosedi[stBarv][0]= tabela[x-(vrsta*3)];
			sosedi[stBarv][1]= tabela[x+1-(vrsta*3)];
			sosedi[stBarv][2]= tabela[x+2-(vrsta*3)];
		}
	
		if((x+3) < pixlov*3){
			stBarv++;
			sosedi[stBarv][0]= tabela[x+3];
			sosedi[stBarv][1]= tabela[x+4];
			sosedi[stBarv][2]= tabela[x+5];
		}
	
		if((x+(vrsta*3)) < pixlov*3){
			stBarv++;
			sosedi[stBarv][0]= tabela[x+(vrsta*3)];
			sosedi[stBarv][1]= tabela[x+1+(vrsta*3)];
			sosedi[stBarv][2]= tabela[x+2+(vrsta*3)];
		}
		
		if(x < pixlov*3) {
			int ran = random[x]%(stBarv+1);
			/*output[x + i*pixlov*3] = sosedi[ran][0];
			output[x+1 + i*pixlov*3] = sosedi[ran][1];
			output[x+2 + i*pixlov*3] = sosedi[ran][2];*/
			output[x] = sosedi[ran][0];
			output[x+1] = sosedi[ran][1];
			output[x+2] = sosedi[ran][2];
			__syncthreads();
			tabela = output;
			random = random+1;
			
			//printf("%d,%d %d %d %d\n", i, x, output[x + i*pixlov*3], output[x+1 + i*pixlov*3], output[x+2 + i*pixlov*3]);
		}
		
	}
}

int main(int argc, char* argv[]) {

	double diff = 0.0;
	time_t start;
    time_t stop;
    time(&start);


	BMP* bmp;
	BMP* nova;
	unsigned char r, g, b; 
	int width, height; 
	int x, y; 

	printf("Vnesi stevilo iteraciji na GPU:\n");
	int cudaIteracije;
	scanf("%d", &cudaIteracije);

	/* Preverimo, če je število vnešenih argumentov pravilno */
	if ( argc != 3 )
	{
		fprintf( stderr, "Uporaba: %s <vhodna slika> <izhodna slika>",
			argv[ 0 ] );
		return 0;
	}

	bmp = BMP_ReadFile( argv[ 1 ] );
	//BMP_CHECK_ERROR( stderr, -1 );
	
	width = BMP_GetWidth( bmp );
	height = BMP_GetHeight( bmp );

	srand ( time(NULL) );

	// alociranje pomnilnika
	int *tabela1D;
	int *rezultat;
	int *random;
	int *cudaRandom;
	int *cudaInput;
	int *cudaOutput;

	tabela1D = (int*)malloc(width*height*3*sizeof(int));

	rezultat = (int*)malloc(width*height*3*sizeof(int));

	random = (int*)malloc(width*height*3*sizeof(int));
	cudaMalloc(&cudaRandom, width*height*sizeof(int));

	cudaMalloc(&cudaOutput, width*height*3*sizeof(int));

	cudaMalloc(&cudaInput, width*height*3*sizeof(int));

	//preberi RGB vrednosti vsakega pixla na sliki v 1D tabelo
	int j=0;
	for(y = 0; y < height; y++) {
		for(x = 0; x < width; x++) {
			BMP_GetPixelRGB( bmp, x, y, &r, &g, &b );
			/*printf("%d) %u %u %u\n", j, r, g, b);
			j+=3;*/
			tabela1D[y*width*3+x*3] = (int)r;
			tabela1D[y*width*3+x*3+1] = (int)g;
			tabela1D[y*width*3+x*3+2] = (int)b;
		}
	}

	for(j = 0; j < height*width+cudaIteracije+1; j++) {
		random[j] = rand();
	}

	cudaMemcpy(cudaInput, tabela1D, width*height*3*sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(cudaRandom, random, width*height*sizeof(int), cudaMemcpyHostToDevice);



	process<<<height, width>>>(cudaInput, cudaOutput, cudaRandom, width, width*height, cudaIteracije);

	cudaMemcpy(rezultat, cudaOutput, width*height*3*sizeof(int), cudaMemcpyDeviceToHost);


	nova = BMP_Create(width, height, 24);

	
	for(y = 0; y < height; y++) {
		for(x = 0; x < width; x++) {
			/*printf("%d) %d %d %d\n", j, rezultat[y*width*3+x*3], 
									rezultat[y*width*3+x*3+1],
									rezultat[y*width*3+x*3+2]);
			j+=3;*/
			BMP_SetPixelRGB(nova, x, y, (unsigned char)rezultat[y*width*3+x*3], 
										(unsigned char)rezultat[y*width*3+x*3+1], 
										(unsigned char)rezultat[y*width*3+x*3+2]);
		}
	}
	j = 0;
	for(x = 0; x < height*width*3; x++) {
		printf("%d ", rezultat[x]);
		j++;
		if(j == 3) {
			j = 0;
			printf("\n");
		}
	}

	BMP_WriteFile(nova, argv[2]);
	BMP_CHECK_ERROR(stdout, -2);

	free(tabela1D);
	free(random);
	cudaFree(cudaRandom);
	cudaFree(cudaInput);
	cudaFree(cudaOutput);

	time(&stop);
  	diff = difftime(stop, start);
  	printf("Runtime: %g\n", diff);

	return 0;
}