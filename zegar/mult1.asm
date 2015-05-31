.386P
WIELKOSC_ELEMENTU EQU 2  	;Rozmiar pola danych w elemencie kolejki.
STALA_KWANTU      EQU 20  	;Po ilu przerwaniach zegarowych nast¹pi prze³¹czenie zadañ.

INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
;Globalna tablica deskryptorów  (w komentarzach znajduj¹ siê selektory segmentów)
INCLUDE GDT.TXT
GDT_TSS_0	DESKR <103,0,0,89H>		;Selektor 40
;Poni¿szy deskryptor opisuje adres bazowy segmentów stosów dodawanych zadañ:
GDT_STOSY_Z  	DESKR <1000,0,0,92H,0,0>     	;Selektor 48
;Deskryptory opisuj¹ce TSS-y tworzonych zadañ:
GDT_TSS1      	DESKR <103,0,0,89H>         	;Selektor 56
GDT_TSS2     	DESKR <103,0,0,89H>       	;Selektor 64
GDT_TSS3      	DESKR <103,0,0,89H>       	;Selektor 72
GDT_TSS4   	DESKR <103,0,0,89H>       	;Selektor 80
GDT_TSS5     	DESKR <103,0,0,89H>       	;Selektor 88
GDT_TSS6    	DESKR <103,0,0,89H>       	;Selektor 96
GDT_TSS7    	DESKR <103,0,0,89H>          	;Selektor 104
GDT_TSS8     	DESKR <103,0,0,89H>          	;Selektor 112
GDT_TSS9   	DESKR <103,0,0,89H>          	;Selektor 120
;Deskryptor umo¿liwiaj¹cy modyfikacjê kodu:
GDT_ZAPIS_CS 	DESKR <PROGRAM_SIZE-1,,,92H> 	;Selektor 128
GDT_SIZE=$-GDT_NULL				;Rozmiar GDT
INCLUDE DANE.TXT
INFO2   		DB 'AKTYWNE ZADANIE NUMER ', 0
INFO3   		DB 'ZAD0   ZAD1   ZAD2   ZAD3   ZAD4   ZAD5   ZAD6   ZAD7   ZAD8   ZAD9', 0
              	
DANE_SIZE=$-GDT_NULL			;Rozmiar segmentu danych.
DANE	ENDS

PROGRAM	SEGMENT 'CODE' USE16
ASSUME CS:PROGRAM,DS:DANE
BEGIN	LABEL WORD

INCLUDE MAKRA.TXT

MAIN	PROC
  INCLUDE KOD.TXT
  MOV CX, 10
  CALL INICJUJ_PULE_DYNAMICZNA
  MOV AX, 40                       	;Selektor TSS zadania g³ównego.
  CALL DODAJ_ZADANIE_DO_KOLEJKI_ZADAN	;Dodanie zadania g³ównego do kolejki zadañ.
  MOV BYTE PTR INT_ON, 1             	;Ustawienie zmiennej informuj¹cej,
                                        ;¿e wielozadaniowoœæ zosta³a zainicjowana.
;Poni¿ej nastêpuje wypisanie tekstu:  'ZAD0   ZAD1   ZAD2   ZAD3   ZAD4   ZAD5   ZAD6   ZAD7   ZAD8   ZAD9'
  XOR DI, DI
  MOV BX, OFFSET INFO3
  MOV DL, ' '
  PM_WYPISZ_TEKST_I_DL
;Pozostawienie tylko pierwszego napisu (ZAD0):
  MOV DL, '0'
  ZNACZ_ELEMENT
;Poni¿sza pêtla cyklicznie wypisuje na ekranie informacje o tym, ¿e aktualnie 
;wykonuje siê zadanie g³ówne (ZAD0):
  PROGRAM_DZIALA_DALEJ:
    ZNACZ_ELEMENT        
    MOV BX, OFFSET INFO2
    MOV DI, 2*80
    PM_WYPISZ_TEKST_I_DL        
    MOV AL, 0         
    MOV AH, CZY_MOZNA_KONCZYC
    CMP AL, AH
  JE PROGRAM_DZIALA_DALEJ
  MIEKI_POWROT_RM
  MOV AX,STK
  MOV SS,AX
  MOV SP,200
  KONTROLER_PRZERWAN_RM
;Przywrócenie w³aœciwego stanu rejestru IDTR:
  POWROT_DO_RM 0,1
MAIN	ENDP

;Procedura wykonywana w zadaniu nr 1:
ZADANIE PROC
  MOV AX, 8
  MOV DS, AX
;Poni¿sza pêtla cyklicznie wypisuje informacje o aktualnie dzia³aj¹cym
;zadaniu (na podstawie zawartoœci rejestru DL)
  ZADANIE_PETLA:
    ZNACZ_ELEMENT  		;Wyœwietlenie w³aœciwego elementu w pierwszej linii ekranu.
    MOV BX, OFFSET INFO2
    MOV DI, 2*80
    PM_WYPISZ_TEKST_I_DL 	;Wypisanie tekstu z numerem zadania.
  JMP ZADANIE_PETLA
ZADANIE ENDP

INCLUDE PROC.TXT

INCLUDE MULT.TXT

PRZERWANIE1 PROC
  ZACHOWAJ_REG 1
;Odczyt kodu naciœniêcia (b¹dŸ zwolnienia) klawisza:
  SPRAWDZ_BUFOR_KLAWIATURY
  IN AL, 60H
  TEST AL, 10000000B
  JNZ PRZERWANIE_1_DALEJ 	;Gdy odczytana wartoœæ wskazuje na to, ¿e przycisk klawiatury
                              	;zosta³ zwolniony, nastêpuje skok do dalszej czêœci kodu.
  MOV AL, LICZNIK_ZADAN  	;Odczyt zmiennej przechowuj¹cej iloœæ uruchomionych zadañ.
  CMP AL, 9               	;Gdy jest ich 9, to podejmowane s¹ czynnoœci zwi¹zane
                              	; z zakoñczeniem programu
  JB MOZNA_DODAC_ZADANIE
  MOV BYTE PTR CZY_MOZNA_KONCZYC, 1 ;Ustawienie zmiennej spowoduje zakoñczenie programu 
;zaraz po tym jak scheduler przeka¿e procesor zadaniu g³ównemu.
  JMP PRZERWANIE_1_DALEJ       
  MOZNA_DODAC_ZADANIE:       
  CALL URUCHOM_KOLEJNE_ZADANIE	;Uruchomienie kolejnego zadania.
  PRZERWANIE_1_DALEJ:
  IN AL, 61H        		;Odczyt bajtu z portu 61h.
  OR AL, 10000000B  		; Suma logiczna otrzymanego bajtu
                    		;z ustawionym najstarszym bitem .
  OUT 61H, AL       		
  AND AL, 7FH       		
  OUT 61H, AL       		
  MOV AL, 61H    
  OUT 20H, AL   
  PRZYWROC_REG 1
  IRETD
PRZERWANIE1 ENDP

;Procedura obs³ugi przerwania zegarowego- scheduler:
PRZERWANIE0 PROC
  ZACHOWAJ_REG 1
  CMP BYTE PTR INT_ON, 0 	;Je¿eli wielozadaniowoœæ nie jest aktywowana, to 
                    		;nie mo¿na pozwoliæ na wykonanie siê tej procedury.
  JNE WIELOZADANIOWOSC_JEST_AKTYWOWANA 
  JMP KONIEC_PRZERWANIE_0 
  WIELOZADANIOWOSC_JEST_AKTYWOWANA: 
  MOV AL, LICZNIK_TYKOW 	;Pobranie zmiennej przechowuj¹cej iloœæ wywo³añ
                                ;przerwania zegarowego.		
  INC BYTE PTR LICZNIK_TYKOW ;Inkrementacja jej wartoœci.
  CMP AL, STALA_KWANTU    	;Porównanie ze sta³¹ okreœlaj¹c¹ iloœæ przerwañ
                                ;zegarowych do prze³¹czenia zadañ.
  JA ODPOWIEDNI_CZAS_NA_PRZELACZENIE ;Je¿eli aktualna wartoœæ jest od niej wiêksza
                                     ;nale¿y prze³¹czyæ zadania.
  MOV AL, 60H            	;Je¿eli jeszcze nie czas na prze³¹czenie,
                                ;nale¿y wys³aæ do kontrolera przerwañ informacje
                                ;o obs³u¿onym przerwaniu.
  OUT 20H, AL
  JMP NIE_MOZNA_PRZELACZYC_ZADAN_ 
  ODPOWIEDNI_CZAS_NA_PRZELACZENIE: 
  MOV BYTE PTR LICZNIK_TYKOW, 0 ;Wyzerowanie zmiennej przechowuj¹cej iloœæ
                                ;wywo³añ przerwania zegarowego
;Pobieranie selektora TSS aktualnie wykonuj¹cego siê zadania:
  MOV BX, OFFSET KOLEJKA_ZADAN
  CALL ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA
;Rotacja kolejki zadañ:
  CALL PRZELACZ_ZADANIA 
;Rejestr DI zawiera selektor TSS zadania ustawionego na pierwszej pozycji kolejki zadañ dziêki 
;zastosowaniu procedury  PRZELACZ_ZADANIA, natomiast CX zawiera selektor TSS  obecnego 
;zadania (zwrócony z procedury  ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA).
;Je¿eli oba te selektory s¹ identyczne (na przyk³ad gdy jest tylko jedno zadanie) to nie mo¿na 
;pozwoliæ na dalsze wykonywanie siê procedury - w Intelowskiej architekturze rekursywne 
;wywo³ywanie siê zadañ jest niedozwolone.
  CMP CX, DI 
  JNE ZADANIA_SA_ROZNE 
;Wys³anie do kontrolera przerwañ informacji o zakoñczeniu obs³ugi przerwania:
  MOV AL, 60H
  OUT 20H, AL
  JMP NIE_MOZNA_PRZELACZYC_ZADAN_ 	
  ZADANIA_SA_ROZNE:            
;Poni¿sza sekwencja rozkazów wykona siê w przypadku, gdy zadania s¹ ró¿ne.
;Aby prze³¹czyæ zadania potrzebny jest selektor TSS nowego zadania, na które ma nast¹piæ 
;prze³¹czenie - czyli wartoœæ, która znajduje siê obecnie w rejestrze DI. Nale¿y zmodyfikowaæ 
;wartoœæ selektora TSS w instrukcji skoku odleg³ego (nast¹pi prze³¹czenie 
;na w³aœciwe zadanie). Instrukcja skoku odleg³ego zosta³a zapisana w formie 
;maszynowej, by móc zmieniaæ dynamicznie jej parametr zawieraj¹cy selektor TSS.
;Do zmiany tego parametru nale¿a³o przygotowaæ pseudonim deskryptora opisuj¹cego segment kodu
;(nie mo¿na korzystaæ z rejestru CS, gdy¿ zawartoœci segmentu kodu nie mo¿na modyfikowaæ).
  MOV AX, 128        
  MOV GS, AX    
  MOV [GS:_SELEKTOR_], DI   
  KONIEC_PRZERWANIE_0:    
;Wys³anie do kontrolera przerwañ informacji o tym, ¿e obs³uga obecnego przerwania
;zosta³a zakoñczona:
  MOV AL, 60H  
  OUT 20H, AL  	
  CMP BYTE PTR INT_ON, 0    
  JE PRZERWANIE_ZEGARA_DALEJ2    
;Prze³¹czenie na nowe zadanie:
    POLECENIE       	DB 0EAH         
    OFFSET_         	DW 12            
    _SELEKTOR_      	DW 40H
  PRZERWANIE_ZEGARA_DALEJ2: 
  NIE_MOZNA_PRZELACZYC_ZADAN_: 
  PRZYWROC_REG 1
  IRETD  
PRZERWANIE0 ENDP

PRZYGOTUJ_NASTEPNE_ZADANIE PROC
;Obliczenie adresu TSS dla dok³adanego zadania:
  MOV DI, OFFSET TSSY_ZADAN 
  XOR AX, AX
  XOR DX, DX
  MOV BX, 104
  MOV AL, LICZNIK_ZADAN  
  MUL BX
  ADD DI, AX 
  INC BYTE PTR LICZNIK_ZADAN 	;Inkrementowana zmienna przechowuj¹ca 
				;liczbê uruchomionych  procesów. 
  MOV WORD PTR [DS:DI+4CH],16 	;Selektor segmentu programu (CS).
  MOV WORD PTR [DS:DI+20H],OFFSET ZADANIE ;Offset w segmencie progr.
  MOV WORD PTR [DS:DI+50H],48 	;Selektor segmentu stosu (SS).
;Jako, ¿e segment stosu jest dla wszystkich zadañ jednakowy, nale¿y ustawiæ ró¿ne szczyty stosu. 
;Ka¿de kolejne zadanie bêdzie posiada³o wartoœæ esp zwiêkszon¹ o 100:
  XOR AX, AX
  XOR DX,DX
  MOV AL, LICZNIK_ZADAN
  MOV BX, 100 
  MUL BX
  MOV WORD PTR [DS:DI+38H], AX	;Offset w segmencie stosu.
  MOV WORD PTR [DS:DI+54H], 8	;Selektor segmentu danych (DS).
  MOV WORD PTR [DS:DI+48H], 32	;Selektor segmentu danych (ES).
  MOV DWORD PTR [DS:DI+36], 00000000000000000000001000000000B   
;eflags z ustawionym if.
  MOV DL, LICZNIK_ZADAN  	;W rejestrze DL ka¿de zadanie otrzyma znak - odpowiednik
                               	;ASCII numeru porz¹dkowego zadania.
  ADD DL, '0' 
  MOV DWORD PTR [DS:DI+48], EDX 
  RET 
PRZYGOTUJ_NASTEPNE_ZADANIE ENDP

URUCHOM_KOLEJNE_ZADANIE PROC
  CALL  PRZYGOTUJ_NASTEPNE_ZADANIE ;Przygotowanie TSS zadania.
;Okreœlenie selektora TSS dla aktualnie dok³adanego zadania:
  XOR AX, AX
  MOV AL, LICZNIK_ZADAN 
  DEC AL
  XOR DX, DX 
  MOV BX, 8 
  MUL BX 
  ADD AX, 56 
  CALL DODAJ_ZADANIE_DO_KOLEJKI_ZADAN 
  RET 
URUCHOM_KOLEJNE_ZADANIE ENDP


PROGRAM_SIZE=$-BEGIN
PROGRAM	ENDS

STK	SEGMENT STACK 'STACK'
  DB 256 DUP (0)
STK	ENDS

STOSY_ZADAN SEGMENT
  DB 1000 DUP (0)
STOSY_ZADAN ENDS
END	MAIN

