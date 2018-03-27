
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                               proc.h
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                                                    Forrest Yu, 2005
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
#pragma once

#include "protect.h"

typedef struct s_stackframe {
	u32	gs;		/* \                                    */
	u32	fs;		/* |                                    */
	u32	es;		/* |                                    */
	u32	ds;		/* |                                    */
	u32	edi;		/* |                                    */
	u32	esi;		/* | pushed by save()                   */
	u32	ebp;		/* |                                    */
	u32	kernel_esp;	/* <- 'popad' will ignore it            */
	u32	ebx;		/* |                                    */
	u32	edx;		/* |                                    */
	u32	ecx;		/* |                                    */
	u32	eax;		/* /                                    */
	u32	retaddr;	/* return addr for kernel.asm::save()   */
	u32	eip;		/* \                                    */
	u32	cs;		/* |                                    */
	u32	eflags;		/* | pushed by CPU during interrupt     */
	u32	esp;		/* |                                    */
	u32	ss;		/* /                                    */
}STACK_FRAME;


typedef struct s_proc {
	STACK_FRAME regs;          /* process registers saved in stack frame */

	u16 ldt_sel;               /* gdt selector giving ldt base and limit */
	DESCRIPTOR ldts[LDT_SIZE]; /* local descriptors for code and data */

	int ticks;
	int priority;

	u32 pid;                   /* process id passed in from MM */
	char p_name[16];           /* name of the process */

	int p_flags;

	MESSAGE* p_msg;
	int p_recvfrom;
	int p_sendto;

	int has_int_msg;

	struct s_proc* q_sending;    //queue of procs sending msg
	struct s_proc* next_sending; //next proc int the sending queue

	int nr_tty;
}PROCESS;

typedef struct s_task{
	task_f initial_eip;
	int stacksize;
	int priority;
	char name[32];
}TASK;

#define proc2pid(x) (x - proc_table)

/* Number of tasks */
#define NR_TASKS	2
#define NR_PROCS  2
#define FIRST_PROC	proc_table[0]
#define LAST_PROC	proc_table[NR_TASKS + NR_PROCS - 1]

/* stacks of tasks */
#define STACK_SIZE_TESTA	0x8000
#define STACK_SIZE_TESTB	0x8000

#define STACK_SIZE_TTY 0x8000
#define STACK_SIZE_SYS 0x8000

#define STACK_SIZE_TOTAL	(STACK_SIZE_TESTA + \
													STACK_SIZE_TESTB + \
													STACK_SIZE_TTY + \
												  STACK_SIZE_SYS)
