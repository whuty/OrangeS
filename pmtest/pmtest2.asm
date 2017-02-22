;============================
;pmtest2.asm
;nasm pmtest2.asm -o pmtest2.bin
;if debug in dos
;nasm pmtest2.asm -o pmtest2.com
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
LABEL_DESC_DATA:	Descriptor 		0,		DataLen - 1,		DA_DRW	;Data
LABEL_DESC_STACK:	Descriptor 		0,		TopOfStack,			DA_DRWA+DA_32	;Stack , 32bit
LABEL_DESC_TEST:	Descriptor 	0500000h,	0ffffh,				DA_DRW
LABEL_DESC_VIDEO:	Descriptor	0B8000h,	0ffffh,				DA_DRW	; Video Memory
;gdt end

GdtLen		equ	$ - LABEL_GDT	;gdt length
GdtPtr		dw 	GdtLen - 1 	;gdt limit
			dd 	0 		;gdt base addr
						;6 bytes

;GDT selector
SelectorNormal	 	equ	LABEL_DESC_NORMAL	-LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32 	- LABEL_GDT
SelectorCode16	 	equ LABEL_DESC_CODE16	-LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA 	-LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK 	-LABEL_GDT
SelectorTest		equ	LABEL_DESC_TEST 	-LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO 	- LABEL_GDT
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
	mov 	ss, ax

	mov	sp, [SPValueInRealMode]

	;turn off the A20  Address Line
	in 	al,92h
	and 	al, 11111101b
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
	mov	ax,SelectorTest
	mov	es,ax
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

	call	TestRead
	call	TestWrite
	call	TestRead

	jmp	SelectorCode16:0

;---------------------------------------------------------------------------------------------------------------
TestRead:
	xor	esi, esi
	mov	ecx, 8

.loop:
	mov	al, [es:esi]
	call	DispAL
	inc 	esi
	loop	.loop
	call	DispReturn
	ret 
;------------------------------------------------------------------------------------------------------------------

;------------------------------------------------------------------------------------------------------------------
TestWrite:
	push	esi
	push	edi
	xor	esi,esi
	xor	edi,edi
	mov	esi,OffsetStrTest
	cld
.1:
	lodsb
	test 	al,al 
	jz	.2
	mov	[es:edi], al 
	inc 	edi 
	jmp 	.1
.2:
	pop	edi 
	pop	esi

	ret
;-----------------------------------------------------------------------------------------------------------------------

;-----------------------------------------------------------------------------------------------------------------------
;Display the number in AL 
; default:
;	the number is in Al 
;	edi point to the next char
;changed register:
;	ax,edi 
;---------------------------------------------------------------------------------------------------------------------------
DispAL:
	push	ecx
	push	edx

	mov	ah, 0Ch 	;0000: black background      1100:red word
	mov	dl,al 
	shr	al, 4
	mov	ecx, 2
.begin:
	and	al,01111b
	cmp	al, 9
	ja	.1
	add 	al, '0'
	jmp	.2
.1:
	sub	al,0Ah
	add 	al, 'A'
.2:
	mov [gs:edi], ax
	add edi, 2
	
	mov	al,dl 
	loop	.begin
	add 	edi, 2

	pop	edx
	pop	ecx
	ret
;--------------------------------------------------------------------------------------------------------------------------

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