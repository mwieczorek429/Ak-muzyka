_code segment
	assume  cs:_code

start:	mov	ax, _data
	mov	ds, ax
	assume	ds:_data
	mov	ax, _stack
	mov	ss, ax
	assume	ss:_stack
	mov	sp, top_stack

	;mov ah,3dh	; OTWIERANIE
	;mov al,0
	;mov dx, offset plik
	;int 21h
	;jc blad
	
	;mov bx,ax	; ZAPISANIE DO PAMIECI
	;mov ah,3fh
	;mov cx,5
	;mov dx, offset buffor
	;int 21h
	;jc blad
	
	;mov ah,3eh	; ZAMYKANIE PLIKU
	;int 21h
	;jc blad
	
	;mov ah,09h	; WYSWIETLENIE ZAWARTOSCI
	;mov dx,offset buffor
	;int 21h
	
	MOV BP, offset notes
	MOV BX, offset muzyka
	mov si,0
	
	IN AL,61h	; WLACZENIE GLOSNIKA
	OR AL, 00000011b
	OUT 61h, AL

petla:
	MOV DX,
	MOV	AX, []
	SAL AX,7
	OUT 42h, AL
	MOV AL,AH
	OUT 42h,AL
	mov ah,86h
	mov cx,10
	int 15h
	ADD SI,2
	cmp SI,14
	jne petla
	
	IN AL,61h	; WYLACZENIE GLOSNIKA
	AND AL,11111100b
	OUT 61h, AL
	

KONIEC:	
	mov DX, offset tekst
	MOV AH, 09h
	int 21h
	mov	ah, 4ch
	mov	al, 0
	int	21h
BLAD:
	mov DX, offset bladmsg
	MOV AH, 09h
	int 21h
	mov	ah, 4ch
	mov	al, 0
	int	21h
_code ends

_data segment
	tekst db 'dziala',13,10,'$'
	bladmsg db 'blad',13,10,'$'
	plik db 'C:\MUZYKA\PLIK.DAT', 0
	buffor db 10 dup('$')
	notes   dw 440	;A4
			dw 493	;B4
			dw 523	;C5
			dw 587	;D5
			dw 659	;E5
			dw 698	;F5
			dw 783	;G5
_data ends

_stack segment stack
	top_stack	equ 100h
_stack ends

end start