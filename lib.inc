;;lib.inc

;-------------------------------------------------------
;Display the number in AL 
; default:
;	the number is in Al 
;	the position to display is in [dwDispPos]
;changed register:
;	ax [dwDispPos]
;--------------------------------------------------------
DispAL:
	push	ecx
	push	edx
	push 	edi

	mov edi,[dwDispPos]
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
	;add 	edi, 2

	mov [dwDispPos],edi

	pop edi
	pop	edx
	pop	ecx
	ret
;--------------------------------------------------------

;--------------------------------------------------------
;;display an int
;default:
;		the number to display is on the top of the stack
;		the position to display is in [dwDispPos]
;changed register:
;	eax
;--------------------------------------------------------
DispInt:
	mov eax,[esp+4]
	shr eax,24
	call DispAL

	mov eax,[esp+4]
	shr eax,16
	call DispAL

	mov eax,[esp+4]
	shr eax,8
	call DispAL

	mov eax,[esp+4]
	call DispAL

	mov ah,0Ch 	;0000: black background      1100:red word
	mov al,'h'
	push edi
	mov edi,[dwDispPos]
	mov [gs:edi], ax
	add edi,4
	mov [dwDispPos],edi
	pop edi

	ret
;---------------------------------------------------

;---------------------------------------------------
;display a string
;
;---------------------------------------------------
DispStr:
	push ebp
	mov ebp,esp
	push ebx
	push esi
	push edi

	mov esi,[ebp + 8]	;pszInfo
	mov edi,[dwDispPos]
	mov ah,0Ch
.1:
	lodsb
	test al,al
	jz .2
	cmp al,0Ah; is it Enter?
	jnz .3
	call DispReturn
	jmp .1
.3:
	mov [gs:edi],ax
	add edi,2
	jmp .1
.2:
	mov [dwDispPos],edi

	pop edi
	pop esi
	pop ebx
	pop ebp
	ret
;-------------------------------------------------------

;----------------------------------
DispReturn:
	push 	eax
	push	ebx
	push	edi
	mov edi,[dwDispPos]
	mov	eax, edi
	mov	bl, 160
	div 	bl
	and	eax, 0FFh 
	inc 	eax
	mov 	bl, 160
	mul	bl
	mov	edi, eax
	mov [dwDispPos],edi
;set edi to next Line
	pop edi
	pop	ebx
	pop	eax

	ret 
;----------------------------------

;---------------------------------------------------
;MemCpy
;before call MemCpy
;push iSize
;push pSrc
;push pDest
;void* MemCpy(void* es:pDest,void* ds:pSrc,int iSize);
;----------------------------------------------------
MemCpy:
	push ebp
	mov ebp,esp

	push esi
	push edi
	push ecx
	mov edi,[ebp + 8] 	;Destination
	mov esi,[ebp + 12] 	;Source
	mov ecx,[ebp + 16] 	;Counter
.1:
	cmp ecx,0
	jz .2

	mov al,[ds:esi]
	inc esi

	mov byte [es:edi],al 
	inc edi

	dec ecx
	jmp .1
.2:
	mov eax,[ebp + 8]

	pop ecx
	pop edi
	pop esi
	mov esp,ebp
	pop ebp

	ret
;----------------------------------------------------