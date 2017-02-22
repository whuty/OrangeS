;define _BOOT_DEBUG_
%ifdef _BOOT_DEBUG_
org	0100h
%else
org 	07c00h		;the program is loaded at 7c00
%endif

%ifdef	_BOOT_DEBUG_
BaseOfStack		equ	0100h	;Debug mode
%else
BaseOfStack		equ	07c00h	;base of stack
%endif

BaseOfLoader 	equ 09000h
OffsetOfLoader 	equ 0100h

;=====================================================================

jmp short LABEL_START	;start to boot
nop 					;necessary

%include "fat12hdr.inc"

LABEL_START:
	mov 	ax,cs		;cs,code segment
	mov		ds,ax		;ds,data segment
	mov		es,ax		;es,extra segment
					;let ds, es , in the same segment with cs
	;call	DispStr
	;jmp		$			;loop
;DispStr:
	;mov		ax,BootMessage
	;mov		bp,ax		;ES:BP = address of the string
	;mov		cx,16		;CX = the length of string
	;mov		ax,01301h	;AH=13,AL=01h
	;mov		bx,000ch	;page num = 0(BH=0),red word with black backgroud (BL=0ch, highlight)
	;mov		dl,0
	;int		10h
	;ret
;BootMessage:		db	"hello,OS World"
	;times	510-($-$$)	db	0 			;fill the remaining space to the number of the binary code reach 510 bytes , add with 0xaa55,512 bytes
	;dw		0xaa55

	mov	ss, ax
	mov	sp, BaseOfStack

	;clear sceen
	mov ax,0600h	;AH=6h,AL=0h
	mov bx,0700h 	;black backgroud,white word
	mov cx,0 		;(0,0)
	mov dx,0184fh	;(80,50)
	int 10h

	mov dh,0
	call DispStr 	;"Booting   "

	xor	ah, ah
	xor	dl, dl
	int	13h

;search Loader.bin in a://
	mov word [wSectorNo],SectorNoOfRootDir
LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
	cmp word [wRootDirSizeForLoop],0
	jz LABEL_NO_LOADERBIN
	dec word [wRootDirSizeForLoop]
	mov ax,BaseOfLoader
	mov es,ax
	mov bx,OffsetOfLoader
	mov ax,[wSectorNo]
	mov cl,1
	call ReadSector

	mov si,LoaderFileName ;ds:si -> "LOADER BIN"
	mov di,OffsetOfLoader ;es:di -> BaseOfLoader:0100
	cld
	mov dx,10h
LABEL_SEARCH_FOR_LOADERBIN:
	cmp dx,0
	jz LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR
	dec dx
	mov cx,11
LABEL_CMP_FILENAME:
	cmp cx,0
	jz LABEL_FILENAME_FOUND
	dec cx
	lodsb
	cmp al,byte [es:di]
	jz LABEL_GO_ON
	jmp LABEL_DIFFERENT
LABEL_GO_ON:
	inc di
	jmp LABEL_CMP_FILENAME
LABEL_DIFFERENT:
	and di,0FFE0h
	add di,20h
	mov si,LoaderFileName;
	jmp LABEL_SEARCH_FOR_LOADERBIN
LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
	add word [wSectorNo],1
	jmp LABEL_SEARCH_IN_ROOT_DIR_BEGIN

LABEL_NO_LOADERBIN:
	mov dh,2
	call DispStr

%ifdef _BOOT_DEBUG_
	mov ax,4c00h
	int 21h 	;can't find,back to DOS
%else
	jmp $
%endif

LABEL_FILENAME_FOUND:
	;this time,es:di ->the end of filename
	mov ax,RootDirSectors
	and di,0FFE0h ;di->the start of current filename 
	add di,01Ah   ;di->DIR_FstClus
	mov cx,word [es:di]
	push cx  	;save the num of sector in FAT
	add cx,ax
	add cx,DeltaSectorNo
	mov ax,BaseOfLoader
	mov es,ax 	;es<-BaseOfLoader
	mov bx,OffsetOfLoader
	mov ax,cx 	;ax<- Sector num

LABEL_GOON_LOADING_FILE:
	push ax
	push bx
	mov ah,0eh
	mov al,'.'
	mov bl,0fh
	int 10h
	pop bx
	pop ax

	mov cl,1
	;from the ax th sector ,read cl=1 sector to es:bx=BaseOfLoader:OffsetOfLoader
	call ReadSector
	pop ax
	call GetFATEntry
	cmp ax,0fffh
	jz LABEL_FILE_LOADED
	push ax
	mov dx,RootDirSectors
	add ax,dx
	add ax,DeltaSectorNo
	add bx,[BPB_BytsPerSec]
	jmp LABEL_GOON_LOADING_FILE

LABEL_FILE_LOADED:
	mov dh,1
	call DispStr
;****************************
	jmp BaseOfLoader:OffsetOfLoader
;***************************

;===============================================
wRootDirSizeForLoop dw RootDirSectors
wSectorNo dw 0
bOdd db 0

LoaderFileName db "LOADER  BIN",0
;in order to simplify,the Length of message is MessageLength
MessageLength equ 9
BootMessage db "Booting  "
Message1 db "Ready.   "
Message2 db "No Loader"

;DispStr
;display a string,dh is the number of string(0-based)
DispStr:
	mov ax,MessageLength
	mul dh
	add ax,BootMessage
	mov bp,ax
	mov ax,ds
	mov es,ax
	mov cx,MessageLength
	mov ax,01301h 		;AH=13h,AL=01h
	mov bx,0007h		;BH=0,BL=07h,black backgroud,white word
	mov dl,0
	int 10h
	ret

;ReadSector
;from the ax th Sector,read cl Sector to es:bx
ReadSector:
;the number of sector is x
    ;                      	    ┌ 柱面号 = y >> 1
	;       x           ┌ 商 y ┤
	; -------------- => ┤      └ 磁头号 = y & 1
	;  SecPerTrk        │
	;                   └ 余 z => 起始扇区号 = z + 1
	push bp
	mov bp,sp
	sub esp,2
	mov byte [bp-2],cl
	push bx
	mov bl,[BPB_SecPerTrk]
	div bl
	inc ah
	mov cl,ah
	mov dh,al
	shr al,1
	mov ch,al
	and dh,1
	pop bx

	mov dl,[BS_DrvNum]
.GoOnReading:
	mov ah,2
	mov al,byte [bp-2]
	int 13h
	jc .GoOnReading

	add esp,2
	pop bp

	ret

;-------------------------------------------------------------
;GetFATEntry
;get the FATNo of Sector with num ax,the result save in ax
;read the sector in FAT to es:bx
GetFATEntry:
	push es
	push bx
	push ax
	mov ax,BaseOfLoader
	sub ax,0100h
	mov es,ax
	pop ax
	mov byte [bOdd],0
	mov bx,3
	mul bx
	mov bx,2
	div bx
	cmp dx,0
	jz LABEL_EVEN
	mov byte [bOdd],1
LABEL_EVEN:
	xor dx,dx
	mov bx,[BPB_BytsPerSec]
	div bx
	push dx
	mov bx,0
	add ax,SectorNoOfFAT1
	mov cl,2
	call ReadSector
	pop dx
	add bx,dx
	mov ax,[es:bx]
	cmp byte [bOdd],1
	jnz LABEL_EVEN_2
	shr ax,4
LABEL_EVEN_2:
	and ax,0fffh
LABEL_GET_FAT_ENRY_OK:
	pop bx
	pop es
	ret
;-------------------------------------

times 510-($-$$) db 0
dw 0xaa55