

;================================================================
;;gdt   Global Descriptor Table
;High----------------------------------------------------------Low
;|Byte7	|Byte6	|Byte5	|Byte4	|Byte3	|Byte2	|Byte1	|Byte0	|
;|	31..24		|Attr&	|		23..0 			|	15..0 		|
;|Base 24		|Some	|		Base1			|    Limit1		|
;----------------------------------------------------------------
;|Byte6                         |
;|7	|6 	|5	|4	|3 	|2 	|1 	|0 	|
;|G	|D/B|0 	|AVL|19..16Limit2	|
;|Byte7                         |
;|7 |6	|5	|4	|3 	|2 	|1 	|0 	|
;|P	|DPL 	|S 	|-----TYPE-----	|
;-----------------------------------------------------------------
;P 		Present				Present bit. This must be 1 for all valid selectors.
;DPL	Descriptor Privilege Level	Privilege, 2 bits. Contains the ring level, 0 = highest (kernel), 3 = lowest (user applications).
;S 		System segment		0:System,1:code or data
;TYPE 
;bit0	Accessed			Just set to 0. The CPU sets this to 1 when the segment is accessed.
;bit3	Executable bit. 			If 1 code in this segment can be executed, ie. a code selector. If 0 it is a data selector.
;when data selector
;bit1	Write				If 0 , only readable.If 1, writeable
;bit2	Expand Direct			Direction bit for data selectors: Tells the direction. 0 the segment grows up. 1 the segment grows down, ie. the offset has to be greater than the limit.
;when code selector
;bit1	Read 				if 0 , only executable.If 1, readable
;bit2	Conforming			if 0 , not Conforming.If 1, Conforming

;G 	Granularity			If 0 the limit is in 1 B blocks (byte granularity), if 1 the limit is in 4 KiB blocks (page granularity).
;D/B 	
;when code Descriptor
;D 	 If 0 the selector defines 16 bit protected mode , using 16/8 bit operators. If 1 it defines 32 bit protected mode , using 32/8 bit operators. 
;when data segment grows down
;B 	If 0 the top of the segment limits 64kb.If 1 , 4GB
;when describe stack segment ( pointed by ss register )
;B 	If 1 , implicit stack operate use 32bit esp.If 0 , use 16bit sp 
;AVL 	available by software

; usage : Descriptor  Base,Limit, Attr
;	  Base:	dd
;	  Limit:	dd ( low 20 bits available )
;	  Attr:	dw (lower 4 bits of higher byte are always 0)
%macro  Descriptor  3						;3 parameter
dw	%2 & 0FFFFh								;segment Limit 1
dw	%1 & 0FFFFh								;segment Base addr 1
db	(%1 >> 16) & 0FFh 						;higher byte of Base 1
	dw	((%2 >> 8) & 0F00h) | (%3 & 0F0FFh)		;Attribute and Limit 2
db	(%1 >> 24) & 0FFh 						;segment Base addr 2
%endmacro

;Gate
;usage:Gate Selector,offset,DCount,Attr
;	Selector:	dw
;	offset:		dd
;	DCount:		db
;	Attr:		db
%macro Gate 4
	dw (%2 & 0FFFFh)	;offset 1
	dw %1 				;Selector
	dw (%3 & 1Fh)|((%4 << 8) & 0FF00h) 	;Attribute
	dw ((%2 >> 16) & 0FFFFh) 			;offset 2
%endmacro

;Descriptor Type
DA_32		equ	4000h	;32bit segment
DA_LIMIT_4K equ 8000h 	;

DA_DPL0	equ	00h 	;DPL=0
DA_DPL1	equ	20h		;DPL=1
DA_DPL2	equ	40h 	;DPL=2
DA_DPL3	equ	60h		;DPL=3

;Storage Segment Descriptor
DA_DR		equ	90h	;only readable data segment
DA_DRW		equ	92h	;readable,writeable
DA_DRWA		equ	93h	;Accessed R W
DA_C		equ	98h	;only executable code segment
DA_CR		equ	9Ah	;R
DA_CCO		equ	9Ch	;only executable Conforming code segment
DA_CCOR		equ	9Eh	;Readable Conforming code segment

;System Segment Descriptor
DA_LDT		equ	82h	;Local Descriptor Table
DA_TaskGate	equ	85h	;TaskGate
DA_386TSS	equ	89h	;386 Task State Segment
DA_386CGate	equ	8Ch	;386 Call Gate
DA_386IGate	equ	8Eh	;386 Trap Gate
DA_386TGate	equ	8Fh	;386 Interrupt Gate


;Selector
;|15|14|13|12|11|10|9 |8 |7 |6 |5 |4 |3 |2 |1 |0 |
;|-----Descriptor Index-----------------|TI|RPL  |
;RPL	Requested Privilege level
;Ti 	Table Indicator
;	TI=0 read Descriptor from GDT
;	TI=1 read Descriptor from LDT

;SA_ : Selector Attribute
SA_RPL0		equ		0 	;
SA_RPL1		equ 	1
SA_RPL2		equ		2 	;
SA_RPL3		equ 	3
SA_TIG		equ 	0
SA_TIL		equ 	4

;used for paging
PG_P 	equ 1 	;page present 
PG_RWR 	equ 0 	;R/W,read/execute
PG_RWW 	equ 2 	;R/W,read/write/execute
PG_USS 	equ 0 	;U/S,system level
PG_USU 	equ 4 	;U/S,user level