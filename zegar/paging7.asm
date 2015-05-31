.486p
ROZMIAR_BMP EQU 100
CALKOWITA_WIELKOSC_PAMIECI_W_B EQU 100*8*4096

Dane     SEGMENT
NAPIS    DB 'WCISNIJ 1 - REZERWACJA RAMKI, 2 - ZWOLNIENIE PIERWSZEJ ZAJETEJ RAMKI', 13, 10
         DB   'REJESTR EAX BEDZIE ZAWIERAL ADRES FIZYCZNY RAMKI ZAREZERWOWANEJ/ZWOLNIONEJ', 13, 10
         DB   'ADRES 0 JEST ZAREZERWOWANY - OKRESLA BRAK ZAJETYCH LUB WOLNYCH RAMEK$'
BINARNA_MAPA_PAMIECI DB 100 DUP(0)
WARTOWNIK            DD 0
WARTOWNIK2           DD 0FFFFFFFFH
Dane     ENDS

Program     SEGMENT  'CODE' USE16
           assume CS:Program,DS:Dane
MAIN PROC
  mov ax, Dane
  mov ds, ax
  MOV ES, AX
;Ustawienie kursora w 20 wierszu:
  MOV AH, 2
  MOV BH, 0
  MOV DH, 20
  MOV DL, 0
  INT 10H
;Wy�wietlenie napisu informacyjnego:
  MOV DX, OFFSET NAPIS
  MOV AH, 9H
  INT 21H
;Petla wyboru operacji:
  PETLA_GLOWNA:
  XOR AH, AH
  INT 16H       ;Odczyt bufora klawiatury
  CMP AL, '1'
  JNE D1
;Rezerwacja ramki:
    MOV DI, OFFSET  BINARNA_MAPA_PAMIECI
    CALL  ZAREZERWOJ_STRONE
    CALL WYSWIETL_STAN
    call DRUKUJ_HEX
    JMP PETLA_GLOWNA
  D1:
  CMP AL, '2'
  JNE D2
;Zwolnienie pierwszej zaj�tej ramki:
    MOV DI, OFFSET  BINARNA_MAPA_PAMIECI
    CALL  ZNAJDZ_PIERWSZY_ZAJETY_BIT
    MOV EDX, EAX
    PUSH DX
    SHR EDX, 16
    PUSH DX
    CALL DRUKUJ_HEX
    POP AX
    SHL EAX, 16
    POP AX
    CALL ZWOLNIJ_STRONE
    CALL  WYSWIETL_STAN
  JMP PETLA_GLOWNA
  D2:
  CMP AL, 'k'
  JNE D3
;Koniec programu:
  JMP K
  D3:
  JMP PETLA_GLOWNA
  K:
  mov  AH,4CH
  mov  AL,0
  int  21H
MAIN ENDP

ZAREZERWOJ_STRONE PROC
  PUSH BX
  PUSH CX
  PUSH DI
  XOR EAX, EAX
  XOR ECX, ECX
;Poszukiwanie pierwszego bajtu w binarnej mapie pami�ci, kt�rego warto�� jest r�na od 0FFh
;(czyli samych jedynek), co oznacza, �e w bajcie tym jest bit opisuj�cy woln� ramk� pami�ci
  PETLA_ZNAJDOWANIA_WOLNEJ_PRZESTRZENI:
    MOV AL, [ES:DI]
    CMP AL, 0FFH
    JNE KONIEC_PETLI_ZNAJDOWANIA_WOLNEJ_PRZESTRZENI
    INC DI
    JMP PETLA_ZNAJDOWANIA_WOLNEJ_PRZESTRZENI
  KONIEC_PETLI_ZNAJDOWANIA_WOLNEJ_PRZESTRZENI:
;Rejestr DI zawiera adres znalezionego bajtu, natomiast rejestr AL  jego warto��
  PUSH AX    		;Zachowywana jest warto�� odnalezionego bajtu.
  NOT AL     		;Negacja bit�w rejestru AL - dzi�ki temu wszystkie zerowe bity
		        ;stan� si� jedynkami- ich pozycje mo�na okre�li� z u�yciem instrukcji BSR.
  SHL AX, 8   		;Przeniesienie rejestru AL do rejestru AH z jednoczesnym
		        ;wyzerowaniem tego pierwszego (rozkaz BSR u�ywa
       			;rejestr co najmniej 16 bitowy).
  XOR EBX, EBX
  BSR BX, AX 		;Binarne poszukiwanie w ty�, pozycja pierwszego ustawionego bitu
		        ;zapisana do BX, nale�y jednak zaznaczy�, �e pozycja ta jest liczona
			;od bitu numer 0.
  BTC AX, BX   		;Prze��czenie bitu (na pozycji obliczonej powy�ej)- rezerwacja ramki.
  CLC
  NOT AH      		;Przywracanie pierwotnego stanu bit�w odnalezionego bajtu (z wyj�tkiem
			;tego,  kt�ry zosta� przestawiony poleceniem BTC- zarezerwowanego).
  MOV [ES:DI], AH 	;Od�o�enie we w�a�ciwe miejsce binarnej mapy pami�ci
			;zaktualizowanej warto�ci bajtu (rezerwacja ramki).
;Czynno�ci zwi�zane z obliczaniem adresu fizycznego znalezionej wolnej ramki.
  MOV CX, 8   ;Bajt binarnej mapy pami�ci zosta� przesuni�ty na starsz� po�ow�
              ;rejestru AX, przez odj�cie 8 zostanie otrzymany numer bitu w
  SUB BX, CX  ;odczytanym bajcie.
  MOV AX, DI  ;AX teraz zawiera adres odczytanego bajtu
  POP dx
  pop cx
  PUSH CX          ;CX zawiera adres binarnej mapy
  push dx
  SUB AX, CX       ;okre�lenie adresu bajtu wzgl�dem pocz�tku mapy
;Warto�� ta mno�ona jest przez 8, dzi�ki czemu uzyskiwana jest liczba bit�w mapy pami�ci,
;do pozycji w kt�rej odnaleziono bajt z wolnym elementem:
  XOR DX, DX
  MOV CX, 8
  MUL  CX
;Nale�y jeszcze doda� pozycj� w�a�ciwego bitu w bajce, by otrzyma� ostateczny numer ramki:
  MOV DX, 8
  SUB DX, BX      ;8 - (numer bitu liczony od najm�odszego bitu) = numer bitu
                  ;wzgl�dem najstarszego bitu + 1
  ADD AX, DX      ;dodanie numeru bitu
;Aby uzyska� adres fizyczny nale�y pomno�y� przez 4096:
  MOV ECX, 4096
  XOR EDX, EDX
  MUL ECX
;W tej chwili w EAX znajduje si� adres fizyczny pocz�tku wolnej ramki.

  POP CX    		;Przywracane wcze�niej zachowane s�owo zawieraj�ce na m�odszych 8 bitach
			;warto�� znalezionego bajtu sprawdzany jest jeszcze warunek, czy ten
;adres fizyczny nie le�a� poza przestrzeni� adresow�.
  CMP EAX, CALKOWITA_WIELKOSC_PAMIECI_W_B
  JBE DALEJ3
  XOR EAX, EAX	;Gdy juz nie ma wolnych ramek, zwracane jest 0 w EAX.
  MOV [ES:DI], CL 	;Przywracana warto�� wcze�niej zmienionego bajtu binarnej mapy pami�ci
  DALEJ3:
  POP DI
  POP CX
  POP BX
  RET
ZAREZERWOJ_STRONE ENDP


ZWOLNIJ_STRONE PROC
;Parametry procedury:
;EAX - adres fizyczny ramki,
;ES:DI - adres binarnej mapy pami�ci.
  PUSHA
;Obliczany jest numer ramki:
  MOV EBX, 4096
  SUB EAX, EBX      ;Adres 0 jest zarezerwowany, pierwszym adresem fizycznym
                    ;ramki mo�e by� adres 4096. Pozycja zwolnionego bitu w
                    ;binarnej mapie pami�ci b�dzie jednak liczona od 0.
  XOR EDX, EDX
  DIV EBX      	    ;W EAX znajduje si� numer ramki

;Wyznaczenie adresu bajtu w mapie pami�ci, kt�ry przechowuje informacje o zaj�to�ci tej ramki
  XOR EDX, EDX
  MOV EBX, 8
  DIV EBX   		;W EAX obliczono numer bajtu, kt�ry przechowuje informacj� o ramce
			;EDX zawiera natomiast reszt� z dzielenia- numer bitu w bajcie wzgl�dem najstarszego bitu.
  ADD DI, AX  		;Adres bajtu przechowuj�cego docelowy bit
  MOV AL, [ES:DI]	;Zapis bajtu do AL
  MOV CX, 7
  SUB CX, DX            ;uzyskanie numeru bitu wzgl�dem najm�odszego bitu
  BTR AX, CX  		;Kasowanie bitu.
  MOV [ES:DI], AL 	;Odk�adana do mapy pami�ci zaktualizowana warto�� bajtu, w kt�rym
		    	;zwolniono pozycj�.
  POPA
  RET
ZWOLNIJ_STRONE ENDP

ZNAJDZ_PIERWSZY_ZAJETY_BIT PROC
  PUSH BX
  PUSH CX
  PUSH DI
  XOR EAX, EAX
  XOR ECX, ECX
;Poszukiwanie pierwszego bajtu w binarnej mapie pami�ci, kt�rego warto�� jest r�na od 0
;co oznacza, �e w bajcie znajduje si� zaj�ta ramka.
  PETLA_ZNAJDOWANIA_ZAJETEJ_RAMKI:
    MOV AL, [ES:DI]
    CMP AL, 0H
    JNE KONIEC_PETLI_ZNAJDOWANIA_ZAJETEJ_RAMKI
    INC DI
    JMP PETLA_ZNAJDOWANIA_ZAJETEJ_RAMKI
  KONIEC_PETLI_ZNAJDOWANIA_ZAJETEJ_RAMKI:
;Rejestr DI zawiera adres znalezionego bajtu, natomiast rejestr AL  jego warto��
  PUSH AX    		;Zachowywana jest warto�� odnalezionego bajtu.
  SHL AX, 8   		;Przeniesienie rejestru AL do rejestru AH z jednoczesnym
                      	;wyzerowaniem tego pierwszego (rozkaz BSR u�ywa
                      	;rejestr co najmniej 16 bitowy).
  BSR BX, AX 		;Binarne poszukiwanie w ty�, pozycji pierwszego ustawionego bitu
;Czynno�ci zwi�zane z obliczaniem adresu fizycznego znalezionej zaj�tej ramki.
  MOV CX, 8
  SUB BX, CX            ;Bajt binernej mapy pami�ci zosta� przesuni�ty na starsz� po�ow�
              		;rejestru AX, przez odj�cie 8 zostanie otrzymany numer bitu w
              		;odczytanym bajcie.
  MOV AX, DI		;AX teraz zawiera adres odnalezionego bajtu w mapie.
  POP dx
  pop cx
  PUSH CX               ;CX zawiera adres mapy (wzgl�dem ES).
  push dx
  SUB AX, CX           ;Otrzymanie adresu bajtu wzgl�dem pocz�tku mapy.
;Warto�� ta mno�ona jest przez 8, dzi�ki czemu uzyskiwana jest liczba bit�w mapy pami�ci,
;do pozycji w kt�rej odnaleziono bajt z zaj�tym elementem:
  XOR DX, DX
  MOV CX, 8
  MUL  CX
;Nale�y jeszcze doda� pozycj� w�a�ciwego bitu w bajce, by otrzyma� ostateczny numer ramki:
  MOV DX, 8
  SUB DX, BX   		;uzyskanie numeru bitu wzgl�dem najstarszego bitu
  ADD AX, DX
;Aby uzyska� adres fizyczny nale�y pomno�y� przez 4096:
  MOV ECX, 4096
  XOR EDX, EDX
  MUL ECX
;W tej chwili w EAX znajduje si� adres fizyczny pocz�tku pierwszej zaj�tej ramki.

  POP CX    			;Przywracane wcze�niej zachowane s�owo zawieraj�ce na m�odszych 8 bitach
				;warto�� znalezionego bajtu.
                                ;sprawdzenie warunku, czy ten
				;adres fizyczny nie le�a� poza przestrzeni� adresow�.
  CMP EAX, CALKOWITA_WIELKOSC_PAMIECI_W_B
  JBE DALEJ4
  XOR EAX, EAX		;Gdy juz nie ma wolnych stron, zwracane jest 0 w EAX.
  MOV [ES:DI], CL 	;Przywracana warto�� wcze�niej zmienionego bajtu binarnej mapy pami�ci
  DALEJ4:
  POP DI
  POP CX
  POP BX
  RET
ZNAJDZ_PIERWSZY_ZAJETY_BIT ENDP

WYSWIETL_STAN PROC
;Parametry procedury:
;REJESTRY ES:DI MAJ� ZAWIERA� ADRES BINARNEJ MAPY
  PUSH DI
  PUSH AX
  PUSH DX
  PUSH BX
;ustawienie kursora w zerowym wierszu i zerowej kolumnie:
  MOV AH, 2
  MOV BH, 0
  MOV DH, 0
  MOV DL, 0
  INT 10H
;W zale�no�ci od warto�ci kolejnych bit�w binarnej mapy pami�ci
;zostan� wypisane znaki '0' lub '1'
  MOV CX, ROZMIAR_BMP
  PETLA_WYSWIETLANIA_BINARNEJ_MAPY:
  PUSH CX
    MOV DL, [ES:DI]
    MOV CX, 8
    PETLA_WYSWIETLANIA_BAJTA_MAPY:
      SHL DL, 1
      JNC DALEJ
        MOV AL, '1'
      JMP DALEJ2
      DALEJ:
        MOV AL, '0'
      DALEJ2:
      MOV BH, 0
      MOV BL, 7H
      MOV AH, 0EH
      INT 10H
    LOOP PETLA_WYSWIETLANIA_BAJTA_MAPY
    INC DI
  POP CX
  LOOP PETLA_WYSWIETLANIA_BINARNEJ_MAPY

  POP BX
  POP DX
  POP AX
  POP DI
  RET
WYSWIETL_STAN ENDP

DRUKUJ_HEX     PROC
;Procedura drukuj�ca warto�� rejestru EAX w kodzie szestnastkowym
;Parametry procedury:
;EAX - liczba do wydrukowania
  PUSH CX
  PUSH DI
  PUSH DX
  PUSH AX
  MOV DX, ES
  PUSH DX
  MOV DX, 0B800h
  MOV ES, DX
  MOV DI, 2000
  MOV CX, 8
  MOV BYTE PTR [ES:DI-8], 'E'
  MOV BYTE PTR [ES:DI-6], 'A'
  MOV BYTE PTR [ES:DI-4], 'X'
  MOV BYTE PTR [ES:DI-2], '='
  PETLA_WYPISYWANIA:
    MOV EDX, 0FH
    ROL EAX, 4
    AND EDX, EAX
    CMP DL, 9
    JA DALEJ1
    ADD DL, '0'
    JMP KONIEC_DALEJ1
    DALEJ1:
    SUB DL, 10
    ADD DL, 'A'
    KONIEC_DALEJ1:
    PUSH AX
    MOV [ES:DI], DL
    INC DI
    INC DI
    POP AX
  LOOP PETLA_WYPISYWANIA
  POP DX
  MOV ES, DX
  POP AX
  POP DX
  POP DI
  POP CX
  RET
DRUKUJ_HEX     ENDP



Program     ENDS
Stos_    SEGMENT STACK
           DB      64 DUP ('STACK!!!')
Stos_    ENDS
END MAIN



