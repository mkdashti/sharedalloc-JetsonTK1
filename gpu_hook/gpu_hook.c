/*
 *
 * * gpu_hook Linux Kernel Module by Mohammad Dashti
 *
 * */

#include <linux/init.h> 
#include <linux/module.h> 
#include <linux/syscalls.h>
#include <linux/printk.h>

#include <linux/dma-mapping.h>
#include <linux/export.h>
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/nvmap.h>
#include <linux/vmalloc.h>

#include <asm/memory.h>

#include <trace/events/nvmap.h>

#include "/home/ubuntu/kernel/kernel/drivers/video/tegra/nvmap/nvmap_ioctl.h"
#include "/home/ubuntu/kernel/kernel/drivers/video/tegra/nvmap/nvmap_priv.h"
#include "/home/ubuntu/kernel/kernel/drivers/gpu/nvgpu/gk20a/gk20a.h"

#include <linux/list.h>


/* see the module init below. This function pointer is exported */ 
extern pid_t (*function_pointer)(unsigned int flag);

/* This is the function body of the gpu_hook system call */
pid_t gpu_hook_module(unsigned int flag)
{

   switch(flag) {
      case 1: {
                 current->nv_handle |= GPU_HOOK_CACHEABLE;
                 break;
              }
      case 2: {// flushing the CPU caches
                 inner_flush_cache_all();
                 break;
              }
      case 3: {
                 current->nv_handle |= GPU_HOOK_GK20A_FLAG;
                 break;
              }
      case 4: {// flushing the GPU L2 cache
                 gk20a_mm_l2_flush(current->gpu_channel->g,0);
                 break;
              }
      case 5: {// flushing the GPU L2 cache with invalidations(clearing clean data from L2--forcing to access DRAM)
                 gk20a_mm_l2_flush(current->gpu_channel->g,1);
                 break;
              }
   
      case 0: { //reset flag
                 current->nv_handle = 0;
                 break;
              }
     
      default: {}
   }

   //printk(KERN_ALERT "current->nv_handle = %x\n",current->nv_handle);
   return task_tgid_vnr(current);
}

/*
 * This is a dirty hack to have the implementation of the syscall 
 * in the kernel module. Please refer to the kernel sources to see
 * that I export this function pointer.
 *
 * */ 
static int gpu_hook_init(void) 

{
   printk(KERN_ALERT "gpu_hook kernel module loaded.\n");
   function_pointer = &gpu_hook_module;

   return 0;

}
static void gpu_hook_exit(void) 

{

   printk(KERN_ALERT "gpu_hook kernel module removed\n"); 

}

module_init(gpu_hook_init); 

module_exit(gpu_hook_exit);

MODULE_LICENSE("GPL"); 

MODULE_AUTHOR("Mohammad Dashti"); 

MODULE_DESCRIPTION("GK20a GPU Hook");
