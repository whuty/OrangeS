	;============================
;pmtest1.asm
;nasm pmtest1.asm -o pmtest.bin
;if debug in dos
;nasm pmtest1.asm -o pmtest1.com
;sudo mount -o loop pm.img /mnt/floppy
;sudo cp pmtest1.com /mnt/floppy/
;sudo umount /mnt/floppy
;%define _BOOT_DEBUG_
;============================

%include	"pm.inc"

%define _BOOT_DEBUG_
%ifdef _BOOT_DEBUG_
org	0100h
%else
org 	07c00h		;the program is loaded at 7c00
%endif
	jmp	LABEL_BEGIN

;gdt   Global Descriptor Table
[SECTION	.gdt]
;gdt
;			Descriptor is defined in pm.inc
;					segment 	segment		Attribute
;					base addr	limit
LABEL_GDT:		Descriptor		0,	0,			0		; null Descriptor
LABEL_DESC_CODE32:	Descriptor		0,	SegCode32Len - 1,	DA_C+DA_32	; not Conforming Code Segment
LABEL_DESC_VIDEO:	Descriptor	0B8000h,	0ffffh,			DA_DRW	; Video Memory
;gdt end

GdtLen		equ	$ - LABEL_GDT	;gdt length
GdtPtr		dw 	GdtLen - 1 	;gdt limit
			dd 	0 			;gdt base addr
							;6 bytes

;GDT selector
SelectorCode32		equ	LABEL_DESC_CODE32 	- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO 	- LABEL_GDT
; END of [SECTION  .gdt]

[SECTION  .s16]
[BITS	16]
LABEL_BEGIN:
	mov	ax,  cs
	mov	ds,  ax
	mov	es,  ax
	mov	ss,  ax
	mov	sp,  0100h

	; initialize the 32 bits code segment Descriptor
	xor	eax,  eax				;clear  eax
	mov	ax,  cs
	shl	eax,  4					;Physical Address = Segment * 16 + Offset
	add	eax,LABEL_SEG_CODE32			;the Physical Address of  LABEL_SEG_CODE32
	mov	word  [LABEL_DESC_CODE32 + 2] ,  ax
	shr	eax,  16
	mov	byte [LABEL_DESC_CODE32 + 4] ,  al
	mov	byte [LABEL_DESC_CODE32 + 7] ,  ah	;let the Physical Address be the segment base addr

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

	; turn on th A20  Address Line
	in 	al,92h
	or 	al,00000010b
	out	92h,al

	;prepare for protect mode
	;the 0bit of register cr0 is  PE .When PE=0, CPU is in real mode ,when 1 , protect mode
	mov	eax,cr0
	or 	eax,1
	mov	cr0,eax

	jmp 	dword  SelectorCode32:0
;END of [SECTION  .s16]

[SECTION  .s32]
[BITS	32]

LABEL_SEG_CODE32:
	mov	ax,SelectorVideo
	mov	gs, ax

	mov	edi, (80*11+79) * 2	;the 11th row,79th column of the screen
	mov	ah,0ch 			;0000 black background,1100  red word
	mov	al,'p'
	mov	[gs:edi],ax

	jmp	$
SegCode32Len 		equ	$ - LABEL_SEG_CODE32
;END of [SECTION  .s32]