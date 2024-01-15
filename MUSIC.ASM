_code segment
   assume  cs:_code

start:   mov   ax, _data
   mov   ds, ax
   assume   ds:_data
   mov   ax, _stack
   mov   ss, ax
   assume   ss:_stack
   mov   sp, top_stack
   
   
GETFILE:
	xor cx,cx
	mov cl,es:[80h]         ; POD ADRESEM 80h ZNAJDUJE SIE BAJT ZAWIERAJACY DLUGOSC PARAMETROW
	cmp cl,0                ; SPRAWDZENIE CZY PODANO SCIEZKE DO PLIKU
	JZ NOFILE
	dec cl                  ; POMIJAMY SPACJE PO .EXE
	mov si,offset fname     ; USTALAMY WSKAZNIK SI NA MIEJSCE W PAMIECI W SEGMENCIE DANYCH DO KTOREGO BEDZIE ZAPISYWANA SCIEZKA PLIKU  
	mov di,82h              ; [80]- BYTE Z DLUGOSCIA, [81]-NIECHCIANA SPACJA, [82+]-PARAMETR
				
SAVENAME:	               ; ZAPISANIE NAZWY PLIKU
	mov		al,es:[di]     ; KOPIOWANIE KAZDEGO ZNAKU PARAMETRU DO PRZEMIESZCZENIA FNAME W DATA SEGMENT 
	mov 	ds:[si],al
	inc		si             ; INKREMENTUJ SI - TERAZ WSKAZUJE NA KOLEJNY BAJT DO KTOREGO MA BYC SKOPIOWANY ZNAK  
	inc		di             ; INKREMENTUJ DI - TERAZ WSKAZUJE NA KOLEJNY ZNAK DO SKOPIOWANIA 
	dec		cl             ; DEKREMENTUJ DLUGOSC STRINGA 
	jnz		SAVENAME       ; JEZELI ZERO TO ZNACZY ZE PRZEPISALISMY CALY PARAMETR 

INIT:
   xor si,si               ; WYZEROWANIE SI, DI i DX
   xor di,di
   xor dx,dx
   call INIT_CHIP          ; INICJALIZACJA UKLADU 8253
   call OPENF              ; OTWARCIE PLIKU
   call ON_SPEAK           ; WLACZENIE GLOSNIKA
MAIN:
   call READL              ; WCZYTANIE LINII POD ADRES LINES, CZYLI 4 ZNAKOW: NUTA,OKTAWA,CZAS,ENTER 
   cmp ax, 'E'             ; KONIEC PLIKU JEST OZNACZONE JAKO 'E' W AX
   jz CLOSE                ; ZAKONCZ WYKONYWANIE PETLI
   mov dl, [lines+2]       ; PRZESLANIE CZASU 
   sub dl, 48d             ; ZAPISANY JEST KOD ASCII, WIEC TRZEBA ODJAC 48
   mov timeH, dx           ; PRZESLANIE WCZYTANEGO CZASU POD ADRES TIMEH, KTORY JEST WYKORZYSTANY W DELAY
   mov cl, [lines+1]       ; PRZESLANIE OKTAWY
   sub cl, 48d             ; ZAMIANA NA LICZBE
   mov dl, [lines]         ; PRZESLANIE POZYCJI NUTY
   sub dx,48d              ; ZAMIANA NA LICZBE
   add dx,dx               ; ABY PRZESUWALO O SLOWO
   mov si,dx                
   mov bx, [notes + si]    ; CZESTOTLIWOSC NUTY W OKTAWIE 0
   shr bx,cl               ; POPRAWIENIE CZESTOTLIWOSCI O OKTAWE, ABY BYLA WIEKSZA CZESTOTLIWOSC MNOZYMY PRZEZ POTEGE 2
   call CH_FREQ            ; WYWOLANIE ZMIANY CZESTOTLIWOSCI
   call DELAY              ; ODCZEKAJ O WCZESNIEJ WCZYTANY CZAS
   jmp main                ; POWTARZANIE ODGRYWANIA TONU AZ NASTAPI KONIEC WCZYTYWANIA PLIKU
   
CLOSE:
   call CLOSEF             ; ZAMKNIECIE PLIKU
   call OFF_SPEAK          ; WYLACZENIE GLOSNIKA

KONIEC:
   mov   ah, 4ch
   mov   al, 0
   int   21h

NOFILE:                    ; WYSWIETLENIE INFORMACJI O BRAKU PODANIU NAZWY PLIKU 
	mov  ah,09h         
	mov dx,offset empty
	int 21h
	jmp KONIEC

BLAD:                      
   LEA DX,error
   MOV AH,09h
   INT 21h
   JMP KONIEC

ON_SPEAK:
   in al, 61h              ; POBRANIE BAJTU Z UKLADU, ABY NIE ZMIENIAC BITOW ODPOWIEDZIALNYCH ZA INNE RZECZY
   or al, 00000011b        ; USTAWIENIE DWOCH NAJMLODSZYCH BITOW ODPOWIEDZIALNYCH ZA WLACZENIE GLOSNIKA(GATE2 I SPEAKER DATA), BEZ ZMIANY POZOSTALYCH
   out 61h, al             ; WYSLANIE ZMIENIONEGO BAJTU DO UKLADU, CO SPOWODUJE URUCHOMIENIE GLOSNIKA
   ret

OFF_SPEAK:
   in al, 61h              ; POBRANIE BAJTU Z UKLADU
   AND al, 11111100b       ; USTAWIENIE DWOCH NAJMLODSZYCH BITOW ODPOWIEDZIALNYCH ZA WLACZENIE GLOSNIKA, BEZ ZMIANY POZOSTALYCH
   out 61h, al             ; WYSLANIE BAJTU DO UKLADU, ABY WYLACZYC GLOSNIK 
   ret

DELAY:
   mov cx, timeH           ; OPOZNIENIE W MIKROSEKUNDACH CX:DX (np. 1000000 = 000f4240h, czyli 1s), MY ZMIENIAMY TYLKO CX O WIELOKROTNOSCI 65ms
   mov ah, 86h             ; FUNKCJA WYKONUJE PUSTA PETLE WYKONUJACA SIE CX:DX MIKROSEKUND 
   int 15h                 ; PRZERWANIE DODATKOWE AT
   ret

INIT_CHIP:
   mov al, 10110110b       ; ZAPISANIE BAJTU STERUJACEGO: B7-6 KANAL 2, B5-4 WCZYTANIE NAJMLODSZY NAJSTARSZY BAJT, B3-1 GENERATOR FALI PROSTOKATNEJ, B0 ZLICZANIE BINARNE
   out 43h, al             ; PRZESLANIE BAJTU STERUJACEGO DO REJESTRU STERUJACEGO 8253
   ret

CH_FREQ:
   mov ax, bx              ; W BX JEST ZAPISANY DZIELNIK 
   out 42h, al             ; PRZESLANIE DZIELNIKA DO LICZNIKA CZESTOTLIWOSCI, NAJPIERW MLODSZY BAJT
   mov al, ah              ; NASTEPNIE STARSZY BAJT (OUT DZIALA Z REJESTREM AL LUB AX)
   out 42h, al             
   ret

;OBSLUGA PLIKU 
OPENF:
   mov dx, offset Fname        ; PRZESLANIE ADRESU NAZWY PLIKU
   mov al, 0d                  ; TRYB DOSTEPU DO PLIKU (READ)
   mov ah, 3dh                 ; FUNKCJA OTWIERANIA PLIKU
   int 21h
   jc BLAD                     ; USTAWIONA FLAGA C OZNACZA BLAD OTWIERANIA
   mov handler, ax             ; PRZESLANIE NUMERU DOJSCIA DO PLIKU
   ret

CLOSEF:
   mov bx, handler             ; PRZESLANIE NUMERU DOJSCIA DO PLIKU
   mov ah, 3eh                 ; FUNKCJA ZAMKNIECIA PLIKU
   int 21h
   jc BLAD                     ; USTAWIONA FLAGA C OZNACZA BLAD ZAMKNIECIA
   ret

READL:
   mov cx, 4d                  ; USTAWIENIE LICZBY BAJTOW DO PRZECZYTANIA
   mov dx, offset lines        ; PRZESLANIE ADRESU DO KTOREGO BEDA PRZESYLANE WCZYTANE ZNAKI
   mov bx, handler             ; USTAWIENIE ADRESU POD KTORYM ZAPISANY ZOSTANIE NUMER DOJSCIA DO PLIKU
   mov ah, 3fh                 ; FUNKCJA WCZYTUJACA CX BAJTOW DO DS:DX
   int 21h
   jc BLAD                     ; USTAWIONA FLAGA C OZNACZA BLAD WCZYTANIA
   cmp ax,0d                   ; NIE WCZYTANO ZADNYCH ZNAKOW, CZYLI KONIEC PLIKU
   jz EOF                      
   mov ax, 'N'                 ; PRZESLANIE DO AX 'N', ABY WIEDZIEC CZY BYL KONIEC PLIKU
   ret
EOF:
   mov ax, 'E'                 ; PRZESLANIE DO AX 'E', ABY WIEDZIEC ZE NASTAPIL KONIEC PLIKU
   ret


_code ends

_data segment
   ; your data goes here
   adr dw 1000h
   error db 'BLAD',13,10,'$'
   timeH  dw 0003h
   notes  dw (1193180/33)     ; C
         dw (1193180/37)      ; D
         dw (1193180/39)      ; D#
         dw (1193180/41)      ; E
         dw (1193180/44)      ; F
         dw (1193180/46)      ; F#
         dw (1193180/49)      ; G 
         dw (1193180/52)      ; G#
         dw (1193180/55)      ; A
         dw (1193180/62)      ; B

   ;Dane zwiazane z obsluga pliku
   handler dw ?               ; ZAREZERWOWANIE SLOWA, BEZ INCIJALIZACJI 
   fname db 80h dup(0),'$'    ; ZAINICJALIZOWANIE 128 BAJTOW ZERAMI
   lines db 4 dup(?)          ; ZAREZERWOWANIE 4 BAJTOW (DUP, CZYLI DUPLICATE, INACZEJ ? ? ? ?)
   empty db 'Nie podano nazwy pliku',13,10,'$'
   
_data ends

_stack segment stack
   top_stack   equ 100h
_stack ends

end start
