
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            proto.h
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                                                    Forrest Yu, 2005
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
#pragma once


/* kliba.asm */
PUBLIC void	out_byte(u16 port, u8 value);
PUBLIC u8	in_byte(u16 port);
PUBLIC void	disp_str(char * info);
PUBLIC void	disp_color_str(char * info, int color);
PUBLIC void enable_int();
PUBLIC void disable_int();
PUBLIC void enable_irq(int irq);
PUBLIC void disable_irq(int irq);

/*i8259.c*/
PUBLIC void	init_8259A();

/* protect.c */
PUBLIC void	init_prot();
PUBLIC u32	seg2phys(u16 seg);

/* klib.c */
PUBLIC void	delay(int time);
PUBLIC void disp_int(int);

/* kernel.asm */
void restart();

/* main.c */
void TestA();
void TestB();

/*tty.c*/
PUBLIC void task_tty();

/* i8259.c */
PUBLIC void put_irq_handler(int irq, irq_handler handler);
PUBLIC void spurious_irq(int irq);

/* clock.c */
PUBLIC void init_clock();
PUBLIC void clock_handler(int irq);
PUBLIC void milli_delay(int milli_sec);

/* proc.c */
PUBLIC int sys_get_ticks();
PUBLIC void schedule();

/* syscall.asm */
PUBLIC void sys_call();
PUBLIC int get_ticks();

// keyboard.c
PUBLIC void init_keyboard();
PUBLIC void keyboard_handler(int irq);
PUBLIC void keyboard_read();
