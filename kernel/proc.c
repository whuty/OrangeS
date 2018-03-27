#include "type.h"
#include "const.h"
#include "protect.h"
#include "tty.h"
#include "string.h"
#include "proc.h"
#include "global.h"
#include "proto.h"

PRIVATE void block(PROCESS* p);
PRIVATE void unblock(PROCESS* p);
PRIVATE int  msg_send(PROCESS* current, int dest, MESSAGE* m);
PRIVATE int  msg_receive(PROCESS* current, int src, MESSAGE* m);
PRIVATE int  deadlock(int src, int dest);

PUBLIC void schedule()
{
	PROCESS* p;
	int greatest_ticks = 0;
	while (!greatest_ticks) {
		for (p = proc_table; p < proc_table + NR_TASKS + NR_PROCS; p++) {
			if (p->p_flags == 0) {
				if (p->ticks > greatest_ticks) {
					greatest_ticks = p->ticks;
					p_proc_ready = p;
				}
			}
		}
		if (!greatest_ticks) {
			for (p = proc_table; p < proc_table + NR_TASKS + NR_PROCS; p++)
				if (p->p_flags == 0) {
					p->ticks = p->priority;
				}
		}
	}
}

// sys_sendrec
// <ring 0> the core routine of system call sendrec()
// @param function SEND or RECEIVE
// @param src_dest To/From the message is transferred
// @param m        Ptr to the message body
// @param p        The caller proc
//
// return 0 if success

PUBLIC int sys_sendrec(int function, int src_dest, MESSAGE* m, PROCESS* p)
{
	assert(k_reenter == 0);         /* make sure not in ring0*/
	assert((src_dest >= 0 && src_dest < NR_TASKS + NR_PROCS) ||
	       src_dest == ANY || src_dest == INTERRUPT);
	int ret = 0;
	int caller = proc2pid(p);
	MESSAGE* mla = (MESSAGE*)va2la(caller, m);
	mla->source = caller;

	assert(mla->source != src_dest);

	if (function == SEND) {
		ret = msg_send(p, src_dest, m);
		if (ret != 0) {
			return ret;
		}
	} else if (function == RECEIVE) {
		ret = msg_receive(p, src_dest, m);
		if (ret != 0) {
			return ret;
		}
	}else {
		panic("{sys_sendrec} invalid function: "
		      "%d (SEND:%d, RECEIVE:%d).", function, SEND, RECEIVE);
	}
	return 0;
}

/***************************************************************************                               send_recv
 ***************************************************************************/
/*
 * <Ring 1~3> IPC syscall.
 *
 * It is an encapsulation of `sendrec',
 * invoking `sendrec' directly should be avoided
 *
 * @param function  SEND, RECEIVE or BOTH
 * @param src_dest  The caller's proc_nr
 * @param msg       Pointer to the MESSAGE struct
 *
 * @return always 0.
 *****************************************************************************/
PUBLIC int send_recv(int function, int src_dest, MESSAGE* msg)
{
	int ret = 0;

	if (function == RECEIVE)
		memset(msg, 0, sizeof(MESSAGE));

	switch (function) {
	case BOTH:
		ret = sendrec(SEND, src_dest, msg);
		if (ret == 0)
			ret = sendrec(RECEIVE, src_dest, msg);
		break;
	case SEND:
	case RECEIVE:
		ret = sendrec(function, src_dest, msg);
		break;
	default:
		assert((function == BOTH) ||
		       (function == SEND) || (function == RECEIVE));
		break;
	}

	return ret;
}

/*
 * ldt_seg_linear
 */
// <Ring 0~1> Calculate the linear address of a certain segment of a given proc
// @param p  the proc ptr.
// @param idx one proc has more than one segments.
//
// @return The required linear address.
PUBLIC int ldt_seg_linear(PROCESS* p, int idx)
{
	DESCRIPTOR* d = &p->ldts[idx];

	return d->base_high << 24 | d->base_mid << 16 | d->base_low;
}

//    va2la
// <Ring 0~1> Virtual addr to Linear addr.
// @param pid PID of the proc
// @param va Virtual address.
//
// @return The linear address for the given virtual address
PUBLIC void* va2la(int pid, void* va)
{
	PROCESS* p = &proc_table[pid];
	u32 seg_base = ldt_seg_linear(p, INDEX_LDT_RW);
	u32 la = seg_base + (u32)va;

	if (pid < NR_TASKS + NR_PROCS) {
		assert(la == (u32)va);
	}

	return (void*)la;
}

// reset_msg
// <Ring 0~3> Clear up a message by setting each byte to 0
//
// @param p The message to be cleared.
PUBLIC void reset_msg(MESSAGE* p)
{
	memset(p, 0, sizeof(MESSAGE));
}

// block
// <Ring 0> This routine is called after 'p_flags' has been set (!=1),
// it calls 'schedule()' to choose another proc as the 'proc_ready'.
//
// @attention This routine does not change 'p_flags'.Make sure the
// 'p_flags' of the proc to be blocked has been set properly.
//
// @param p The proc to be blocked.
PRIVATE void block(PROCESS* p)
{
	assert(p->p_flags);
	schedule();
}

// unblock
PRIVATE void unblock(PROCESS* p)
{
	assert(p->p_flags == 0);         //now it does nothing
}

/*****************************************************************************
*                                deadlock
*****************************************************************************/
/**
 * <Ring 0> Check whether it is safe to send a message from src to dest.
 * The routine will detect if the messaging graph contains a cycle. For
 * instance, if we have procs trying to send messages like this:
 * A -> B -> C -> A, then a deadlock occurs, because all of them will
 * wait forever. If no cycles detected, it is considered as safe.
 *
 * @param src   Who wants to send message.
 * @param dest  To whom the message is sent.
 *
 * @return Zero if success.
 *****************************************************************************/
PRIVATE int deadlock(int src, int dest)
{
	PROCESS* p = proc_table + dest;
	while (1) {
		if (p->p_flags & SENDING) {
			if (p->p_sendto == src) {
				/*print the chain */
				p = proc_table + dest;
				printf("deadlock %s", p->p_name);
				do {
					assert(p->p_msg);
					p = proc_table + p->p_sendto;
					printf("->%s", p->p_name);
				} while (p != proc_table + src);
				printf("..");
				return 1;
			}
			p = proc_table + p->p_sendto;
		}else {
			break;
		}
	}
	return 0;
}

/*****************************************************************************
*                                msg_send
*****************************************************************************/
/**
 * <Ring 0> Send a message to the dest proc. If dest is blocked waiting for
 * the message, copy the message to it and unblock dest. Otherwise the caller
 * will be blocked and appended to the dest's sending queue.
 *
 * @param current  The caller, the sender.
 * @param dest     To whom the message is sent.
 * @param m        The message.
 *
 * @return Zero if success.
 *****************************************************************************/
PRIVATE int msg_send(PROCESS* current, int dest, MESSAGE* m)
{
	PROCESS* sender = current;
	PROCESS* p_dest = proc_table + dest;

	assert(proc2pid(sender) != dest);

	if (deadlock(proc2pid(sender), dest)) {
		panic(">>deadlock<< %s->%s", sender->p_name, p_dest->p_name);
	}
	if ((p_dest->p_flags & RECEIVING) &&         /*dest is waiting for the msg*/
	    (p_dest->p_recvfrom == proc2pid(sender) || p_dest->p_recvfrom == ANY)) {
		assert(p_dest->p_msg);
		assert(m);
		phys_copy(va2la(dest, p_dest->p_msg),
			  va2la(proc2pid(sender), m),
			  sizeof(MESSAGE));
		p_dest->p_msg = 0;
		p_dest->p_flags &= ~RECEIVING;         /* dest has received the msg */
		p_dest->p_recvfrom = NO_TASK;
		unblock(p_dest);

		assert(p_dest->p_flags == 0);
		assert(p_dest->p_msg == 0);
		assert(p_dest->p_recvfrom == NO_TASK);
		assert(sender->p_flags == 0);
		assert(sender->p_msg == 0);
	}else {         /* dest is not waiting for the msg */
		sender->p_flags |= SENDING;
		assert(sender->p_flags == SENDING);
		sender->p_sendto = dest;
		sender->p_msg = m;

		/* append to the sending queue */
		PROCESS* p;
		if (p_dest->q_sending) {
			p = p_dest->q_sending;
			while (p->next_sending)
				p = p->next_sending;
			p->next_sending = sender;
		}else {
			p_dest->q_sending = sender;
		}
		sender->next_sending = 0;

		block(sender);

		assert(sender->p_flags == SENDING);
		assert(sender->p_msg != 0);
		//assert(sender->p_recvfrom == NO_TASK);
		assert(sender->p_sendto == dest);
	}

	return 0;
}


/*****************************************************************************
*                                msg_receive
*****************************************************************************/
/**
 * <Ring 0> Try to get a message from the src proc. If src is blocked sending
 * the message, copy the message from it and unblock src. Otherwise the caller
 * will be blocked.
 *
 * @param current The caller, the proc who wanna receive.
 * @param src     From whom the message will be received.
 * @param m       The message ptr to accept the message.
 *
 * @return  Zero if success.
 *****************************************************************************/
PRIVATE int msg_receive(PROCESS* current, int src, MESSAGE* m)
{
	PROCESS* p_recv = current;
	PROCESS* p_from = 0;
	PROCESS* prev = 0;

	int copyok = 0;

	assert(proc2pid(p_recv) != src);

	if ((p_recv->has_int_msg) &&
	    ((src == ANY) || (src == INTERRUPT))) {
		/* There is an interrupt needs p_recv to handle and p_recv is ready*/
		MESSAGE msg;
		reset_msg(&msg);
		msg.source = INTERRUPT;
		msg.type = HARD_INT;
		assert(m);
		phys_copy(va2la(proc2pid(p_recv), m), &msg, sizeof(MESSAGE));
		p_recv->has_int_msg = 0;

		assert(p_recv->p_flags == 0);
		assert(p_recv->p_msg);
		assert(p_recv->p_sendto == NO_TASK);
		assert(p_recv->has_int_msg == 0);

		return 0;
	}

	if (src == ANY) {
		if (p_recv->q_sending) {
			p_from = p_recv->q_sending;
			copyok = 1;
		}
	}else {
		//receive a message from a certain proc
		p_from = &proc_table[src];

		if ((p_from->p_flags & SENDING) &&
		    (p_from->p_sendto == proc2pid(p_recv))) {
			//src is sending a message to p_recv
			copyok = 1;

			PROCESS* p = p_recv->q_sending;

			assert(p);

			while (p) {
				assert(p_from->p_flags & SENDING);
				if (proc2pid(p) == src) {
					p_from = p;
					break;
				}
				prev = p;
				p = p->next_sending;
			}

			assert(p_recv->p_flags == 0);
			assert(p_recv->p_msg == 0);
			assert(p_recv->q_sending != 0);
			assert(p_from->p_flags == SENDING);
			assert(p_from->p_msg != 0);
			assert(p_from->p_sendto == proc2pid(p_recv));
		}
	}
	if (copyok) {
		//copy the message
		if (p_from == p_recv->q_sending) {
			assert(prev == 0);

			p_recv->q_sending = p_from->next_sending;
			p_from->next_sending = 0;
		}else {
			assert(prev != 0);
			prev->next_sending = p_from->next_sending;
			p_from->next_sending = 0;
		}
		assert(m != 0);
		assert(p_from->p_msg != 0);
		phys_copy(va2la(proc2pid(p_recv), m),
			  va2la(proc2pid(p_from), p_from->p_msg),
			  sizeof(MESSAGE));
		p_from->p_msg = 0;
		p_from->p_sendto = NO_TASK;
		p_from->p_flags &= ~SENDING;
		unblock(p_from);
	}else {
		//no proc is sending msg, set p_flags so p_recv
		//will not be schedule until it is unblocked.
		p_recv->p_flags |= RECEIVING;
		p_recv->p_msg = m;
		if (src == ANY) {
			p_recv->p_recvfrom = ANY;
		}else {
			p_recv->p_recvfrom = proc2pid(p_from);
		}
		block(p_recv);

		assert(p_recv->p_flags == RECEIVING);
		assert(p_recv->p_msg != 0);
		assert(p_recv->p_recvfrom != NO_TASK);
		assert(p_recv->has_int_msg == 0);
	}
	return 0;
}
