/***********************************************************************************
  Implementing Breadth first search on CUDA using algorithm given in HiPC'07
  paper "Accelerating Large Graph Algorithms on the GPU using CUDA"

  Copyright (c) 2008 International Institute of Information Technology - Hyderabad. 
  All rights reserved.

  Permission to use, copy, modify and distribute this software and its documentation for 
  educational purpose is hereby granted without fee, provided that the above copyright 
  notice and this permission notice appear in all copies of this software and that you do 
  not sell the software.

  THE SOFTWARE IS PROVIDED "AS IS" AND WITHOUT WARRANTY OF ANY KIND,EXPRESS, IMPLIED OR 
  OTHERWISE.

  Created by Pawan Harish.

  Changes for sharedalloc implementation by Mohammad Dashti
 ************************************************************************************/
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <cuda.h>

#include <unistd.h>
#include <sys/syscall.h>
#define gpu_hook(x) syscall(380,x)

static void HandleError( cudaError_t err, const char *file, int line ) {
    
    if (err != cudaSuccess) {
        
        printf( "%s in %s at line %d\n", cudaGetErrorString( err ), file, line );
        exit( EXIT_FAILURE );
    
    }

}

#define HANDLE_ERROR( err ) (HandleError( err, __FILE__, __LINE__ ))

#define HANDLE_NULL( a ) {if (a == NULL) { \
                            printf( "Host memory failed in %s at line %d\n", \
                                    __FILE__, __LINE__ ); \
                            exit( EXIT_FAILURE );}}


#define MAX_THREADS_PER_BLOCK 512

int no_of_nodes;
int edge_list_size;
FILE *fp;

//Structure to hold a node information
struct Node
{
	int starting;
	int no_of_edges;
};

#include "kernel.cu"
#include "kernel2.cu"

void BFSGraph(int argc, char** argv);

////////////////////////////////////////////////////////////////////////////////
// Main Program
////////////////////////////////////////////////////////////////////////////////
int main( int argc, char** argv) 
{
   cudaFree(0); //setup context to be able to gpu_hook
   gpu_hook(1);
   gpu_hook(3);
	no_of_nodes=0;
	edge_list_size=0;
	BFSGraph( argc, argv);
}

void Usage(int argc, char**argv){

fprintf(stderr,"Usage: %s <input_file>\n", argv[0]);

}
////////////////////////////////////////////////////////////////////////////////
//Apply BFS on a Graph using CUDA
////////////////////////////////////////////////////////////////////////////////
void BFSGraph( int argc, char** argv) 
{

    char *input_f;
	if(argc!=2){
	Usage(argc, argv);
	exit(0);
	}
	
	input_f = argv[1];
	printf("Reading File\n");
	//Read in Graph from a file
	fp = fopen(input_f,"r");
	if(!fp)
	{
		printf("Error Reading graph file\n");
		return;
	}

	int source = 0;

	fscanf(fp,"%d",&no_of_nodes);

	int num_of_blocks = 1;
	int num_of_threads_per_block = no_of_nodes;

	//Make execution Parameters according to the number of nodes
	//Distribute threads across multiple Blocks if necessary
	if(no_of_nodes>MAX_THREADS_PER_BLOCK)
	{
		num_of_blocks = (int)ceil(no_of_nodes/(double)MAX_THREADS_PER_BLOCK); 
		num_of_threads_per_block = MAX_THREADS_PER_BLOCK; 
	}
   Node* d_graph_nodes;
	HANDLE_ERROR(cudaHostAlloc( (void**) &d_graph_nodes, sizeof(Node)*no_of_nodes,0)) ;

   //Copy the Mask to device memory
	bool* d_graph_mask;
	HANDLE_ERROR(cudaHostAlloc( (void**) &d_graph_mask, sizeof(bool)*no_of_nodes,0)) ;

	bool* d_updating_graph_mask;
	HANDLE_ERROR(cudaHostAlloc( (void**) &d_updating_graph_mask, sizeof(bool)*no_of_nodes,0)) ;

	//Copy the Visited nodes array to device memory
	bool* d_graph_visited;
	HANDLE_ERROR(cudaHostAlloc( (void**) &d_graph_visited, sizeof(bool)*no_of_nodes,0)) ;


	int start, edgeno;   
	// initalize the memory
	for( unsigned int i = 0; i < no_of_nodes; i++) 
	{
		fscanf(fp,"%d %d",&start,&edgeno);
		d_graph_nodes[i].starting = start;
		d_graph_nodes[i].no_of_edges = edgeno;
		d_graph_mask[i]=false;
		d_updating_graph_mask[i]=false;
		d_graph_visited[i]=false;
	}

	//read the source node from the file
	fscanf(fp,"%d",&source);
	source=0;

	//set the source node as true in the mask
	d_graph_mask[source]=true;
	d_graph_visited[source]=true;

	fscanf(fp,"%d",&edge_list_size);
   //Copy the Edge List to device Memory
	int *d_graph_edges;
	HANDLE_ERROR(cudaHostAlloc( (void**) &d_graph_edges, sizeof(int)*edge_list_size,0)) ;

	int id,cost;
	for(int i=0; i < edge_list_size ; i++)
	{
		fscanf(fp,"%d",&id);
		fscanf(fp,"%d",&cost);
		d_graph_edges[i] = id;
	}

	if(fp)
		fclose(fp);    

	printf("Read File\n");

	// allocate device memory for result
	int* d_cost;
	HANDLE_ERROR(cudaHostAlloc( (void**) &d_cost, sizeof(int)*no_of_nodes,0));

   for(int i=0;i<no_of_nodes;i++)
		d_cost[i]=-1;
	d_cost[source]=0;
	
	//make a bool to check if the execution is over
	bool *stop;
	HANDLE_ERROR(cudaHostAlloc( (void**) &stop, sizeof(bool),0));

	printf("Copied Everything to GPU memory\n");

	// setup execution parameters
	dim3  grid( num_of_blocks, 1, 1);
	dim3  threads( num_of_threads_per_block, 1, 1);

	int k=0;
	printf("Start traversing the tree\n");
	//Call the Kernel untill all the elements of Frontier are not false
	do
	{
		//if no thread changes this value then the loop stops
		*stop=false;
      gpu_hook(2);
		Kernel<<< grid, threads, 0 >>>( d_graph_nodes, d_graph_edges, d_graph_mask, d_updating_graph_mask, d_graph_visited, d_cost, no_of_nodes);
		// check if kernel execution generated and error
		
      cudaDeviceSynchronize();
      gpu_hook(5);

		Kernel2<<< grid, threads, 0 >>>( d_graph_mask, d_updating_graph_mask, d_graph_visited, stop, no_of_nodes);
		// check if kernel execution generated and error
		

      cudaDeviceSynchronize();
      gpu_hook(5);
		k++;
	}
	while(*stop);
   HANDLE_ERROR(cudaGetLastError());


	printf("Kernel Executed %d times\n",k);


	//Store the result into a file
	FILE *fpo = fopen("result.txt","w");
	for(int i=0;i<no_of_nodes;i++)
		fprintf(fpo,"%d) cost:%d\n",i,d_cost[i]);
	fclose(fpo);
	printf("Result stored in result.txt\n");


	cudaFreeHost(d_graph_nodes);
	cudaFreeHost(d_graph_edges);
	cudaFreeHost(d_graph_mask);
	cudaFreeHost(d_updating_graph_mask);
	cudaFreeHost(d_graph_visited);
	cudaFreeHost(d_cost);
}
