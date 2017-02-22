#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "string.h"
#include "global.h"

PUBLIC void* memcpy(void* pDst,void* pSrc,int iSize);

PUBLIC u8 gdt_ptr[6];/* 0~15:Limit  16~47:Base */
PUBLIC DESCRIPTOR gdt[GDT_SIZE];

//cstart
PUBLIC void cstart()
{
	disp_str("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
		 "-----\"cstart\" begins-----\n");

	u16* p_gdt_limit = (u16*)(&gdt_ptr[0]);
	u32* p_gdt_base  = (u32*)(&gdt_ptr[2]);

	memcpy(&gdt,				/*new gdt*/
		(void*)(*p_gdt_base),	/*old gdt base*/
		*(p_gdt_limit)+1 		/*old gdt limit*/
		);
	
	*p_gdt_limit = GDT_SIZE * sizeof(DESCRIPTOR) - 1;
	*p_gdt_base  = (u32)&gdt;
}
