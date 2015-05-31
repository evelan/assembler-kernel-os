.386P
WIELKOSC_ELEMENTU EQU 2  	;Rozmiar pola danych w elemencie kolejki.
STALA_KWANTU      EQU 20  	;Po ilu przerwaniach zegarowych nast�pi prze��czenie zada�.

INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
;Globalna tablica deskryptor�w  (w komentarzach znajduj� si� selektory segment�w)
INCLUDE GDT.TXT
GDT_TSS_0	DESKR <103,0,0,89H>		;Selektor 40
;Poni�szy deskryptor opisuje adres bazowy segment�w stos�w dodawanych zada�:
GDT_STOSY_Z  	DESKR <1000,0,0,92H,0,0>     	;Selektor 48
;Deskryptory opisuj�ce TSS-y tworzonych zada�:
GDT_TSS1      	DESKR <103,0,0,89H>         	;Selektor 56
GDT_TSS2     	DESKR <103,0,0,89H>       	;Selektor 64
GDT_TSS3      	DESKR <103,0,0,89H>       	;Selektor 72
GDT_TSS4   	DESKR <103,0,0,89H>       	;Selektor 80
GDT_TSS5     	DESKR <103,0,0,89H>       	;Selektor 88
GDT_TSS6    	DESKR <103,0,0,89H>       	;Selektor 96
GDT_TSS7    	DESKR <103,0,0,89H>          	;Selektor 104
GDT_TSS8     	DESKR <103,0,0,89H>          	;Selektor 112
GDT_TSS9   	DESKR <103,0,0,89H>          	;Selektor 120
;Deskryptor umo�liwiaj�cy modyfikacj� kodu:
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
  MOV AX, 40                       	;Selektor TSS zadania g��wnego.
  CALL DODAJ_ZADANIE_DO_KOLEJKI_ZADAN	;Dodanie zadania g��wnego do kolejki zada�.
  MOV BYTE PTR INT_ON, 1             	;Ustawienie zmiennej informuj�cej,
                                        ;�e wielozadaniowo�� zosta�a zainicjowana.
;Poni�ej nast�puje wypisanie tekstu:  'ZAD0   ZAD1   ZAD2   ZAD3   ZAD4   ZAD5   ZAD6   ZAD7   ZAD8   ZAD9'
  XOR DI, DI
  MOV BX, OFFSET INFO3
  MOV DL, ' '
  PM_WYPISZ_TEKST_I_DL
;Pozostawienie tylko pierwszego napisu (ZAD0):
  MOV DL, '0'
  ZNACZ_ELEMENT
;Poni�sza p�tla cyklicznie wypisuje na ekranie informacje o tym, �e aktualnie 
;wykonuje si� zadanie g��wne (ZAD0):
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
;Przywr�cenie w�a�ciwego stanu rejestru IDTR:
  POWROT_DO_RM 0,1
MAIN	ENDP

;Procedura wykonywana w zadaniu nr 1:
ZADANIE PROC
  MOV AX, 8
  MOV DS, AX
;Poni�sza p�tla cyklicznie wypisuje informacje o aktualnie dzia�aj�cym
;zadaniu (na podstawie zawarto�ci rejestru DL)
  ZADANIE_PETLA:
    ZNACZ_ELEMENT  		;Wy�wietlenie w�a�ciwego elementu w pierwszej linii ekranu.
    MOV BX, OFFSET INFO2
    MOV DI, 2*80
    PM_WYPISZ_TEKST_I_DL 	;Wypisanie tekstu z numerem zadania.
  JMP ZADANIE_PETLA
ZADANIE ENDP

INCLUDE PROC.TXT

INCLUDE MULT.TXT

PRZERWANIE1 PROC
  ZACHOWAJ_REG 1
;Odczyt kodu naci�ni�cia (b�d� zwolnienia) klawisza:
  SPRAWDZ_BUFOR_KLAWIATURY
  IN AL, 60H
  TEST AL, 10000000B
  JNZ PRZERWANIE_1_DALEJ 	;Gdy odczytana warto�� wskazuje na to, �e przycisk klawiatury
                              	;zosta� zwolniony, nast�puje skok do dalszej cz�ci kodu.
  MOV AL, LICZNIK_ZADAN  	;Odczyt zmiennej przechowuj�cej ilo�� uruchomionych zada�.
  CMP AL, 9               	;Gdy jest ich 9, to podejmowane s� czynno�ci zwi�zane
                              	; z zako�czeniem programu
  JB MOZNA_DODAC_ZADANIE
  MOV BYTE PTR CZY_MOZNA_KONCZYC, 1 ;Ustawienie zmiennej spowoduje zako�czenie programu 
;zaraz po tym jak scheduler przeka�e procesor zadaniu g��wnemu.
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

;Procedura obs�ugi przerwania zegarowego- scheduler:
PRZERWANIE0 PROC
  ZACHOWAJ_REG 1
  CMP BYTE PTR INT_ON, 0 	;Je�eli wielozadaniowo�� nie jest aktywowana, to 
                    		;nie mo�na pozwoli� na wykonanie si� tej procedury.
  JNE WIELOZADANIOWOSC_JEST_AKTYWOWANA 
  JMP KONIEC_PRZERWANIE_0 
  WIELOZADANIOWOSC_JEST_AKTYWOWANA: 
  MOV AL, LICZNIK_TYKOW 	;Pobranie zmiennej przechowuj�cej ilo�� wywo�a�
                                ;przerwania zegarowego.		
  INC BYTE PTR LICZNIK_TYKOW ;Inkrementacja jej warto�ci.
  CMP AL, STALA_KWANTU    	;Por�wnanie ze sta�� okre�laj�c� ilo�� przerwa�
                                ;zegarowych do prze��czenia zada�.
  JA ODPOWIEDNI_CZAS_NA_PRZELACZENIE ;Je�eli aktualna warto�� jest od niej wi�ksza
                                     ;nale�y prze��czy� zadania.
  MOV AL, 60H            	;Je�eli jeszcze nie czas na prze��czenie,
                                ;nale�y wys�a� do kontrolera przerwa� informacje
                                ;o obs�u�onym przerwaniu.
  OUT 20H, AL
  JMP NIE_MOZNA_PRZELACZYC_ZADAN_ 
  ODPOWIEDNI_CZAS_NA_PRZELACZENIE: 
  MOV BYTE PTR LICZNIK_TYKOW, 0 ;Wyzerowanie zmiennej przechowuj�cej ilo��
                                ;wywo�a� przerwania zegarowego
;Pobieranie selektora TSS aktualnie wykonuj�cego si� zadania:
  MOV BX, OFFSET KOLEJKA_ZADAN
  CALL ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA
;Rotacja kolejki zada�:
  CALL PRZELACZ_ZADANIA 
;Rejestr DI zawiera selektor TSS zadania ustawionego na pierwszej pozycji kolejki zada� dzi�ki 
;zastosowaniu procedury  PRZELACZ_ZADANIA, natomiast CX zawiera selektor TSS  obecnego 
;zadania (zwr�cony z procedury  ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA).
;Je�eli oba te selektory s� identyczne (na przyk�ad gdy jest tylko jedno zadanie) to nie mo�na 
;pozwoli� na dalsze wykonywanie si� procedury - w Intelowskiej architekturze rekursywne 
;wywo�ywanie si� zada� jest niedozwolone.
  CMP CX, DI 
  JNE ZADANIA_SA_ROZNE 
;Wys�anie do kontrolera przerwa� informacji o zako�czeniu obs�ugi przerwania:
  MOV AL, 60H
  OUT 20H, AL
  JMP NIE_MOZNA_PRZELACZYC_ZADAN_ 	
  ZADANIA_SA_ROZNE:            
;Poni�sza sekwencja rozkaz�w wykona si� w przypadku, gdy zadania s� r�ne.
;Aby prze��czy� zadania potrzebny jest selektor TSS nowego zadania, na kt�re ma nast�pi� 
;prze��czenie - czyli warto��, kt�ra znajduje si� obecnie w rejestrze DI. Nale�y zmodyfikowa� 
;warto�� selektora TSS w instrukcji skoku odleg�ego (nast�pi prze��czenie 
;na w�a�ciwe zadanie). Instrukcja skoku odleg�ego zosta�a zapisana w formie 
;maszynowej, by m�c zmienia� dynamicznie jej parametr zawieraj�cy selektor TSS.
;Do zmiany tego parametru nale�a�o przygotowa� pseudonim deskryptora opisuj�cego segment kodu
;(nie mo�na korzysta� z rejestru CS, gdy� zawarto�ci segmentu kodu nie mo�na modyfikowa�).
  MOV AX, 128        
  MOV GS, AX    
  MOV [GS:_SELEKTOR_], DI   
  KONIEC_PRZERWANIE_0:    
;Wys�anie do kontrolera przerwa� informacji o tym, �e obs�uga obecnego przerwania
;zosta�a zako�czona:
  MOV AL, 60H  
  OUT 20H, AL  	
  CMP BYTE PTR INT_ON, 0    
  JE PRZERWANIE_ZEGARA_DALEJ2    
;Prze��czenie na nowe zadanie:
    POLECENIE       	DB 0EAH         
    OFFSET_         	DW 12            
    _SELEKTOR_      	DW 40H
  PRZERWANIE_ZEGARA_DALEJ2: 
  NIE_MOZNA_PRZELACZYC_ZADAN_: 
  PRZYWROC_REG 1
  IRETD  
PRZERWANIE0 ENDP

PRZYGOTUJ_NASTEPNE_ZADANIE PROC
;Obliczenie adresu TSS dla dok�adanego zadania:
  MOV DI, OFFSET TSSY_ZADAN 
  XOR AX, AX
  XOR DX, DX
  MOV BX, 104
  MOV AL, LICZNIK_ZADAN  
  MUL BX
  ADD DI, AX 
  INC BYTE PTR LICZNIK_ZADAN 	;Inkrementowana zmienna przechowuj�ca 
				;liczb� uruchomionych  proces�w. 
  MOV WORD PTR [DS:DI+4CH],16 	;Selektor segmentu programu (CS).
  MOV WORD PTR [DS:DI+20H],OFFSET ZADANIE ;Offset w segmencie progr.
  MOV WORD PTR [DS:DI+50H],48 	;Selektor segmentu stosu (SS).
;Jako, �e segment stosu jest dla wszystkich zada� jednakowy, nale�y ustawi� r�ne szczyty stosu. 
;Ka�de kolejne zadanie b�dzie posiada�o warto�� esp zwi�kszon� o 100:
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
  MOV DL, LICZNIK_ZADAN  	;W rejestrze DL ka�de zadanie otrzyma znak - odpowiednik
                               	;ASCII numeru porz�dkowego zadania.
  ADD DL, '0' 
  MOV DWORD PTR [DS:DI+48], EDX 
  RET 
PRZYGOTUJ_NASTEPNE_ZADANIE ENDP

URUCHOM_KOLEJNE_ZADANIE PROC
  CALL  PRZYGOTUJ_NASTEPNE_ZADANIE ;Przygotowanie TSS zadania.
;Okre�lenie selektora TSS dla aktualnie dok�adanego zadania:
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

