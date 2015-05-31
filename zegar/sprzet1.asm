.386P
POLOZENIE_DESKRYPTORA_DANYCH_KLAWIATURY EQU  40
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
;Globalna tablica deskryptor�w  
INCLUDE GDT.TXT
GDT_KLAWIATURA DESKR <KEYB_SIZE-1, 0,0,92H,0,0>	;Selektor 40
GDT_SIZE = $ - GDT_NULL

KEYBOARD LABEL WORD
  BUFOR_OFFSET=$-KEYBOARD
  BUFOR 			DW 32 DUP(0)
  WSKAZNIK_ZAPISU_OFFSET=$-KEYBOARD
  WSKAZNIK_ZAPISU   	DB  1
  WSKAZNIK_ODCZYTU_OFFSET=$-KEYBOARD
  WSKAZNIK_ODCZYTU  	DB  1
  BAJT_STANU_1_OFFSET=$-KEYBOARD
  BAJT_STANU_1      	DB  0
;0    wci�ni�ty prawy shift, 1    wci�ni�ty lewy  shift, 2    wci�ni�ty ctrl, 3    wci�ni�ty alt, 4    wci�ni�ty scroll lock, 
;5    wci�ni�ty num lock, 6    wci�ni�ty caps lock, 7    wci�ni�ty insert.
KEYB_SIZE=$-KEYBOARD

KLAWISZE1 DB 0, 1BH,"1234567890-=", 08H, 09H, "qwertyuiop[]", 0DH, 0, "asdfghjkl;",39, "`", 0, "\", "zxcvbnm,./", 0,0,0," ", 0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,    0,0,0, 0
KLAWISZE2 DB 0, 1BH,"!@#$%^&*()_+", 08H, 09H, "QWERTYUIOP{}", 0DH, 0, "ASDFGHJKL:",34, "~", 0, "|", "ZXCVBNM<>?", 0,0,0," ", 0,0,0,0,0,0,0,0,0,0,0,0,0,"789-456+1230", 0
;Tablica deskryptor�w przerwa� IDT:
IDT	LABEL WORD
  TRAP 	13 	DUP(<EXC_>)
  EXC13   	TRAP <EXC_13>
  TRAP 	18 	DUP(<EXC_>)
  INTR 		<EXC_>
  INTR 		<PRZERWANIE1>
IDT_SIZE = $ - IDT
PDESKR	DQ 0
ORG_IDT DQ 0
TEKST	DB 'TRYB CHRONIONY'
ATRYB   DB 1EH
TEKST_0	DB 'OBS�UGA WYJATKU NR 0 (DZIELENIE PRZEZ ZERO)'
ATRYB_0	DB 1EH
TEKST_1	DB 'OBS�UGA WYJATKU NR 1'
ATRYB_1 DB 1EH
TEKST13 DB 'OGOLNE NARUSZENIE MECHANIZMU OCHRONY'
ATRYB13 DB 0FAH
INFO	DB 'POWROT Z TRYBU CHRONIONEGO $'
DANE_SIZE = $ - GDT_NULL
DANE	ENDS

PROGRAM	SEGMENT  USE16
  ASSUME CS:PROGRAM, DS:DANE

SPRAWDZ_BUFOR_KLAWIATURY    MACRO
  LOCAL BRAK_GOTOWOSCI_KLAWIATURY
  BRAK_GOTOWOSCI_KLAWIATURY:
    IN AL, 64H    				;Pobranie rejestru stanu.
    MOV AH, 00100001B  				;Pozostawienie bit�w 0- stan bufora wej�ciowego ( 0-pusty,
                       				;1-sa dane) bit 5- z jakiego uk�adu dane pochodz�
                       				;0- z klawiatury, 1- z jednostki dodatkowej.
    AND AL, AH
    CMP AL, 1          				;Oczekiwanie na dane pochodz�ce z klawiatury.	
  JNE BRAK_GOTOWOSCI_KLAWIATURY
ENDM

PM_WYPISZ_ZNAK MACRO
  MOV [ES:DI], AL      
  INC DI      
  INC DI      
ENDM

INCLUDE MAKRA.TXT

START:
  INICJOWANIE_DESKRYPTOROW
  XOR EAX,EAX			
  MOV AX,SEG DANE
  SHL EAX,4				
  XOR EBX, EBX
  MOV BX, OFFSET KEYBOARD
  ADD EAX, EBX
  MOV BX,OFFSET GDT_KLAWIATURA
  MOV [BX].BASE_1,AX
  ROL EAX,16
  MOV [BX].BASE_M,AL
  XOR EAX, EAX
  MOV AX,SEG DANE           					
  SHL EAX,4					
  MOV EBP,EAX	
  CLI
  KONTROLER_PRZERWAN_PM 0FDH
  INICJACJA_IDTR
  AKTYWACJA_PM
  MOV AX,32                            					
  MOV ES,AX                            
  MOV BX,OFFSET TEKST			;Wy�wietlenie tekstu potwierdzaj�cego
  MOV CX,14				;prac� w trybie chronionym.
  MOV AL,[BX]
  MOV SI,0
  PETLA:
    MOV ES:[SI+680],AL
    MOV AL,ATRYB
    MOV ES:[SI+681],AL
    ADD BX,1
    ADD SI,2
    MOV AL,[BX]
  LOOP PETLA
  STI
  JMP $
  _KONIEC_:
  CLI
  MIEKI_POWROT_RM
  KONTROLER_PRZERWAN_RM	
  POWROT_DO_RM 0,1

INCLUDE PROC.TXT


POBIERZ_LOKALNY_REJESTR_STANU_KLAWIATYRY PROC
  PUSH BX
  MOV BX, ES
  PUSH BX
  MOV BX, POLOZENIE_DESKRYPTORA_DANYCH_KLAWIATURY
  MOV ES, BX  
  MOV AH, [ES:BAJT_STANU_1_OFFSET]  ;Do rejestru AH pobierany 
                                    ;lokalny rejestr stanu klawiatury.
  POP BX
  MOV ES, BX
  POP BX
  RET
POBIERZ_LOKALNY_REJESTR_STANU_KLAWIATYRY ENDP

INNY_PRZYCISK PROC
;Parametry procedury:
;AL - kod wci�ni�tego klawisza
  PUSH BX   
  MOV BX, ES
  PUSH BX
  MOV BX, POLOZENIE_DESKRYPTORA_DANYCH_KLAWIATURY
  MOV ES, BX  			;ES zawiera selektor segmentu danych klawiatury.
;Ustawienie bitu zwi�zanego z klawiszem ctrl (2 bit w bajcie stanu odpowiada za ten przycisk):
  XOR BX, BX
  CMP AL, 29    		;ctrl wci�ni�ty.
  JNE CONTINUE1
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 100B
  JMP TERMINATE
;Wyzerowanie bitu zwi�zanego z klawiszem ctrl (2 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE1:
  CMP AL, 29+128 		;Zwolniony ctrl.
  JNE CONTINUE2
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 11111011B
  JMP TERMINATE
;Ustawienie bitu zwi�zanego z klawiszem lewego shifta (1 bit w bajcie stanu ;odpowiada za ten przycisk):
  CONTINUE2:
  CMP AL, 42  			;Lewy Shift.
  JNE CONTINUE3
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 10B
  JMP TERMINATE
;Wyzerowanie bitu zwi�zanego z klawiszem lewego shifta (2 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE3:
  CMP AL, 42+128 		;Lewy shift.
  JNE CONTINUE4
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 11111101B
  JMP TERMINATE
;Ustawienie bitu zwi�zanego z klawiszem prawego shifta (0 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE4:
  CMP AL, 54   			;Prawy shift.
  JNE CONTINUE5
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 1B
  JMP TERMINATE
;Wyzerowanie bitu zwi�zanego z klawiszem prawego shifta (0 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE5:
  CMP AL, 54+128 		;Prawy shift.
  JNE CONTINUE6
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 11111110B
  JMP TERMINATE
;Ustawienie bitu zwi�zanego z klawiszem alt(3 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE6:
  CMP AL, 56  			;alt
  JNE CONTINUE7
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 1000B
  JMP TERMINATE
;Wyzerowanie bitu zwi�zanego z klawiszem alt (3 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE7:
  CMP AL, 56+128 		;alt
  JNE CONTINUE8
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 11110111B
  JMP TERMINATE
;Ustawienie bitu zwi�zanego z klawiszem scroll lock (4 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE8:
  CMP AL, 70  			;scroll lock
  JNE CONTINUE9
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 10000B
  JMP TERMINATE
;Wyzerowanie bitu zwi�zanego z klawiszem scroll lock (4 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE9:
  CMP AL, 70+128 		;scroll lock
  JNE CONTINUE10
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 11101111B
  JMP TERMINATE
;Ustawienie bitu zwi�zanego z klawiszem num lock (5 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE10:
  CMP AL, 69  			;num lock
  JNE CONTINUE11
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 100000B
  JMP TERMINATE
;Wyzerowanie bitu zwi�zanego z klawiszem num lock (5 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE11:
  CMP AL, 69+128 		;num lock
  JNE CONTINUE12
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 11011111B
  JMP TERMINATE
;Prze��czenie bitu zwi�zanego z klawiszem caps lock (6 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE12:
  CMP AL, 58  			;caps lock
  JNE CONTINUE13
    BTC WORD PTR [ES:BAJT_STANU_1_OFFSET], 6 ;negacja 6 bit
    CLC
  JMP TERMINATE
;Ustawienie bitu zwi�zanego z klawiszem insert (7 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE13:
  CMP AL, 82  			;insert
  JNE CONTINUE15
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 10000000B
  JMP TERMINATE
;Wyzerowanie bitu zwi�zanego z klawiszem insert (7 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE15:
  CMP AL, 82+128 		;insert
  JNE CONTINUE16	
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 01111111B
  JMP TERMINATE
;Je�eli kod klawisza zawarty w rejestrze AL jest kodem zwolnienia (tylko kody zwolnienia
;mog� osi�ga� warto�ci powy�ej 128)  to nast�puje skok do dalszej cz�ci procedury.
  CONTINUE16:
  CMP AL, 128
  JA TERMINATE
;W przeciwnym razie nast�puje wprowadzenie znaku do bufora:
  CALL WPROWADZ_DO_BUFORA
  TERMINATE:
  MOV BL, [ES:BAJT_STANU_1_OFFSET]
  TEST BL, 100000B
  JZ CONTINUE17
    CALL WCISNIETY_
  CONTINUE17:
  TEST BL, 00000100B
  JZ CONT_Z
    CALL PROCEDURA_KOMBINACJI_KLAWISZY
  CONT_Z:
  POP BX
  MOV ES, BX
  POP BX
  RET
INNY_PRZYCISK ENDP

WPROWADZ_DO_BUFORA PROC
;Zadaniem procedury jest zapisanie na odpowiedniej pozycji bufora klawiatury s�owa okre�laj�cego kod 
;matrycowy naci�ni�tego klawisza, oraz jego odpowiednik ASCII (w przypadku, gdy klawisz nie ma 
;odpowiednika ASCII - zera).
  PUSH AX
  PUSH BX
  MOV BX, ES
  PUSH BX
  MOV BX, POLOZENIE_DESKRYPTORA_DANYCH_KLAWIATURY
  MOV ES, BX     			;Rejestr segmentowy es �adowany selektorem danych klawiatury.
  MOV BL, [ES:WSKAZNIK_ZAPISU_OFFSET]   ;Do BL �adowany wska�nik zapisu
                                        ;okre�laj�cy ostatnio zapisan� pozycj� w buforze klawiatury.
  MOV BH, [ES:WSKAZNIK_ODCZYTU_OFFSET]  ;Rejestr BH �adowany wska�nikiem odczytu
                                        ;klawiatury, zawieraj�cym pozycj� ostatnio odczytywan�.
  INC BL        			;Wska�nik zapisu zwi�kszany o 1 (ustawiana kolejna pozycja
                			;w�a�ciwa do zapisu kod�w matrycowych i ASCII).
  CMP BL, 32    			;Sprawdzany warunek, czy wska�nik zapisu nie przekracza
                			;wielko�ci bufora.
  JNE NEXT1
  XOR BL, BL  				;Je�eli tak, nast�puje zawiniecie adresu.
  NEXT1:
  CMP BL, BH    			;Sprawdzenie warunku, czy wska�nik odczytu nie pokrywa 
                			;si� z zaktualizowanym wska�nikiem zapisu.
  JNE NEXT
;Je�eli pokrywaj� si� obie warto�ci, nale�y przywr�ci� warto�� wska�nika zapisu (zosta� zwi�kszony, ale nie 
;mo�e doj�� do zapisu, gdy� bufor jest przepe�niony)
  CMP BL, 0 				;Je�eli wska�nik zapisu ma warto�� 0, to przed aktualizacj�
;musia� mie� warto�� 32.
  JNE NEXT2
  MOV BL, 32
  NEXT2:
  DEC BL
;Wywo�anie procedury (w przyk�adzie ksi��kowym pustej), kt�ra mo�e pos�u�y� do podj�cia pewnych 
;krok�w maj�cych na celu cho�by poinformowanie u�ytkownika o przepe�nionym buforze.
  CALL PRZEPELNIENIE_BUFORA_KLAWIATURY
  JMP KONIEC_WPR
  NEXT:
  AND BX, 0FFH  			;Rejestr BL zawiera warto�� wska�nika zapisu, nast�puje
					;czyszczenie rejestru BH.
;Poni�ej nast�puje zapis kodu ASCII oraz kodu matrycowego (obie warto�ci przekazane procedurze w rejestrze BX)
;na odpowiedniej pozycji bufora klawiatury (BX mno�ony razy 2, gdy� wska�nik zapisu ma za zadanie
;wskazywa� s�owa w buforze, natomiast adresowanie odbywa si� w bajtach):
  PUSH BX
  SHL BX, 1
  MOV [ES:BX+BUFOR_OFFSET], AX 
;Uaktualnienie warto�ci wska�nika zapisu:
  POP BX
  MOV [ES:WSKAZNIK_ZAPISU_OFFSET], BL
  KONIEC_WPR:
  POP BX
  MOV ES, BX
  POP BX
  POP AX
  RET
WPROWADZ_DO_BUFORA ENDP

WCISNIETY_ PROC
  PUSH AX
  PUSH BX
  MOV BX, ES
  PUSH BX
  MOV AX, 20H
  MOV ES, AX
  CALL PM_WYMAZ_EKRAN
  XOR DI, DI
  WYPISYWANIE_BUFORA:
    CALL ODCZYTAJ_Z_BUFORA
    CMP AX, 0
    JE KONIEC_WYPISYWANIA
    XCHG AL, AH
    PM_WYPISZ_ZNAK
  JMP WYPISYWANIE_BUFORA
  KONIEC_WYPISYWANIA:
  POP BX
  MOV ES, BX
  POP BX
  POP AX
  RET
WCISNIETY_ ENDP

PROCEDURA_KOMBINACJI_KLAWISZY PROC
  CLI
  IN AL, 61H        		;Odczyt bajtu z portu 61h.
  OR AL, 10000000B  		;Suma logiczna otrzymanego bajtu
                     		;z ustawionym najstarszym bitem.
  OUT 61H, AL       
  AND AL, 7FH       		;Wyczyszczenie ostatniego bitu.
  OUT 61H, AL       
  MOV AL, 20H
  OUT 20H, AL

  JMP _KONIEC_
  RET
PROCEDURA_KOMBINACJI_KLAWISZY ENDP

PRZEPELNIENIE_BUFORA_KLAWIATURY  PROC
  RET
PRZEPELNIENIE_BUFORA_KLAWIATURY  ENDP

ODCZYTAJ_Z_BUFORA PROC
;Procedura odczytuje bufor klawiatury i zwraca kod matrycowy oraz kod ASCII znaku 
;Wyniki:
;AX - kod matrycowy oraz kod ASCII znaku.
  CLI    			;Wy��czenie przerwa�, aby mie� pewno��, �e w trakcie wykonywania
       				;si� procedury nie nast�pi do�o�enie nowej pozycji do bufora.
  PUSH BX
  MOV BX, ES
  PUSH BX
  MOV BX, DS
  PUSH BX
  MOV BX, 8
  MOV DS, BX      		;Rejestr ds �adowany selektorem segmentu danych.
  MOV BX, POLOZENIE_DESKRYPTORA_DANYCH_KLAWIATURY
  MOV ES, BX      		;Rejestr segmentowy ES �adowany selektorem danych klawiatury.
  MOV BL, [ES:WSKAZNIK_ODCZYTU_OFFSET] ;Do BL �adowany wska�nik odczytu
                                       ;okre�laj�cy ostatnio odczytywan� pozycj� bufora klawiatury.
  MOV BH, [ES:WSKAZNIK_ZAPISU_OFFSET]  ;Do BH �adowany wska�nik zapisu
                                       ;okre�laj�cy ostatnio zapisywan� pozycj� w buforze klawiatury.
  INC BH        		;Inkrementacja warto�ci wska�nika zapisu umieszczonej w BH.
  CMP BH, 32    		;Sprawdzenie, czy aby nie jest wi�kszy od rozmiaru bufora.
  JNE CAS0
  XOR BH, BH  			;Je�eli tak, adres jest zawijany.
  CAS0:
  INC BL        		;Ustawienie wska�nika odczytu na pierwsz� jeszcze
                		;nie odczytywan� pozycj� w buforze.
  CMP BL, 32    		;Sprawdzenie, czy warto�� wska�nika odczytu nie jest wi�ksza
                		;od rozmiaru bufora klawiatury.
  JNE CAS1
  XOR BL, BL  			;Je�eli wska�nik odczytu jest wi�kszy od rozmiaru bufora klawiatury
                		;nast�puje zawini�cie adresu.
  CAS1:
  CMP BL, BH    		;Sprawdzenie warunku, czy wska�nik odczytu nie pokrywa
                		;si� ze wska�nikiem zapisu (zwi�kszonym o 1).
  JNE CAS
;Je�eli bufor jest pusty, do rejestru AX zapisywana jest warto�� 0.
  XOR AX, AX
  JMP ZAKONCZ_
  CAS:
;W BL znajduje si� numer pozycji bufora, kt�r� nale�y odczyta�. 
  AND BX, 0FFH
;Poni�ej nast�puje odczyt kodu ASCII oraz kodu matrycowego pierwszej jeszcze nie odczytywanej 
;pozycji bufora klawiatury (BX mno�ony razy 2):
  PUSH BX
  SHL BX, 1
  MOV AX, [ES:BX+BUFOR_OFFSET]
;Uaktualnienie warto�ci wska�nika odczytu:
  POP BX
  MOV [ES:WSKAZNIK_ODCZYTU_OFFSET], BL
  ZAKONCZ_:
  POP BX
  MOV DS, BX
  POP BX
  MOV ES, BX
  POP BX
  STI
  RET
ODCZYTAJ_Z_BUFORA ENDP

PRZERWANIE1 PROC
  PUSHA
  PUSHF
  PUSH AX
  PUSH SI
  MOV AX, DS
  PUSH AX
  MOV AX, ES
  PUSH AX
  MOV AX, 8
  MOV DS, AX    		;Rejestr DS �adowany selektorem segmentu danych
;Odczyt kodu naci�ni�cia (b�d� zwolnienia) klawisza:
  SPRAWDZ_BUFOR_KLAWIATURY
  IN AL, 60H

;Dla niekt�rych klawiszy nie istniej� odpowiedniki ASCII, nale�y wi�c wzi�� pod uwag� r�wnie� ten warunek:
  CMP AL, 2
  JB INNE
  CMP AL, 82
  JA INNE
  XOR ESI, ESI
  MOVZX SI, AL  		;Rejestr indeksowy SI �adowany jest
                 		;kodem matrycowym klawisza (odpowiednie kody ASCII
                 		;s� na pozycjach o numerze r�wnym kodowi matrycowemu).
  MOV AH, 0    		
  CALL POBIERZ_LOKALNY_REJESTR_STANU_KLAWIATYRY
  TEST AH, 1000011B  		;Sprawdzenie, czy aby kt�ry� z przycisk�w
                      		;zmieniaj�cych wielko�� liter nie jest trzymany
                      		;(gdy� zmieni to tablic� znak�w, z kt�rej nast�pi
                      		;dekodowanie kodu matrycowego na kod ASCII).
  JNZ WCISNIETY_SHIFT
;W przypadku, gdy �aden klawisz z: prawy shift, lewy shift, caps lock nie jest naci�niety, pobierany jest kod 
;ASCII z tablicy znak�w KLAWISZE1.
  MOV AH, [KLAWISZE1+ SI]
  JMP CONT
  WCISNIETY_SHIFT:
;W przeciwnym razie nale�y pobra� odpowiedni kod ASCII z tablicy znak�w KLAWISZE2.
  MOV AH, [KLAWISZE2+ SI]
  CONT:
  CMP AH, 0  			;W przypadku, gdy kod matrycowy nie ma swojego
              			;odpowiednika ASCII, zostanie wywo�ana procedura
              			;INNY_PRZYCISK.
  JNE DO_BUFORA
  INNE:
  MOV BL, 0
  CALL INNY_PRZYCISK
  JMP KONIEC_PRZERW1
  DO_BUFORA:
;Gdy klawisz ma powi�zany z nim kod ASCII nast�puje zapis zar�wno kodu matrycowego (w AL) jak
;i kodu ASCII (w AH) do bufora klawiatury:
  CALL WPROWADZ_DO_BUFORA
  KONIEC_PRZERW1:
;Poni�ej znajduje si� kod zwi�zany z potwierdzeniem odbioru kodu matrycowego.
  IN AL, 61H        		;Odczyt bajtu z portu 61h.
  OR AL, 10000000B  		;Suma logiczna otrzymanego bajtu
                     		;z ustawionym najstarszym bitem.
  OUT 61H, AL       
  AND AL, 7FH       		;Wyczyszczenie ostatniego bitu.
  OUT 61H, AL       
  POP AX
  MOV ES, AX
  POP AX
  MOV DS, AX
  MOV AL, 20H
  OUT 20H, AL
  POP SI
  POP AX
  POPF
  POPA
  IRETD
PRZERWANIE1 ENDP

EXC_ PROC			;Procedura obs�ugi wyj�tku nr 0.
  JMP _KONIEC_
EXC_ ENDP


EXC_13 PROC			;Procedura obs�ugi wyj�tku nr 13.
  MOV AX,32				
  MOV ES,AX
  MOV BX,OFFSET TEKST13
  MOV CX,36
  MOV AL,[BX]
  MOV SI,0
  PETLA13:
    MOV ES:[SI+1000],AL
    MOV AL,ATRYB13
    MOV ES:[SI+1001],AL
    ADD BX,1
    ADD SI,2
    MOV AL,[BX]
  LOOP PETLA13
  JMP _KONIEC_
EXC_13 ENDP

  PROGRAM_SIZE = $ - START
PROGRAM ENDS

STK  SEGMENT STACK 'STACK'
  DB 256 DUP(?)
STK  ENDS
END START

