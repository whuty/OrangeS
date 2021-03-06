
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            global.c
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                                                    Forrest Yu, 2005
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

#define GLOBAL_VARIABLES_HERE

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proc.h"
#include "global.h"
#include "proto.h"

PUBLIC PROCESS proc_table[NR_TASKS];

PUBLIC TASK task_table[NR_TASKS] = {{task_tty, STACK_SIZE_TTY,100, "tty"},
                                    {task_sys,STACK_SIZE_SYS,100,"SYS"}};

PUBLIC TASK user_proc_table[NR_PROCS] = {{TestA,STACK_SIZE_TESTA,50,"TestA"},
                                         {TestB,STACK_SIZE_TESTB,100,"TestB"}};

PUBLIC irq_handler irq_table[NR_IRQ];

PUBLIC system_call sys_call_table[NR_SYS_CALL]={sys_sendrec,sys_printx};

PUBLIC	char			task_stack[STACK_SIZE_TOTAL];

PUBLIC	TTY		tty_table[NR_CONSOLES];
PUBLIC	CONSOLE		console_table[NR_CONSOLES];
