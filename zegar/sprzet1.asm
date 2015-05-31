.386P
POLOZENIE_DESKRYPTORA_DANYCH_KLAWIATURY EQU  40
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
;Globalna tablica deskryptorów  
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
;0    wciœniêty prawy shift, 1    wciœniêty lewy  shift, 2    wciœniêty ctrl, 3    wciœniêty alt, 4    wciœniêty scroll lock, 
;5    wciœniêty num lock, 6    wciœniêty caps lock, 7    wciœniêty insert.
KEYB_SIZE=$-KEYBOARD

KLAWISZE1 DB 0, 1BH,"1234567890-=", 08H, 09H, "qwertyuiop[]", 0DH, 0, "asdfghjkl;",39, "`", 0, "\", "zxcvbnm,./", 0,0,0," ", 0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,    0,0,0, 0
KLAWISZE2 DB 0, 1BH,"!@#$%^&*()_+", 08H, 09H, "QWERTYUIOP{}", 0DH, 0, "ASDFGHJKL:",34, "~", 0, "|", "ZXCVBNM<>?", 0,0,0," ", 0,0,0,0,0,0,0,0,0,0,0,0,0,"789-456+1230", 0
;Tablica deskryptorów przerwañ IDT:
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
TEKST_0	DB 'OBS£UGA WYJATKU NR 0 (DZIELENIE PRZEZ ZERO)'
ATRYB_0	DB 1EH
TEKST_1	DB 'OBS£UGA WYJATKU NR 1'
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
    MOV AH, 00100001B  				;Pozostawienie bitów 0- stan bufora wejœciowego ( 0-pusty,
                       				;1-sa dane) bit 5- z jakiego uk³adu dane pochodz¹
                       				;0- z klawiatury, 1- z jednostki dodatkowej.
    AND AL, AH
    CMP AL, 1          				;Oczekiwanie na dane pochodz¹ce z klawiatury.	
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
  MOV BX,OFFSET TEKST			;Wyœwietlenie tekstu potwierdzaj¹cego
  MOV CX,14				;pracê w trybie chronionym.
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
;AL - kod wciœniêtego klawisza
  PUSH BX   
  MOV BX, ES
  PUSH BX
  MOV BX, POLOZENIE_DESKRYPTORA_DANYCH_KLAWIATURY
  MOV ES, BX  			;ES zawiera selektor segmentu danych klawiatury.
;Ustawienie bitu zwi¹zanego z klawiszem ctrl (2 bit w bajcie stanu odpowiada za ten przycisk):
  XOR BX, BX
  CMP AL, 29    		;ctrl wciœniêty.
  JNE CONTINUE1
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 100B
  JMP TERMINATE
;Wyzerowanie bitu zwi¹zanego z klawiszem ctrl (2 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE1:
  CMP AL, 29+128 		;Zwolniony ctrl.
  JNE CONTINUE2
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 11111011B
  JMP TERMINATE
;Ustawienie bitu zwi¹zanego z klawiszem lewego shifta (1 bit w bajcie stanu ;odpowiada za ten przycisk):
  CONTINUE2:
  CMP AL, 42  			;Lewy Shift.
  JNE CONTINUE3
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 10B
  JMP TERMINATE
;Wyzerowanie bitu zwi¹zanego z klawiszem lewego shifta (2 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE3:
  CMP AL, 42+128 		;Lewy shift.
  JNE CONTINUE4
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 11111101B
  JMP TERMINATE
;Ustawienie bitu zwi¹zanego z klawiszem prawego shifta (0 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE4:
  CMP AL, 54   			;Prawy shift.
  JNE CONTINUE5
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 1B
  JMP TERMINATE
;Wyzerowanie bitu zwi¹zanego z klawiszem prawego shifta (0 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE5:
  CMP AL, 54+128 		;Prawy shift.
  JNE CONTINUE6
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 11111110B
  JMP TERMINATE
;Ustawienie bitu zwi¹zanego z klawiszem alt(3 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE6:
  CMP AL, 56  			;alt
  JNE CONTINUE7
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 1000B
  JMP TERMINATE
;Wyzerowanie bitu zwi¹zanego z klawiszem alt (3 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE7:
  CMP AL, 56+128 		;alt
  JNE CONTINUE8
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 11110111B
  JMP TERMINATE
;Ustawienie bitu zwi¹zanego z klawiszem scroll lock (4 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE8:
  CMP AL, 70  			;scroll lock
  JNE CONTINUE9
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 10000B
  JMP TERMINATE
;Wyzerowanie bitu zwi¹zanego z klawiszem scroll lock (4 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE9:
  CMP AL, 70+128 		;scroll lock
  JNE CONTINUE10
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 11101111B
  JMP TERMINATE
;Ustawienie bitu zwi¹zanego z klawiszem num lock (5 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE10:
  CMP AL, 69  			;num lock
  JNE CONTINUE11
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 100000B
  JMP TERMINATE
;Wyzerowanie bitu zwi¹zanego z klawiszem num lock (5 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE11:
  CMP AL, 69+128 		;num lock
  JNE CONTINUE12
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 11011111B
  JMP TERMINATE
;Prze³¹czenie bitu zwi¹zanego z klawiszem caps lock (6 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE12:
  CMP AL, 58  			;caps lock
  JNE CONTINUE13
    BTC WORD PTR [ES:BAJT_STANU_1_OFFSET], 6 ;negacja 6 bit
    CLC
  JMP TERMINATE
;Ustawienie bitu zwi¹zanego z klawiszem insert (7 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE13:
  CMP AL, 82  			;insert
  JNE CONTINUE15
    OR BYTE PTR [ES:BAJT_STANU_1_OFFSET], 10000000B
  JMP TERMINATE
;Wyzerowanie bitu zwi¹zanego z klawiszem insert (7 bit w bajcie stanu odpowiada za ten przycisk):
  CONTINUE15:
  CMP AL, 82+128 		;insert
  JNE CONTINUE16	
    AND BYTE PTR [ES:BAJT_STANU_1_OFFSET], 01111111B
  JMP TERMINATE
;Je¿eli kod klawisza zawarty w rejestrze AL jest kodem zwolnienia (tylko kody zwolnienia
;mog¹ osi¹gaæ wartoœci powy¿ej 128)  to nastêpuje skok do dalszej czêœci procedury.
  CONTINUE16:
  CMP AL, 128
  JA TERMINATE
;W przeciwnym razie nastêpuje wprowadzenie znaku do bufora:
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
;Zadaniem procedury jest zapisanie na odpowiedniej pozycji bufora klawiatury s³owa okreœlaj¹cego kod 
;matrycowy naciœniêtego klawisza, oraz jego odpowiednik ASCII (w przypadku, gdy klawisz nie ma 
;odpowiednika ASCII - zera).
  PUSH AX
  PUSH BX
  MOV BX, ES
  PUSH BX
  MOV BX, POLOZENIE_DESKRYPTORA_DANYCH_KLAWIATURY
  MOV ES, BX     			;Rejestr segmentowy es ³adowany selektorem danych klawiatury.
  MOV BL, [ES:WSKAZNIK_ZAPISU_OFFSET]   ;Do BL ³adowany wskaŸnik zapisu
                                        ;okreœlaj¹cy ostatnio zapisan¹ pozycjê w buforze klawiatury.
  MOV BH, [ES:WSKAZNIK_ODCZYTU_OFFSET]  ;Rejestr BH ³adowany wskaŸnikiem odczytu
                                        ;klawiatury, zawieraj¹cym pozycjê ostatnio odczytywan¹.
  INC BL        			;WskaŸnik zapisu zwiêkszany o 1 (ustawiana kolejna pozycja
                			;w³aœciwa do zapisu kodów matrycowych i ASCII).
  CMP BL, 32    			;Sprawdzany warunek, czy wskaŸnik zapisu nie przekracza
                			;wielkoœci bufora.
  JNE NEXT1
  XOR BL, BL  				;Je¿eli tak, nastêpuje zawiniecie adresu.
  NEXT1:
  CMP BL, BH    			;Sprawdzenie warunku, czy wskaŸnik odczytu nie pokrywa 
                			;siê z zaktualizowanym wskaŸnikiem zapisu.
  JNE NEXT
;Je¿eli pokrywaj¹ siê obie wartoœci, nale¿y przywróciæ wartoœæ wskaŸnika zapisu (zosta³ zwiêkszony, ale nie 
;mo¿e dojœæ do zapisu, gdy¿ bufor jest przepe³niony)
  CMP BL, 0 				;Je¿eli wskaŸnik zapisu ma wartoœæ 0, to przed aktualizacj¹
;musia³ mieæ wartoœæ 32.
  JNE NEXT2
  MOV BL, 32
  NEXT2:
  DEC BL
;Wywo³anie procedury (w przyk³adzie ksi¹¿kowym pustej), która mo¿e pos³u¿yæ do podjêcia pewnych 
;kroków maj¹cych na celu choæby poinformowanie u¿ytkownika o przepe³nionym buforze.
  CALL PRZEPELNIENIE_BUFORA_KLAWIATURY
  JMP KONIEC_WPR
  NEXT:
  AND BX, 0FFH  			;Rejestr BL zawiera wartoœæ wskaŸnika zapisu, nastêpuje
					;czyszczenie rejestru BH.
;Poni¿ej nastêpuje zapis kodu ASCII oraz kodu matrycowego (obie wartoœci przekazane procedurze w rejestrze BX)
;na odpowiedniej pozycji bufora klawiatury (BX mno¿ony razy 2, gdy¿ wskaŸnik zapisu ma za zadanie
;wskazywaæ s³owa w buforze, natomiast adresowanie odbywa siê w bajtach):
  PUSH BX
  SHL BX, 1
  MOV [ES:BX+BUFOR_OFFSET], AX 
;Uaktualnienie wartoœci wskaŸnika zapisu:
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
  CLI    			;Wy³¹czenie przerwañ, aby mieæ pewnoœæ, ¿e w trakcie wykonywania
       				;siê procedury nie nast¹pi do³o¿enie nowej pozycji do bufora.
  PUSH BX
  MOV BX, ES
  PUSH BX
  MOV BX, DS
  PUSH BX
  MOV BX, 8
  MOV DS, BX      		;Rejestr ds ³adowany selektorem segmentu danych.
  MOV BX, POLOZENIE_DESKRYPTORA_DANYCH_KLAWIATURY
  MOV ES, BX      		;Rejestr segmentowy ES ³adowany selektorem danych klawiatury.
  MOV BL, [ES:WSKAZNIK_ODCZYTU_OFFSET] ;Do BL ³adowany wskaŸnik odczytu
                                       ;okreœlaj¹cy ostatnio odczytywan¹ pozycjê bufora klawiatury.
  MOV BH, [ES:WSKAZNIK_ZAPISU_OFFSET]  ;Do BH ³adowany wskaŸnik zapisu
                                       ;okreœlaj¹cy ostatnio zapisywan¹ pozycjê w buforze klawiatury.
  INC BH        		;Inkrementacja wartoœci wskaŸnika zapisu umieszczonej w BH.
  CMP BH, 32    		;Sprawdzenie, czy aby nie jest wiêkszy od rozmiaru bufora.
  JNE CAS0
  XOR BH, BH  			;Je¿eli tak, adres jest zawijany.
  CAS0:
  INC BL        		;Ustawienie wskaŸnika odczytu na pierwsz¹ jeszcze
                		;nie odczytywan¹ pozycjê w buforze.
  CMP BL, 32    		;Sprawdzenie, czy wartoœæ wskaŸnika odczytu nie jest wiêksza
                		;od rozmiaru bufora klawiatury.
  JNE CAS1
  XOR BL, BL  			;Je¿eli wskaŸnik odczytu jest wiêkszy od rozmiaru bufora klawiatury
                		;nastêpuje zawiniêcie adresu.
  CAS1:
  CMP BL, BH    		;Sprawdzenie warunku, czy wskaŸnik odczytu nie pokrywa
                		;siê ze wskaŸnikiem zapisu (zwiêkszonym o 1).
  JNE CAS
;Je¿eli bufor jest pusty, do rejestru AX zapisywana jest wartoœæ 0.
  XOR AX, AX
  JMP ZAKONCZ_
  CAS:
;W BL znajduje siê numer pozycji bufora, któr¹ nale¿y odczytaæ. 
  AND BX, 0FFH
;Poni¿ej nastêpuje odczyt kodu ASCII oraz kodu matrycowego pierwszej jeszcze nie odczytywanej 
;pozycji bufora klawiatury (BX mno¿ony razy 2):
  PUSH BX
  SHL BX, 1
  MOV AX, [ES:BX+BUFOR_OFFSET]
;Uaktualnienie wartoœci wskaŸnika odczytu:
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
  MOV DS, AX    		;Rejestr DS ³adowany selektorem segmentu danych
;Odczyt kodu naciœniêcia (b¹dŸ zwolnienia) klawisza:
  SPRAWDZ_BUFOR_KLAWIATURY
  IN AL, 60H

;Dla niektórych klawiszy nie istniej¹ odpowiedniki ASCII, nale¿y wiêc wzi¹æ pod uwagê równie¿ ten warunek:
  CMP AL, 2
  JB INNE
  CMP AL, 82
  JA INNE
  XOR ESI, ESI
  MOVZX SI, AL  		;Rejestr indeksowy SI ³adowany jest
                 		;kodem matrycowym klawisza (odpowiednie kody ASCII
                 		;s¹ na pozycjach o numerze równym kodowi matrycowemu).
  MOV AH, 0    		
  CALL POBIERZ_LOKALNY_REJESTR_STANU_KLAWIATYRY
  TEST AH, 1000011B  		;Sprawdzenie, czy aby któryœ z przycisków
                      		;zmieniaj¹cych wielkoœæ liter nie jest trzymany
                      		;(gdy¿ zmieni to tablicê znaków, z której nast¹pi
                      		;dekodowanie kodu matrycowego na kod ASCII).
  JNZ WCISNIETY_SHIFT
;W przypadku, gdy ¿aden klawisz z: prawy shift, lewy shift, caps lock nie jest naciœniety, pobierany jest kod 
;ASCII z tablicy znaków KLAWISZE1.
  MOV AH, [KLAWISZE1+ SI]
  JMP CONT
  WCISNIETY_SHIFT:
;W przeciwnym razie nale¿y pobraæ odpowiedni kod ASCII z tablicy znaków KLAWISZE2.
  MOV AH, [KLAWISZE2+ SI]
  CONT:
  CMP AH, 0  			;W przypadku, gdy kod matrycowy nie ma swojego
              			;odpowiednika ASCII, zostanie wywo³ana procedura
              			;INNY_PRZYCISK.
  JNE DO_BUFORA
  INNE:
  MOV BL, 0
  CALL INNY_PRZYCISK
  JMP KONIEC_PRZERW1
  DO_BUFORA:
;Gdy klawisz ma powi¹zany z nim kod ASCII nastêpuje zapis zarówno kodu matrycowego (w AL) jak
;i kodu ASCII (w AH) do bufora klawiatury:
  CALL WPROWADZ_DO_BUFORA
  KONIEC_PRZERW1:
;Poni¿ej znajduje siê kod zwi¹zany z potwierdzeniem odbioru kodu matrycowego.
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

EXC_ PROC			;Procedura obs³ugi wyj¹tku nr 0.
  JMP _KONIEC_
EXC_ ENDP


EXC_13 PROC			;Procedura obs³ugi wyj¹tku nr 13.
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

