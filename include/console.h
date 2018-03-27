#pragma once
#include "tty.h"

//console
typedef struct s_console
{
  unsigned int current_start_addr;
  unsigned int original_addr;
  unsigned int video_mem_limit;
  unsigned int cursor;
}CONSOLE;

#define SCR_UP	1	/* scroll forward */
#define SCR_DN	-1	/* scroll backward */

#define SCREEN_SIZE		(80 * 25)
#define SCREEN_WIDTH		80

#define DEFAULT_CHAR_COLOR	(MAKE_COLOR(BLACK, WHITE))
#define GRAY_CHAR		(MAKE_COLOR(BLACK, BLACK) | BRIGHT)
#define RED_CHAR		(MAKE_COLOR(BLUE, RED) | BRIGHT)

PUBLIC int is_current_console(CONSOLE* p_con);
PUBLIC void init_screen(TTY* p_tty);
PUBLIC void out_char(CONSOLE* p_con, char ch);
PUBLIC void select_console(int nr_console);
PUBLIC void scroll_screen(CONSOLE* p_con, int direction);
