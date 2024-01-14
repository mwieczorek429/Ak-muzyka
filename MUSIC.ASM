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
	xor 	cx,cx
	mov		cl,es:[80h] ;Pod adresem 80h znajduje sie bajt zawierajacy dlugosc parametrow
	cmp cl,0
	JZ NOFILE
	dec 	cl ; pomijamy spacje po .exe
	mov		si,offset fname ;Ustalamy wskaźnik SI na miejsce w pamięci w segmencie danych
	mov		di,82h ;[80]- byte z dlugoscia, [81]-niechciana spacja, [82+]parametr
				
SAVENAME:	;Zapisanie nazwy pliku
	mov		al,es:[di] ;kopiowaie kazdego znaku do data segment
	mov 	ds:[si],al
	inc		si ;Inkrementuj SI - teraz wskazuje na kolejny bajt do którego ma być skopiowany znak
	inc		di ;Inkrementuj DI - teraz wskazuje na kolejny znak do skopiowania
	dec		cl ;Dekrementuj długość stringa
	jnz		SAVENAME ; jezeli zero to znaczy ze przepisalismy caly parametr

INIT:
   xor si,si               ; Wyzerowanie si
   xor di,di
   xor dx,dx
   mov cx,09h              ; Licznik petli
   call INIT_OSC
   call OPENF              ; Otwarcie pliku
   call ON_SPEAK           ; Wlaczenie glosnika
MAIN:
   call READL              ; Wczytanie linii
   cmp ax, 'E'
   jz CLOSE
   mov dl, [lines+2]         ; Wczytanie czasu
   sub dl, 48d
   mov timeH, dx
   mov cl, [lines+1]       ; Wczytanie oktawy
   sub cl, 48d             ; Aby oktawa byla liczba
   mov dl, lines           ; Wczytanie pozycji nuty
   sub dx,48d              ; Aby wczytana wartosc byla liczba
   add dx,dx               ; Aby przesuwalo o slowo
   mov si,dx
   mov bx, [offset notes + si] ; Czestotliwosc nuty w oktawie 0
   shr bx,cl               ; Poprawienie czestotliwosci o oktawe, chcac wieksza czestotliwosc mnozymy przez potege 2
   call CH_FREQ            ; Zmiana czestotliwosci
   call DELAY              ; Czas trwania dzwieku
   jmp main
   
CLOSE:
   call CLOSEF
   call OFF_SPEAK          ; Wylaczenie glosnika

KONIEC:
   mov   ah, 4ch
   mov   al, 0
   int   21h
NOFILE:
	mov  ah,09h
	mov dx,offset empty
	int 21h
	jmp KONIEC

;Do Testowania
LOG:
   pop dx
   pop bx
   push dx
   mov dx, bx
   mov ah, 02h
   int 21h
   ret

BLAD:
   LEA DX,error
   MOV AH,09h
   INT 21h
   JMP KONIEC

ON_SPEAK:
   in al, 61h           ; Pobranie bajtu z glosnika
   or al, 00000011b     ; Ustawienie dwoch najmniej znaczacych bitow, bez zmiany pozostalych
   out 61h, al          ; Wyslanie bajtu do ukladu, aby uruchomic glosnik
   ret

OFF_SPEAK:
   in al, 61h           ; Pobranie bajtu z glosnika
   AND al, 11111100b    ; Ustawienie dwoch najmniej znaczacych bitow, bez zmiany pozostalych
   out 61h, al          ; Wyslanie bajtu do ukladu, aby wylaczyc glosnik
   ret

DELAY:
   mov cx, timeH          ; Opoznienie w mikrosekundach w CX:DX (1000000 = 000f4240h, czyli 1s)
   mov ah, 86h          ; Funkcja wykonuje pusta petle wykonujaca sie CX:DX mikrosekund
   int 15h              ; Przerwania dodatkowe AT
   ret

INIT_OSC:
   mov al, 10110110b    ; Podana liczba inicjalizuje oscylator
   out 43h, al          ; Inicjalizacja oscylatora
   ret

CH_FREQ:
   push ax
   push bx
   mov ax, bx           ; W bx jest zapisany dzielnik
   out 42h, al          
   mov al, ah
   out 42h, al
   pop bx
   pop ax
   ret

;Obsluga pliku
OPENF:
   mov dx, offset Fname        ; Zaladowanie adresu nazwy pliku
   mov al, 0d                  ; Tryb dostepu do pliku (read)
   mov ah, 3dh                 ; Funkcja otwierania pliku
   int 21h
   jc BLAD
   mov handler, ax             ; Przeniesienie numeru dojscia do pliku
   ret

CLOSEF:
   mov bx, handler             ; Numer dojscia do pliku
   mov ah, 3eh                 ; Funkcja zamnkniecia pliku
   int 21h
   jc BLAD
   ret

READL:
   mov cx, 4d                   ; Liczba bajtow do przeczytania
   mov dx, offset lines        ; Adres do ktorego beda wczytywane dane
   mov bx, handler             ; Numer dojscia do pliku
   mov ah, 3fh                 ; Funkcja do wczytania cx bajtow do DS:DX
   int 21h
   jc BLAD
   cmp ax,0d                   ; Jesli nie wczytano bajtow, koniec pliku
   jz EOF                      
   mov ax, 'N'                 ; Jesli nie ma konca pliku ustaw ax na 'N'ext
   ret
EOF:
   mov ax, 'E'                 ; Koniec pliku ustaw ax na 'E'nd of file
   ret


_code ends

_data segment
   ; your data goes here
   adr dw 1000h
   error db 'BLAD',13,10,'$'
   timeH  dw 0003h
   notes  dw (1193180/33)      ; Nota C
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
   handler dw ?
   fname db 80h dup(0),'$'
   lines db 4 dup(?)
   empty db 'Nie podano nazwy pliku',13,10,'$'
   
_data ends

_stack segment stack
   top_stack   equ 100h
_stack ends

end start


; Aby uzyskac odpowiednia note, trzeba wyslac do ukladu 8253? dzielnik, ktory poprzez podzielenie czestotliwosci 1,193180 GHZ, wykonuje akcje w czestotliwosci wskazanej noty.
; Np: Aby uzyskac czestotliwosc nuty C (33Hz), trzeba wyslac: (1193180/33) = 36156 do ukladu 8253. FORMULA: 1193180 / CZESTOTLIWOSC_NUTY
; Plik ma w kazdym wierszu format: NUTA:OKTAWA:CZAS np: 442 -> Nuta F5,130ms
