;============================
;pmtest5.asm
;nasm pmtest5.asm -o pmtest5.bin
;if debug in dos
;nasm pmtest5.asm -o pmtest5.com
;%define _BOOT_DEBUG_
;============================

%include	"pm.inc"

%define _BOOT_DEBUG_
%ifdef _BOOT_DEBUG_
org	0100h
%else
org 07c00h		;the program is loaded at 7c00
%endif
	jmp	LABEL_BEGIN

;gdt   Global Descriptor Table
[SECTION	.gdt]
;gdt
;			Descriptor is defined in pm.inc
;					segment 	segment		Attribute
;					base addr	limit
LABEL_GDT:			Descriptor		0,		0,					0		; null Descriptor
LABEL_DESC_NORMAL	Descriptor 		0,		0ffffh,				DA_DRW	; normal Descriptor
LABEL_DESC_CODE32:	Descriptor		0,		SegCode32Len - 1,	DA_C+DA_32	; not Conforming Code Segment , 32bit
LABEL_DESC_CODE16:	Descriptor		0,		0ffffh,				DA_C		; not Conforming Code Segment , 16bit
LABEL_DESC_CODE_RING3:	Descriptor 		0,		SegCodeRing3Len - 1,DA_C+DA_32+DA_DPL3
LABEL_DESC_DATA:	Descriptor 		0,		DataLen - 1,		DA_DRW	;Data
LABEL_DESC_STACK:	Descriptor 		0,		TopOfStack,			DA_DRWA+DA_32	;Stack , 32bit
LABEL_DESC_STACK3:	Descriptor 		0,		TopOfStack3,		DA_DRWA+DA_32+DA_DPL3
LABEL_DESC_VIDEO:	Descriptor	0B8000h,	0ffffh,				DA_DRW+DA_DPL3	; Video Memory

LABEL_DESC_CODE_DEST:Descriptor 	0,		SegCodeDestLen - 1,	DA_C+DA_32

LABEL_DESC_LDT:		Descriptor 		0,		LDTLen - 1,			DA_LDT	;LDT

LABEL_DESC_TSS:		Descriptor 		0,		TSSLen - 1,			DA_386TSS

;Gate 					Selector,				offset,	DCount,	Attr
LABEL_CALL_GATE_TEST:	Gate SelectorCodeDest, 	0, 		0, 		DA_386CGate + DA_DPL3
;gdt end

GdtLen		equ	$ - LABEL_GDT	;gdt length
GdtPtr		dw 	GdtLen - 1 	;gdt limit
			dd 	0 		;gdt base addr
						;6 bytes

;GDT selector
SelectorNormal	 	equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32 	- LABEL_GDT
SelectorCode16	 	equ LABEL_DESC_CODE16	- LABEL_GDT
SelectorCodeRing3 	equ LABEL_DESC_CODE_RING3 - LABEL_GDT + SA_RPL3
SelectorData		equ	LABEL_DESC_DATA 	- LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK 	- LABEL_GDT
SelectorStack3 		equ LABEL_DESC_STACK3 	- LABEL_GDT + SA_RPL3
SelectorVideo		equ	LABEL_DESC_VIDEO 	- LABEL_GDT

SelectorCodeDest 	equ LABEL_DESC_CODE_DEST - LABEL_GDT

SelectorCallGateTest equ LABEL_CALL_GATE_TEST - LABEL_GDT + SA_RPL3

SelectorLDT 		equ LABEL_DESC_LDT		- LABEL_GDT

SelectorTSS 		equ LABEL_DESC_TSS 		- LABEL_GDT


; END of [SECTION  .gdt]

[SECTION  .data1]
ALIGN	32
[BITS 	32]
LABEL_DATA:
SPValueInRealMode	dw 	0
;String
PMMessage:		db 	"In protect Mode now .",0 	;display in protect mode
OffsetPMMessage	equ	PMMessage - $$
StrTest:			db 	"ABCDEFGHIJKLMNOPQRSTUVWXYZ",0
OffsetStrTest		equ	StrTest - $$
DataLen 		equ	$ - LABEL_DATA
;END of SECTION .data1

[SECTION  .gs]
ALIGN 	32
[BITS	32]
LABEL_STACK:
		times 512 db 0
TopOfStack 	equ	$ - LABEL_STACK - 1
;END of SECTION .gs
[SECTION  .s3]
ALIGN	32
[BITS 	32]
LABEL_STACK3:
	times 512 db 0
TopOfStack3 equ $ - LABEL_STACK3 - 1

[SECTION  .tss]
ALIGN 	32
[BITS 	32]
;TSS: task state stack
LABEL_TSS:
		DD 0 				;back
		DD TopOfStack 		;lv 0 Stack
		DD SelectorStack
		DD 0 				;lv 1 Stack
		DD 0
		DD 0 	;lv 2 Stack
		DD 0
		DD 0 	;CR3 
		DD 0 	;EIP
		DD 0 	;EFLAGS
		DD 0 	;EAX 
		DD 0 	;ECX
		DD 0 	;EDX
		DD 0 	;EBX 
		DD 0 	;ESP 
		DD 0 	;EBP
		DD 0 	;ESI 
		DD 0 	;EDI 
		DD 0 	;ES 
		DD 0 	;CS 
		DD 0 	;SS 
		DD 0 	;DS 
		DD 0 	;FS 
		DD 0 	;GS 
		DD 0 	;LDT 
		DW 0 	;Debug Trap flag
		DW 0 	;I/O bitMap base address
		DW $ - LABEL_TSS + 2 ;I/O bitMap ending flag
TSSLen 	equ 	$ - LABEL_TSS

[SECTION  .s16]
[BITS	16]
LABEL_BEGIN:
	mov	ax,  cs
	mov	ds,  ax
	mov	es,  ax
	mov	ss,  ax
	mov	sp,  0100h

	mov	[LABEL_GO_BACK_TO_REAL + 3], ax
	mov	[SPValueInRealMode] , sp

	; initialize the 16bit code segment Descriptor
	mov	ax , cs
	movzx	eax, ax
	shl	eax, 4
	add 	eax, LABEL_SEG_CODE16
	mov	word  [LABEL_DESC_CODE16 + 2] ,  ax
	shr	eax,  16
	mov	byte [LABEL_DESC_CODE16 + 4] ,  al
	mov	byte [LABEL_DESC_CODE16 + 7] ,  ah	;let the Physical Address be the segment base addr

	; initialize the data segment Descriptor
	xor	eax, eax
	mov	ax, ds 
	shl	eax, 4
	add 	eax, LABEL_DATA
	mov	word  [LABEL_DESC_DATA + 2] ,  ax
	shr	eax,  16
	mov	byte [LABEL_DESC_DATA + 4] ,  al
	mov	byte [LABEL_DESC_DATA + 7] ,  ah	;let the Physical Address be the segment base addr

	; initialize the 32 bits code segment Descriptor
	xor	eax,  eax				;clear  eax
	mov	ax,  cs
	shl	eax,  4					;Physical Address = Segment * 16 + Offset
	add	eax,LABEL_SEG_CODE32			;the Physical Address of  LABEL_SEG_CODE32
	mov	word  [LABEL_DESC_CODE32 + 2] ,  ax
	shr	eax,  16
	mov	byte [LABEL_DESC_CODE32 + 4] ,  al
	mov	byte [LABEL_DESC_CODE32 + 7] ,  ah	;let the Physical Address be the segment base addr

	; initialize the stack segment Descriptor
	xor	eax, eax
	mov	ax, ds 
	shl	eax, 4
	add 	eax, LABEL_STACK
	mov	word  [LABEL_DESC_STACK + 2] ,  ax
	shr	eax,  16
	mov	byte [LABEL_DESC_STACK + 4] ,  al
	mov	byte [LABEL_DESC_STACK + 7] ,  ah	;let the Physical Address be the segment base addr

	xor	eax, eax
	mov	ax, ds 
	shl	eax, 4
	add 	eax, LABEL_STACK3
	mov	word  [LABEL_DESC_STACK3 + 2] ,  ax
	shr	eax,  16
	mov	byte [LABEL_DESC_STACK3 + 4] ,  al
	mov	byte [LABEL_DESC_STACK3 + 7] ,  ah

	;initialize the LDT Descriptor in GDT
	xor	eax, eax
	mov	ax, ds 
	shl	eax, 4
	add 	eax, LABEL_LDT
	mov	word  [LABEL_DESC_LDT + 2] ,  ax
	shr	eax,  16
	mov	byte [LABEL_DESC_LDT + 4] ,  al
	mov	byte [LABEL_DESC_LDT + 7] ,  ah

	;initialize the Descriptor in LDT
	xor	eax, eax
	mov	ax, ds 
	shl	eax, 4
	add eax, LABEL_CODE_A
	mov	word [LABEL_LDT_DESC_CODEA + 2] ,  ax
	shr	eax,  16
	mov	byte [LABEL_LDT_DESC_CODEA + 4] ,  al
	mov	byte [LABEL_LDT_DESC_CODEA + 7] ,  ah

	;initialize the Descriptor of Call Gate
	xor	eax, eax
	mov	ax, cs 
	shl	eax, 4
	add eax, LABEL_SEG_CODE_DEST
	mov	word [LABEL_DESC_CODE_DEST + 2] ,  ax
	shr	eax,  16
	mov	byte [LABEL_DESC_CODE_DEST + 4] ,  al
	mov	byte [LABEL_DESC_CODE_DEST + 7] ,  ah

	xor	eax, eax
	mov	ax, ds 
	shl	eax, 4
	add eax, LABEL_CODE_RING3
	mov	word [LABEL_DESC_CODE_RING3 + 2] ,  ax
	shr	eax,  16
	mov	byte [LABEL_DESC_CODE_RING3 + 4] ,  al
	mov	byte [LABEL_DESC_CODE_RING3 + 7] ,  ah

	xor	eax, eax
	mov	ax, ds 
	shl	eax, 4
	add eax, LABEL_TSS
	mov	word [LABEL_DESC_TSS + 2] ,  ax
	shr	eax,  16
	mov	byte [LABEL_DESC_TSS + 4] ,  al
	mov	byte [LABEL_DESC_TSS + 7] ,  ah

	;initialize the GdtPtr,prepare for loading GDTR
	xor	eax,  eax
	mov	ax,  ds
	shl	eax, 4
	add	eax, LABEL_GDT
	mov	dword  [GdtPtr+2] , eax

	;loading GDTR
	lgdt 	[GdtPtr]

	;clear interrupt
	;the manage of interrupt in protect mode is different
	cli

	in 	al,92h
	or 	al,00000010b
	out	92h,al

	;prepare for protect mode
	;the 0bit of register cr0 is  PE .When PE=0, CPU is in real mode ,when 1 , protect mode
	mov	eax,cr0
	or 	eax,1
	mov	cr0,eax

	jmp 	dword  SelectorCode32:0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LABEL_REAL_ENTRY:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov ss, ax

	mov	sp, [SPValueInRealMode]

	;turn off the A20  Address Line
	in 	al,92h
	and al, 11111101b
	out	92h,al 

	sti 
	mov	ax, 4c00h
	int 	21h
	;back to dos
;END of [SECTION  .s16]

[SECTION  .s32]
[BITS	32]

LABEL_SEG_CODE32:
	mov	ax,SelectorData
	mov	ds, ax

	mov	ax,SelectorVideo
	mov	gs,ax

	mov	ax,SelectorStack
	mov	ss,ax

	mov	esp,TopOfStack

	mov	ah,0Ch 			;0000 black background,1100  red word
	xor	esi,esi
	xor	edi,edi
	mov	esi, OffsetPMMessage
	mov	edi, (80*1+0) * 2	;the 1st row,0th column of the screen
	cld
.1:
	lodsb
	test 	al,al
	jz	.2
	mov	[gs:edi],ax
	add 	edi, 2
	jmp	.1
.2:
	call 	DispReturn


	mov ax,SelectorTSS
	ltr ax ;

	push SelectorStack3
	push TopOfStack3
	push SelectorCodeRing3
	push 0
	retf 	;ring0 -> ring3


;-----------------------------------------------------------------------------------------------------------------------
DispReturn:
	push 	eax
	push	ebx
	mov	eax, edi
	mov	bl, 160
	div 	bl
	and	eax, 0FFh 
	inc 	eax
	mov 	bl, 160
	mul	bl
	mov	edi, eax
;set edi to next Line
	pop	ebx
	pop	eax

	ret 
;-------------------------------------------------------------------------------------------------------------



SegCode32Len 		equ	$ - LABEL_SEG_CODE32
;END of [SECTION  .s32]

[SECTION .s16code]
ALIGN 	32
[BITS 	16]
LABEL_SEG_CODE16:
;jmp back to real mode
	mov	ax, SelectorNormal
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax

	mov	eax, cr0
	and	al,11111110b
	mov	cr0,eax
LABEL_GO_BACK_TO_REAL:
	jmp	0:LABEL_REAL_ENTRY	;
Code16Len	equ	$ - LABEL_SEG_CODE16
;END of [SECTION  .s16code]

[SECTION .ldt]
ALIGN	32
LABEL_LDT:

LABEL_LDT_DESC_CODEA:	Descriptor 	0,	CodeALen - 1,	DA_C+DA_32	;Code,32bit

LDTLen 		equ		$ - LABEL_LDT

SelectorLDTCodeA 	equ		LABEL_LDT_DESC_CODEA - LABEL_LDT + SA_TIL
;END of [SECTION .ldt]

;CodeA (LDT, 32bit code segment)
[SECTION .la]
ALIGN 	32
[BITS 	32]
LABEL_CODE_A:
	mov ax, SelectorVideo
	mov gs, ax

	mov edi,(80*4+0)*2
	mov ah, 0Ch
	mov al, 'L'
	mov [gs:edi], ax

	jmp SelectorCode16:0
CodeALen 	equ 	$ - LABEL_CODE_A
;END of [SECTION .la]

[SECTION .sdest]
[BITS 	32]

LABEL_SEG_CODE_DEST
	;jmp $
	mov ax,SelectorVideo
	mov gs,ax
	mov edi,(80*2+0)*2
	mov ah,0Ch 
	mov al,'C'
	mov [gs:edi], ax

	mov ax,SelectorLDT
	lldt ax

	jmp SelectorLDTCodeA:0

SegCodeDestLen 	equ 	$ - LABEL_SEG_CODE_DEST
;END of [SECTION .sdest]

[SECTION .ring3]
ALIGN 	32
[BITS 	32]
LABEL_CODE_RING3:
	mov ax,SelectorVideo
	mov gs,ax
	mov edi,(80*3+0)*2
	mov ah,0Ch
	mov al,'3'
	mov [gs:edi],ax

	call SelectorCallGateTest:0
	jmp $
SegCodeRing3Len equ $ - LABEL_CODE_RING3