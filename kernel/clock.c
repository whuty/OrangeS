#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "string.h"
#include "proc.h"
#include "global.h"

PUBLIC void init_clock()
{
  /* initial 8253 PIT */
	out_byte(TIMER_MODE, TIMER_RATE_GENERATOR);
	out_byte(TIMER0, (u8) (TIMER_FREQ/HZ) );
	out_byte(TIMER0, (u8) ((TIMER_FREQ/HZ) >> 8));

	put_irq_handler(CLOCK_IRQ, clock_handler); /* Set clock interrupt */
	enable_irq(CLOCK_IRQ);                     /* Open clock interrupt */
}

PUBLIC void clock_handler(int irq)
{
  //disp_str("#");
  ticks++;
  p_proc_ready->ticks--;
  if(k_reenter !=0){
    //disp_str("!");
    return;
  }
  schedule();
}

// delay function that not very accurate
PUBLIC void milli_delay(int milli_sec)
{
  int t=get_ticks();
  while(((get_ticks() - t)*1000/HZ) < milli_sec) {}
}
