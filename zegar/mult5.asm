.386P
WIELKOSC_ELEMENTU EQU 2  	;Wielkoœæ pola danych w elemencie kolejki.
STALA_KWANTU      EQU 1  	;Po ilu przerwaniach zegarowych nast¹pi zmiana zadañ.

INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
INCLUDE GDT.TXT
GDT_TSS_0	DESKR <103,0,0,89H>		;Selektor 40
;Poni¿szy deskryptor opisuje adres bazowy stosów dodawanych zadañ:
GDT_STOSY_Z  	DESKR <1000,0,0,92H,0,0>     	;Selektor 48
;Deskryptory opisuj¹ce TSS-y tworzonych zadañ:
GDT_TSS1      	DESKR <103,0,0,89H>         	;Selektor 56
GDT_TSS2     	DESKR <103,0,0,89H>       	;Selektor 64
GDT_TSS3      	DESKR <103,0,0,89H>       	;Selektor 72
GDT_TSS4   	DESKR <103,0,0,89H>       	;Selektor 80
GDT_TSS5     	DESKR <103,0,0,89H>       	;Selektor 88
;Deskryptor umo¿liwiaj¹cy modyfikacjê kodu:
GDT_ZAPIS_CS 	DESKR <PROGRAM_SIZE-1,,,92H> 	;Selektor 96
GDT_SIZE=$-GDT_NULL				;Rozmiar GDT
;Tablica deskryptorów przerwañ:
IDT	LABEL WORD				;Pocz¹tek IDT
  TRAP 	32 	DUP(<EXC_>)
  INTR  <PRZERWANIE0>
  INTR  <PRZERWANIE1>
  INTR  <USLUGA_WYPISYWANIA_TEKSTU>             ;INT 34
  INTR  <USLUGA_WYPISYWANIA_ZNAKU_NA_EKRANIE>   ;INT 35
IDT_SIZE=$-IDT				;ROZMIAR TABLICY IDT
INCLUDE DANE.TXT
EKRAN_   	URZADZENIE 	<>
KURSOR   	POLOZENIE_KURSORA <>
INFO2   		DB '              AKTYWNE ZADANIE NUMER ', 0
TASK0_OFFS	DW	0		;4-bajtowy adres dla prze³¹czenia
TASK0_SEL	DW	48		;na zadanie 0 przez TSS.
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
  MOV BYTE PTR INT_ON, 1             	;Ustawienie zmiennej informuj¹cej o tym,
                                        ;¿e wielozadaniowoœæ zosta³a zainicjowana.
;Rejestr CX zawiera liczbê zadañ do utworzenia.
  MOV CX, 5  
  PETLA_DODAWANIA_ZADAN:  
    CALL URUCHOM_KOLEJNE_ZADANIE  
  LOOP PETLA_DODAWANIA_ZADAN   
  MOV DL, '0'     
  MOV DI, OFFSET INFO2    
  MOV AX, 8      
  MOV ES, AX    
  PROGRAM_DZIALA_DALEJ:    
    INT 34   
    INT 35   
    MOV CX, 0FFFFH   
    PETLA_SPOWOLNIANIA0:   
      INC AX    
      DEC AX   
      INC AX      
      DEC AX     
    LOOP PETLA_SPOWOLNIANIA0  
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

ZADANIE	PROC
  MOV AX, 8   
  MOV DS, AX  
  MOV ES, AX  
  MOV DI, OFFSET INFO2 
  ZADANIE_PETLA: 
    INT 34  
    INT 35  
    MOV CX, 0FFFFH 
    PETLA_SPOWOLNIANIA:  
      INC AX     
      DEC AX    
      INC AX   
      DEC AX   
    LOOP PETLA_SPOWOLNIANIA 
  JMP ZADANIE_PETLA  
ZADANIE	ENDP

INCLUDE PROC.TXT

INCLUDE MULT.TXT


PRZERWANIE1 PROC
  ZACHOWAJ_REG 1
  SPRAWDZ_BUFOR_KLAWIATURY
  IN AL, 60H
  AND AL, 10000000B       	;Gdy odczytana wartoœæ wskazuje na to, ¿e przycisk
                                ;klawiatury zosta³ zwolniony, to nastêpuje skok do
                                ;dalszej czêœci kodu.
  CMP AL, 0   
  JNE PRZERWANIE1_DALEJ 
  MOV BYTE PTR CZY_MOZNA_KONCZYC, 1 ; Ustawienie zmiennej spowoduje wyjœcie z
                                     ;programu po powrocie do zadania g³ównego.
  PRZERWANIE1_DALEJ: 
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
  MOV AL, 60H            	;Je¿eli jeszcze nie nadszed³ czas na prze³¹czenie,
                                ;nale¿y wys³aæ do kontrolera przerwañ informacjê
                                ;o obs³u¿onym przerwaniu.
  OUT 20H, AL
  JMP NIE_MOZNA_PRZELACZYC_ZADAN_ 
  ODPOWIEDNI_CZAS_NA_PRZELACZENIE: 
  MOV BYTE PTR LICZNIK_TYKOW, 0 ;Wyzerowanie zmiennej przechowuj¹cej iloœæ
                                         			;wywo³añ przerwania zegarowego
;Pobierany jest selektor TSS aktualnie wykonuj¹cego siê zadania:
  MOV BX, OFFSET KOLEJKA_ZADAN
  CALL ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA
;Rotacja kolejki zadañ:
  CALL PRZELACZ_ZADANIA 
;Rejestr DI zawiera selektor TSS zadania ustawionego na pierwszej pozycji kolejki zadañ dziêki 
;zastosowaniu procedury  PRZELACZ_ZADANIA, natomiast CX zawiera selektor  TSS  obecnego 
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
;maszynowej, by móc zmieniaæ dynamicznie jej parametr wskazuj¹cy selektor TSS.
;Do zmiany tego parametru nale¿a³o przygotowaæ deskryptor opisuj¹cy segment kodu
;(nie mo¿na korzystaæ z rejestru CS, gdy¿ zawartoœci segmentu kodu nie mo¿na modyfikowaæ).
  MOV AX, 96
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
;Obliczenie adresu TSS dla dodawanego zadania:
  MOV DI, OFFSET TSSY_ZADAN 
  XOR AX, AX
  XOR DX, DX
  MOV BX, 104
  MOV AL, LICZNIK_ZADAN  
  MUL BX
  ADD DI, AX 
  INC BYTE PTR LICZNIK_ZADAN ;Inkrementowana zmienna przechowuj¹ca 
			     ;liczbê uruchomionych  zadañ. 
  MOV WORD PTR [DS:DI+4CH],16 ;Selektor segmentu programu (CS).
  MOV WORD PTR [DS:DI+20H],OFFSET ZADANIE ;Offset w segmencie progr.
  MOV WORD PTR [DS:DI+50H],48 ;Selektor segmentu stosu (SS).
;Jako, ¿e segment stosu jest dla wszystkich zadañ wspólny, nale¿y ustawiæ im inne szczyty stosu. 
;Ka¿de kolejne zadanie bêdzie posiada³o wartoœæ ESP zwiêkszon¹ o 100:
  XOR AX, AX
  XOR DX,DX
  MOV AL, LICZNIK_ZADAN
  MOV BX, 200 
  MUL BX
  MOV WORD PTR [DS:DI+38H], AX	;Offset w segmencie stosu.
  MOV WORD PTR [DS:DI+54H], 8	;Selektor segmentu danych (DS).
  MOV WORD PTR [DS:DI+48H], 32	;Selektor segmentu danych (ES).
  MOV DWORD PTR [DS:DI+36], 00000000000000000000001000000000B   ;EFLAGS z ustawionym IF.
  MOV DL, LICZNIK_ZADAN  	;W rejestrze DL ka¿de zadanie otrzyma znak - odpowiednik
                               	;ASCII numeru porz¹dkowego zadania.
  ADD DL, '0' 
  MOV DWORD PTR [DS:DI+48], EDX 
  RET 
PRZYGOTUJ_NASTEPNE_ZADANIE ENDP

URUCHOM_KOLEJNE_ZADANIE PROC
  CALL  PRZYGOTUJ_NASTEPNE_ZADANIE ;Przygotowanie TSS zadania.
;Okreœlenie selektora TSS dla aktualnie dodawanego zadania:
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;OBSLUGA EKRANU
LINIA_W_DOL PROC
  PUSHA     
  MOV AX, DS   
  PUSH AX        
  MOV AX, ES     
  PUSH AX      
  MOV AX, 32     
  MOV DS, AX   		;DS ³adowany selektorem segmentu ekranu.
  MOV ES, AX   		;ES ³adowany selektorem segmentu ekranu.
  XOR DI, DI  		;ES:DI wskazuje na pocz¹tek obszaru pamiêci trybu tekstowego.
  MOV SI, 80*2 		;DS:SI wskazuje na pierwszy wiersz trybu tekstowego (za³ó¿my numeracjê wierszy  od zera).
;Skopiowanie pamiêci zawieraj¹cej 24 ostatnie wiersze pod adres pocz¹tku trybu tekstowego
; Dziêki temu nastêpuje przekopiowanie wszystkich znaków na ekranie o jeden wiersz wy¿ej.
  MOV CX, 80*24   
  REP MOVSW   
  MOV AH, 0FH  
;Wyczyszczenie ostatniego wiersza (wpisanie do obszaru pamiêci zajmowanego przez niego spacji).
  MOV AL, ' '    
  MOV DI, 80*24*2     
  MOV CX, 80    
  REP STOSW     
  POP AX    
  MOV ES, AX      
  POP AX   
  MOV DS, AX           
  POPA        
  RET      
LINIA_W_DOL ENDP

WYSWIETL_ZNAK PROC
;Parametry procedury:
;DL - kod ASCII znaku.
  PUSHA    
  MOV AX, ES          
  PUSH AX      
  MOV AX, DS   
  PUSH AX    
  MOV AX, 8     
  MOV DS, AX    		;Za³adowanie DS selektorem segmentu danych systemu.
  MOV AX, 32    
  MOV ES, AX    		;Za³adowanie ES selektorem segmentu ekranu.
  XOR DI, DI  			;ES:DI wskazuj¹ na pocz¹tek obszaru pamiêci zajmowanego przez tryb tekstowy.
;Aby uzyskaæ przesuniêcie aktualnej pozycji na ekranie, nale¿y pomno¿yæ numer wiersza * 80 (iloœæ kolumn 
;znajduj¹cych siê w ka¿dym wierszu) a do uzyskanego wyniku nale¿y dodaæ numer kolumny, 
;w której znajduje siê kursor:
  MOV AX, 80   
  MUL BYTE PTR KURSOR.Y   
  MOV BL, KURSOR.X     
  MOVZX BX, BL    
  ADD AX, BX    
  CMP AX, 80*24   
  JB POL_MNIEJSZE     
;Je¿eli kursor znajduje siê w przedostatnim wierszu, w ostatniej kolumnie,  nastêpuje przesuniêcie strony 
;o jeden wiersz w dó³:
  CALL LINIA_W_DOL  
  SUB BYTE PTR KURSOR.Y, 1 ;Aktualizacja zmiennej wskazuj¹cej wiersz w którym znajduje siê kursor.
  SUB AX, 80       		;Zmniejszenie wczeœniej obliczonego adresu o 80 (jeden wiersz do góry).
  POL_MNIEJSZE: 
  PUSH AX
  SHL AX, 1 			;Razy 2, aby zamiast przesuniêcia kursora otrzymaæ adres bajtu.
  ADD DI, AX   			;Do adresu obszaru trybu tekstowego dodawane jest przesuniêcie
                  		;wskazuj¹ce na aktualn¹ pozycjê, w której nale¿y umieœciæ znak (tam
                  		;gdzie stoi kursor).
  MOV [ES:DI], DL 		;Zapisanie znaku pod tym adresem.
  INC DI          		;Nastêpny bajt zawiera atrybut znaku.
  MOV AL, 0FH    
  MOV [ES:DI], AL      		;Zapisanie  atrybutu na w³aœciwej pozycji.
  POP AX      
  INC AX      			;Zwiêkszenie o 1 rejestru AX - otrzymujemy now¹ pozycjê kursora.
  PUSH AX    			;Zachowanie rejestru AX (w AX znajduje siê s³owo opisuj¹ce
               			;now¹ pozycjê kursora).
;Obliczenie kolumny i wiersza, w którym ma staæ kursor:
  MOV BL, 80   
  DIV BL   
  MOV KURSOR.Y, AL   		;Zachowanie wiersza.
  MOV KURSOR.X, AH   		;Zachowanie kolumny.
  POP AX  			;W rejestrze AX znajduje siê nowa pozycja kursora, na której 
;nale¿y go ustawiæ,
;Wywo³anie procedury, maj¹cej za zadanie w³aœciwe ustawienie kursora na ekranie:
  CALL USTAW_KURSOR_   
  POP AX    
  MOV DS, AX    
  POP AX    
  MOV ES, AX    
  POPA     
  RET   
WYSWIETL_ZNAK ENDP

USTAW_KURSOR_ PROC
;Parametry procedury:
;AX - przesuniêcie kursora.
  PUSHA
;3d4h - port rejestru adresowego, 3d5h port rejestru danych.
  MOV DX, 03D4H    		;Ustawienie portu rejestru adresowego.
  PUSH AX 
  MOV AL, 14 
  OUT DX, AL      		;Wybór rejestru nr 14.
  POP AX 
  XCHG AH, AL  
  INC DX          		;Ustawienie portu danych.
  OUT DX, AL      		;wys³anie starszego bajtu okreœlaj¹cego po³o¿enie kursora.
  XCHG AL, AH 
  PUSH AX  
  DEC DX  
  MOV AL, 15   
  OUT DX, AL     		;wybór rejestru nr 15. 
  INC DX 
  POP AX 
  OUT DX, AL    		;wys³anie m³odszego bajtu okreœlaj¹cego po³o¿enie kursora.
  POPA  
  RET 
USTAW_KURSOR_ ENDP

PROS_O_WYLACZNOSC_EKRANU PROC
;Parametry procedury:
;AX - identyfikator zadania.
;Wyniki:
;AX - stan ekranu (AX=0 - zajêty, AX != 0 - wolny)
  PUSH BX  
  MOV BX, DS   
  PUSH BX   
  PUSH AX   
  MOV AX, 8     
  MOV DS, AX    
  POP AX    
  BTS WORD PTR EKRAN_.STAN, 0 	;Kopiowany jest zerowy bit stanu urz¹dzenia do znacznika 
				;carry i jednoczeœnie bit zostaje ustawiony.
  JC BIT_TEN_JUZ_BYL_USTAWIONY 
;Procedura dotrze w to miejsce, je¿eli ¿adne zadanie nie korzysta z ekranu.
  MOV EKRAN_.ID_PROCESU_WLASCICIELA, AX  
  MOV AX, 1     
  JMP KONIEC_PROS_O_WL_EK   
  BIT_TEN_JUZ_BYL_USTAWIONY:   
;Procedura dotrze w to miejsce, gdy ekran jest zajêty przez inne zadanie.
  MOV AX, 0          
  KONIEC_PROS_O_WL_EK:  
  POP BX      
  MOV DS, BX         
  POP BX          
  RET                        
PROS_O_WYLACZNOSC_EKRANU ENDP


UZYSKAJ_WYLACZNOSC_EKRANU PROC
  PUSHA  
  PETLA_UZYSKIWANIA_WLASNOSCI_EKRANU:
    MOV BX, OFFSET KOLEJKA_ZADAN  
    CALL ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA  
;W CX jest id zadania (selektor TSS).
    MOV AX, CX  
    CALL PROS_O_WYLACZNOSC_EKRANU   
    CMP AX, 0     
    JNE UZYSKANO_WLASNOSC_EKRANU    
  JMP PETLA_UZYSKIWANIA_WLASNOSCI_EKRANU   
  UZYSKANO_WLASNOSC_EKRANU:        
  POPA            
RET           
UZYSKAJ_WYLACZNOSC_EKRANU ENDP


ZWOLNIJ_WLASNOSC_EKRANU PROC
  PUSHA  
  MOV BX, OFFSET KOLEJKA_ZADAN
  CALL ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA  
;W CX jest id zadania (selektor TSS).
  MOV AX, CX        
  CALL ZWOLNIJ_EKRAN      
  POPA    
  RET  
ZWOLNIJ_WLASNOSC_EKRANU ENDP


ZWOLNIJ_EKRAN PROC
;Parametry procedury:
;AX - identyfikator zadania.
;Wyniki:
;Je¿eli w rejestrze AX zwrócone zostanie 0 oznacza to, ¿e nie da siê zwolniæ ekranu.
  PUSH BX        
  MOV BX, DS       
  PUSH BX    
  PUSH AX   
  MOV AX, 8     
  MOV DS, AX    
  POP AX   
  CMP AX, EKRAN_.ID_PROCESU_WLASCICIELA 
  JNE NIE_DA_SIE_ZWOLNIC     
  MOV  WORD PTR EKRAN_.ID_PROCESU_WLASCICIELA, 0  
  BTR  WORD PTR EKRAN_.STAN, 0   
  CLC    
  JMP KONIEC_ZW_EK     
  NIE_DA_SIE_ZWOLNIC:   
  MOV AX, 0    
  KONIEC_ZW_EK:    
  POP BX    
  MOV DS, BX     
  POP BX      
  RET      
ZWOLNIJ_EKRAN ENDP

POTWIERDZ_WLASNOSC_EKRANU PROC
;Parametry procedury:
;AX - identyfikator procesu.
  PUSH BX  
  MOV BX, DS  
  PUSH BX    
  PUSH AX   
  MOV AX, 8     
  MOV DS, AX      
  POP AX    
  CMP AX, EKRAN_.ID_PROCESU_WLASCICIELA    
  JNE NIE_WLASCICIEL        
  MOV AX, 1       
  JMP KONIEC_POTW_WL_EK       
  NIE_WLASCICIEL:    
  MOV AX, 0       
  KONIEC_POTW_WL_EK:      
  POP BX       
  MOV DS, BX       
  POP BX   
  RET  
POTWIERDZ_WLASNOSC_EKRANU ENDP

WYPISZ_ZNAK_NA_EKRANIE PROC
;Parametry procedury:
;DL - kod ASCII znaku.
;Uzyskanie wy³¹cznoœci do ekranu:
  CALL UZYSKAJ_WYLACZNOSC_EKRANU
;Wyœwietlenie znaku zawartego w rejestrze DL:
  CALL WYSWIETL_ZNAK  
;Zwolnienie w³asnoœci ekranu:
  CALL ZWOLNIJ_WLASNOSC_EKRANU 
  RET  
WYPISZ_ZNAK_NA_EKRANIE ENDP

WYPISZ_CIAG_ZNAKOW PROC
;Parametry procedury:
;ES:DI - wskazuje na ci¹g znaków zakoñczony bajtem o wartoœci 0.
;Pêtla, w której nastêpuje wypisywanie kolejnych znaków:
  PETLA_WYPISYWANIA_ZNAKOW: 
;Pobranie znaku z adresu okreœlonego rejestrami es:di:
    MOV DL, [ES:DI]  
    CMP DL, 0   		;Je¿eli znak ma wartoœæ 0, nale¿y opuœciæ procedurê. 
    JE KONIEC_WYP_CIAG_ZN  
;Gdy znak jest kodem ASCII innym od 0 nastêpuje jego wyœwietlenie na ekranie:
    CALL WYSWIETL_ZNAK  
    INC DI  			;Zwiêkszenie adresu. 
    JMP PETLA_WYPISYWANIA_ZNAKOW  
  KONIEC_WYP_CIAG_ZN:  
  RET    
WYPISZ_CIAG_ZNAKOW ENDP

WYPISZ_CIAG_ZNAKOW_NA_EKRANIE PROC
;Parametry procedury:
;ES:DI - adres ci¹gu znaków zakoñczony bajtem 0.
  PUSHA
;Uzyskanie w³asnoœci ekranu przez aktualny proces:
  CALL UZYSKAJ_WYLACZNOSC_EKRANU  
;Procedura wypisuj¹ca ci¹g znaków:
  CALL WYPISZ_CIAG_ZNAKOW  
;Zwolnienie w³asnoœci ekranu przez aktualny proces:
  CALL ZWOLNIJ_WLASNOSC_EKRANU  
  POPA   
  RET    
WYPISZ_CIAG_ZNAKOW_NA_EKRANIE ENDP


USLUGA_WYPISYWANIA_TEKSTU PROC
  STI     
  CALL WYPISZ_CIAG_ZNAKOW_NA_EKRANIE  
  IRETD   
USLUGA_WYPISYWANIA_TEKSTU ENDP

USLUGA_WYPISYWANIA_ZNAKU_NA_EKRANIE PROC
  STI   
  CALL WYPISZ_ZNAK_NA_EKRANIE 
  IRETD  
USLUGA_WYPISYWANIA_ZNAKU_NA_EKRANIE ENDP

PROGRAM_SIZE=$-BEGIN
PROGRAM	ENDS

STK	SEGMENT STACK 'STACK'
  DB 256 DUP (0)
STK	ENDS

STOSY_ZADAN SEGMENT
  DB 1000 DUP (0)
STOSY_ZADAN ENDS

END	MAIN

