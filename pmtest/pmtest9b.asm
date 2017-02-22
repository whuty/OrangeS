%include	"pm.inc"

PageDirBase0 	equ 200000h
PageTblBase0	equ 201000h
PageDirBase1	equ 210000h
PageTblBase1	equ 211000h

LinearAddrDemo 	equ 00401000h
ProcFoo 		equ 00401000h

ProcBar 		equ 00501000h
ProcPagingDemo	equ 00301000h

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

LABEL_DESC_FLAT_C:	Descriptor 		0,		0fffffh,			DA_CR|DA_32|DA_LIMIT_4K
LABEL_DESC_FLAT_RW:	Descriptor		0,		0fffffh,			DA_DRW|DA_LIMIT_4K ;0~4G

LABEL_DESC_CODE32:	Descriptor		0,		SegCode32Len - 1,	DA_CR|DA_32	; not Conforming Code Segment , 32bit
LABEL_DESC_CODE16:	Descriptor		0,		0ffffh,				DA_C		; not Conforming Code Segment , 16bit
LABEL_DESC_DATA:	Descriptor 		0,		DataLen - 1,		DA_DRW	;Data
LABEL_DESC_STACK:	Descriptor 		0,		TopOfStack,			DA_DRWA|DA_32	;Stack , 32bit
LABEL_DESC_VIDEO:	Descriptor	0B8000h,	0ffffh,				DA_DRW	; Video Memory

;gdt end

GdtLen		equ	$ - LABEL_GDT	;gdt length
GdtPtr		dw 	GdtLen - 1 	;gdt limit
			dd 	0 		;gdt base addr
						;6 bytes

;GDT selector
SelectorNormal	 	equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32 	- LABEL_GDT
SelectorCode16	 	equ LABEL_DESC_CODE16	- LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA 	- LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK 	- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO 	- LABEL_GDT

SelectorFlatC 		equ LABEL_DESC_FLAT_C 	- LABEL_GDT
SelectorFlatRW 		equ LABEL_DESC_FLAT_RW 	- LABEL_GDT
; END of [SECTION  .gdt]

[SECTION  .data1]
ALIGN	32
[BITS 	32]
LABEL_DATA:
;symbol in real mode 
;String
_szPMMessage:		db "In protect Mode now .",0 	;display in protect mode
_szMemChkTitle:		db "BaseAddrL BaseAddrH LengthLow LengthHigh  Type",0Ah,0 	;
_szRAMSize 			db "RAM size:",0
;parameters
_wSPValueInRealMode dw 0
_dwMCRNumber: 		dd 0 	;Memory Check Result
_dwDispPos:			dd (80*1 + 0)*2
_dwMemSize:			dd 0
_ARDStruct:					;Address Range Descriptor Structure
	_dwBaseAddrLow: dd 0
	_dwBaseAddrHigh: dd 0
	_dwLengthLow:	dd 0
	_dwLengthHigh:	dd 0
	_dwType:		dd 0
_PageTableNumber 	dd 0

_MemChkBuf:		times 256 db 0

;symbol in protect mode
szPMMessage 	equ _szPMMessage - $$
szMemChkTitle 	equ _szMemChkTitle - $$
szRAMSize 		equ _szRAMSize - $$
dwDispPos 		equ _dwDispPos - $$
dwMemSize 		equ _dwMemSize - $$
dwMCRNumber 		equ _dwMCRNumber - $$
ARDStruct 		equ _ARDStruct - $$
	dwBaseAddrLow: equ _dwBaseAddrLow - $$
	dwBaseAddrHigh: equ _dwBaseAddrHigh - $$
	dwLengthLow:	equ _dwLengthLow - $$
	dwLengthHigh:	equ _dwLengthHigh - $$
	dwType:		equ _dwType - $$
PageTableNumber equ _PageTableNumber - $$
MemChkBuf 		equ _MemChkBuf - $$

DataLen 		equ	$ - LABEL_DATA
;END of SECTION .data1

[SECTION .idt]
ALIGN 32
[BITS 32]
LABEL_IDT:
;gate
%rep 255
Gate SelectorCode32,SpuriousHandler,0,DA_386IGate
%endrep


IdtLen 	equ $ - LABEL_IDT
IdtPtr  dw IdtLen - 1
		dd 0
;END of [SECTION .idt]

[SECTION  .gs]
ALIGN 	32
[BITS	32]
LABEL_STACK:
		times 512 db 0
TopOfStack 	equ	$ - LABEL_STACK - 1
;END of SECTION .gs

[SECTION  .s16]
ALIGN 	16
[BITS	16]
LABEL_BEGIN:
	mov	ax,  cs
	mov	ds,  ax
	mov	es,  ax
	mov	ss,  ax
	mov	sp,  0100h

	mov	[LABEL_GO_BACK_TO_REAL + 3], ax
	mov	[_wSPValueInRealMode] , sp

	;get the number of Memory
	mov ebx,0
	mov di,_MemChkBuf
.loop:
	mov eax,0E820h
	mov ecx,20
	mov edx,0534D4150h
	int 15h
	jc LABEL_MEM_CHK_FAIL
	add di,20
	inc dword [_dwMCRNumber]
	cmp ebx,0
	jne .loop
	jmp LABEL_MEM_CHK_OK
LABEL_MEM_CHK_FAIL:
	mov dword [_dwMCRNumber],0
LABEL_MEM_CHK_OK:
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

	;prepare for IDTR
	xor eax,eax
	mov ax,ds
	shl eax,4
	add eax,LABEL_IDT
	mov dword [IdtPtr + 2],eax

	;loading GDTR
	lgdt 	[GdtPtr]

	;clear interrupt
	;the manage of interrupt in protect mode is different
	cli

	lidt [IdtPtr]

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
	mov	ss, ax

	mov	sp, [_wSPValueInRealMode]

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
ALIGN 	32
[BITS	32]

LABEL_SEG_CODE32:
	mov	ax,SelectorData
	mov	ds, ax
	mov	es,ax
	mov	ax,SelectorVideo
	mov	gs,ax

	mov	ax,SelectorStack
	mov	ss,ax

	mov	esp,TopOfStack

	call Init8259A
	int 080h

	push szPMMessage
	call DispStr
	add esp ,4
	call DispReturn

	push szMemChkTitle
	call DispStr
	add esp ,4
	call DispReturn

	call DispMemSize 	;display the info of Memory
	call PagingDemo


	jmp	SelectorCode16:0

;Init 8259A
Init8259A:
	mov al,011h
	out 020h,al 	;master 8259A,ICW1
	call io_delay

	out 0Ah,al 		;slave ,ICW1
	call io_delay

	mov al,020h 	;IRQ0 0x20
	out 021h,al 	;master 8259A,ICW2
	call io_delay
	mov al,028h 	;IRQ8 0x28
	out 0A1h,al 	;slave ,ICW2
	call io_delay

	mov al,001h
	out 021h,al 
	call io_delay
	out 0Ah,al 
	call io_delay

	mov al, 11111110b ;only open the clock interrupt
	;mov al,11111111b ;
	out 021h,al 	;master ,OCW1
	call io_delay

	mov al,11111111b  ;disable all interrupt form slave 8259
	out 0A1h,al
	call io_delay

	ret

io_delay:
	nop
	nop
	nop
	nop
	ret

_SpuriousHandler:
SpuriousHandler equ _SpuriousHandler - $$
	mov ah,0Ch
	mov al,'!'
	mov [gs:((80*12+75)*2)],ax
	jmp $
	iretd

;-----------------------------------------------------
SetupPaging:
	;calculate how many PDE and page table should be initialize
	xor edx,edx
	mov eax,[dwMemSize]
	mov ebx,400000h ;400000h = 4M ,one page talbe
	div ebx
	mov ecx,eax 	;here ecx in the number of page table ,and also the number or PDE
	test edx,edx
	jz .no_remainder
	inc ecx
.no_remainder:
	mov [PageTableNumber],ecx
	;push the number
	;to simplify,all linear address correspond to the eual Physical address,and Memory hole is not considered

	;first initialize page dir 
	mov ax,SelectorFlatRW
	mov es,ax
	mov edi,PageDirBase0
	xor eax,eax
	mov eax,PageTblBase0|PG_P|PG_USU|PG_RWW
.1:
	stosd
	add eax,4096
	loop 	.1

	;initialize all page table
	mov eax,[PageTableNumber]
	mov ebx,1024
	mul ebx
	mov ecx,eax ;number of PTE = number of pagetable * 1024

	mov edi,PageTblBase0
	xor eax,eax
	mov eax,PG_P|PG_USU|PG_RWW
.2:
	stosd
	add eax,4096
	loop 	.2

	mov eax,PageDirBase0
	mov cr3,eax
	mov eax,cr0
	or eax,80000000h
	mov cr0,eax
	jmp short .3
.3:
	nop

	ret
;-----------------------------------------------------

;test paging
PagingDemo:
	mov ax,cs
	mov ds,ax
	mov ax,SelectorFlatRW
	mov es,ax

	push LenFoo
	push OffsetFoo
	push ProcFoo
	call MemCpy
	add esp,12

	push LenBar
	push OffsetBar
	push ProcBar
	call MemCpy
	add esp,12

	push LenPagingDemoAll
	push OffsetPagingDemoProc
	push ProcPagingDemo
	call MemCpy
	add esp,12

	mov ax,SelectorData
	mov ds,ax
	mov es,ax

	call SetupPaging

	call SelectorFlatC:ProcPagingDemo
	call PSwitch 	;switch pagedir 
	call SelectorFlatC:ProcPagingDemo

	ret
;-------------------------------------------------

PSwitch:
	mov ax,SelectorFlatRW
	mov es,ax
	mov edi,PageDirBase1
	xor eax,eax
	mov eax,PageTblBase1|PG_P|PG_USU|PG_RWW
	mov ecx,[PageTableNumber]
.1:
	stosd
	add eax,4096
	loop 	.1

	mov eax,[PageTableNumber]
	mov ebx,1024
	mul ebx
	mov ecx,eax
	mov edi,PageTblBase1
	xor eax,eax
	mov eax,PG_P|PG_USU|PG_RWW
.2:
	stosd
	add eax,4096
	loop 	.2

	;assumed that Memory is more than 8M
	mov eax,LinearAddrDemo
	shr eax,22
	mov ebx,4096
	mul ebx
	mov ecx,eax
	mov eax,LinearAddrDemo
	shr eax,12
	and eax,03FFh 	;11 1111 1111b(10bits)
	mov ebx,4
	mul ebx
	add eax,ecx
	add eax,PageTblBase1
	mov dword [es:eax],ProcBar|PG_P|PG_USU|PG_RWW

	mov eax,PageDirBase1
	mov cr3,eax
	jmp short .3
.3:
	nop

	ret
;----------------------------------------------------------

PagingDemoProc:
OffsetPagingDemoProc 	equ PagingDemoProc - $$
	mov eax,LinearAddrDemo
	call eax
	retf
LenPagingDemoAll 	equ $ - PagingDemoProc

foo:
OffsetFoo 		equ foo - $$
	mov ah,0Ch 
	mov al,'F'
	mov [gs:((80*15+0)*2)],ax
	mov al,'o'
	mov [gs:((80*15+1)*2)],ax
	mov [gs:((80*15+2)*2)],ax
	ret 
LenFoo 			equ $ - foo

bar:
OffsetBar 		equ bar - $$
	mov ah,0Ch
	mov al,'B'
	mov [gs:((80*16+0)*2)],ax
	mov al,'a'
	mov [gs:((80*16+1)*2)],ax
	mov al,'r'
	mov [gs:((80*16+2)*2)],ax
	ret
LenBar 			equ $ - bar 

;-----------------------------------------------------------
DispMemSize:
	push esi
	push edi
	push ecx

	mov esi,MemChkBuf
	mov ecx,[dwMCRNumber]	;for(int i=0;i<[MCRNumber];i++)
.loop:						;{
	mov edx,5 				;	for(int j=0;i<5;j++)
	mov edi,ARDStruct 		;	{//display BaseAddrLow,BaseAddrHigh,LengthLow,LengthHigh,Type in turn
.1:
	push dword [esi] 		;
	call DispInt 			;		DispInt(MemChkBuf[j*4]);
	pop eax
	stosd 					;		ARDStruct[j*4]=MemChkBuf[j*4];
	add esi, 4 				;
	dec edx
	cmp edx,0
	jnz .1 					;	}
	call DispReturn 		;	printf("\n");
	cmp dword [dwType],1 	;	if(Type == AddressRangeMemory)
	jne .2 					;	{
	mov eax,[dwBaseAddrLow] ;
	add eax,[dwLengthLow]
	cmp eax,[dwMemSize] 	;		if(BaseAddrLow+LengthLow>MemSize)
	jb .2 					;
	mov [dwMemSize], eax	;		MemSize=BaseAddrLow+LengthLow
.2:
	loop .loop 				;	}
							;}
	call DispReturn			;printf("\n");
	push szRAMSize
	call DispStr			;printf("RAM size:");
	add esp, 4

	push dword [dwMemSize]  ;DispInt(MemSize);
	call DispInt
	add esp ,4 				;

	pop ecx
	pop edi
	pop esi
	ret

%include "lib.inc"

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
	and	eax,7FFFFFFEh 	;PE=0,PG=0
	mov	cr0,eax
LABEL_GO_BACK_TO_REAL:
	jmp	0:LABEL_REAL_ENTRY	;
Code16Len	equ	$ - LABEL_SEG_CODE16
;END of [SECTION  .s16code]