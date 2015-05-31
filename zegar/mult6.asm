.486P
WIELKOSC_ELEMENTU 	EQU 4  ;Wielko�� pola danych w elemencie kolejki.
STALA_KWANTU     	EQU 20 ;Po ilu przerwaniach zegarowych nast�pi zmiana zada�.
ZMIANA_KODU	  	EQU 1		

INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
;Globalna tablica deskryptor�w  (w komentarzach znajduj� si� selektory segment�w)
INCLUDE GDT.TXT
GDT_TSS_0	DESKR <103,0,0,89H>		;Selektor 40
;Poni�szy deskryptor opisuje adres bazowy stos�w dodawanych zada�:
GDT_STOSY_Z  	DESKR <1000,0,0,92H,0,0>     	;Selektor 48
;Deskryptory opisuj�ce TSS-y tworzonych zada�:
GDT_TSS1      	DESKR <103,0,0,89H>         	;Selektor 56
GDT_ZAPIS_CS  	DESKR<PROGRAM_SIZE-1,,,92H>  	;Selektor 64
GDT_DESKRYPTOR_WIADOMOSCI DESKR <,,,92H>   	;Selektor 72
GDT_DESKRYPTOR_TSS        DESKR <>          	;Selektor 80
GDT_SIZE=$-GDT_NULL				;Rozmiar GDT
INCLUDE DANE.TXT
TXT_Z1 		DB 'PING-                                        ZADANIE 2 OTRZYMALO WIADOMOSC      ', 0
TXT_Z2 		DB 'PONG-                                        ZADANIE 1 OTRZYMALO WIADOMOSC      ', 0
TASK0_OFFS	DW	0		;4-bajtowy adres dla prze��czenia
TASK0_SEL	DW	48		;na zadanie 0 przez TSS.
CZY_PULA_JUZ_ZAINICJOWANA DB 0  	;Program demonstruje wysy�anie wiadomo�ci jednakowej
                                	;wielko�ci, wi�c inicjacja puli zostanie zapami�tana
                               		;w tej zmiennej.
PULA_DYNAMICZNA_WIADOMOSCI DB 200 DUP (0)
DANE_SIZE=$-GDT_NULL			;Rozmiar segmentu danych.
DANE	ENDS

PROGRAM	SEGMENT 'CODE' USE16
ASSUME CS:PROGRAM,DS:DANE
BEGIN	LABEL WORD

INCLUDE MAKRA.TXT

MAIN	PROC
  INCLUDE KOD.TXT
  MOV DX, 4   
  MOV CX, 10   
  CALL INICJUJ_PULE_DYNAMICZNA   
  XOR AX, AX  
  SHL AX, 16   
  MOV AX, 40  
  CALL DODAJ_ZADANIE_DO_KOLEJKI_ZADAN 
  MOV BYTE PTR INT_ON, 1   
  CALL FORK             	;Procedura tworzy kopi� zadania. Proces macierzysty w rejestrze 
				;AX b�dzie zawiera� identyfikator (selektor TSS) zadania potomnego.
  ETYKIETA_ZA_FORK:  
  CMP AX, 0               	;W zale�no�ci, czy wykonuje si� zadanie macierzyste czy 
				;te� potomne podejmowane s� inne dzia�ania.
  JE ZNAJDUJEMY_SIE_W_PROCESIE_POTOMNYM   
  ZNAJDUJEMY_SIE_W_PROCESIE_MACIERZYSTYM:  
  MOV BX, OFFSET TXT_Z1   
  CALL CREATE_STR_MESSAGE	;Utworzenie wiadomo�ci tekstowej z ci�giem
				;znak�w skopiowanym z TXT_Z1.  
  CALL SEND_MSG           	;Wysy�anie utworzonej powy�ej wiadomo�ci
                                ;do zadania potomnego.
  CALL WAIT_FOR_MSG      	;Oczekiwanie na wiadomo��.
  MOV DS, BX             	;Po opuszczeniu powy�szej procedury rejestr BX zawiera deskryptor
				;segmentu wiadomo�ci- �adowany jest on do rejestru DS.
  XOR DI, DI  
  MOV AX, [DS:DI]        	;Pierwsze s�owo wiadomo�ci zawiera identyfikator (selektor TSS) 
;procesu nadawcy.
  MOV CX, 32    
  MOV ES, CX              	;ES za�adowany selektorem pami�ci ekranu.
  MOV BX, DI  
  ADD BX, 6               	;Pocz�wszy od tego offsetu w segmencie wiadomo�ci 
;rozpoczyna si� tekst przes�any do zadania.
  PUSH AX  
  MOV DX, [DS:DI+2]      	;Wielko�� wiadomo�ci.
  PUSH DX    
  MOV DI, [DS:DI+4]    		;Adres elementu sterty, kt�ry pos�u�y� do utworzenia wiadomo�ci.
  PUSH DI   
  XOR DI, DI 
  MOV DL, ' '   
  PM_WYPISZ_TEKST_I_DL      	;Wypisanie tekstu wiadomo�ci.
  POP SI     
  POP DX   
  CALL DESTROY_STR_MESSAGE 	;Zwolnienie pami�ci zajmowanej przez wiadomo��. 
  MOV AX, 8 
  MOV DS, AX   
;Sprawdzenie czy u�ytkownik wcisn�� klawisz- czy ma nast�pi� zako�czenie programu:
  MOV AL, 0       
  MOV AH, CZY_MOZNA_KONCZYC      
  CMP AL, AH      
  POP AX       
  JNE KONIEC_DZIALANIA_PROCESU_MACIERZYSTEGO 
  JMP ZNAJDUJEMY_SIE_W_PROCESIE_MACIERZYSTYM  
  ZNAJDUJEMY_SIE_W_PROCESIE_POTOMNYM: ;Proces potomny rozpocznie si�
                                      ;od wykonania poni�szego kodu:
  CALL WAIT_FOR_MSG      	;Oczekiwanie na wiadomo��.
  MOV DS, BX              	;Po opuszczeniu powy�szej procedury rejestr BX zawiera 
				;deskryptor segmentu wiadomo�ci- �adowany jest on 
				;do rejestru DS. 
;Analogiczne czynno�ci jak w zadaniu macierzystym polegaj�ce na skompletowaniu niezb�dnych
;informacji z przes�anej wiadomo�ci:
  XOR DI, DI     
  MOV AX, [DS:DI]    
  MOV BX, DI    
  ADD BX, 6      
  PUSH AX    
  MOV DX, [DS:DI+2]   
  PUSH DX     
  MOV DI, [DS:DI+4]     
  PUSH DI       
  XOR DI, DI 
  MOV DL, ' '
  PM_WYPISZ_TEKST_I_DL        	;Wypisanie tekstu wiadomo�ci.
  POP SI    
  POP DX   
  CALL DESTROY_STR_MESSAGE ;Zwolnienie pami�ci zajmowanej przez wiadomo��. 
;Czynno�ci zwi�zane z utworzeniem wiadomo�ci do procesu macierzystego:
  MOV AX, 8   
  MOV DS, AX   
  MOV ES, AX   
  POP AX    
  MOV BX, OFFSET TXT_Z2   
  CALL CREATE_STR_MESSAGE     
  CALL SEND_MSG    
  JMP   ZNAJDUJEMY_SIE_W_PROCESIE_POTOMNYM   
  KONIEC_DZIALANIA_PROCESU_MACIERZYSTEGO:  
  MIEKI_POWROT_RM
  MOV AX,STK
  MOV SS,AX
  MOV SP,200
  KONTROLER_PRZERWAN_RM
;Przywr�cenie w�a�ciwego stanu rejestru IDTR:
  POWROT_DO_RM 0,1
MAIN	ENDP

INCLUDE PROC.TXT

INCLUDE MULT.TXT

PRZERWANIE1 PROC
  ZACHOWAJ_REG 1
  SPRAWDZ_BUFOR_KLAWIATURY
  IN AL, 60H
  AND AL, 10000000B       	;Gdy odczytana warto�� wskazuje na to, �e przycisk
                                ;klawiatury zosta� zwolniony, to nast�puje skok do
                                ;dalszej cz�ci kodu.
  CMP AL, 0   
  JNE PRZERWANIE1_DALEJ 
  MOV BYTE PTR CZY_MOZNA_KONCZYC, 1 ; Ustawienie zmiennej spowoduje wyj�cie z
                                    ;programu po powrocie do zadania g��wnego.
  PRZERWANIE1_DALEJ: 
  IN AL, 61H        		;Odczyt bajtu z portu 61h.
  OR AL, 10000000B  		;Suma logiczna otrzymanego bajtu
                    		;z ustawionym najstarszym bitem .
  OUT 61H, AL       		
  AND AL, 7FH       		
  OUT 61H, AL       		
  MOV AL, 61H    
  OUT 20H, AL  
  PRZYWROC_REG 1 
  IRETD
PRZERWANIE1 ENDP


PRZERWANIE0 PROC
;Nale�y koniecznie zwr�ci� uwag� na fakt, �e nie zostaje zachowany rejestr BX.
  ZACHOWAJ_REG 0
  CMP BYTE PTR INT_ON, 0 	;Je�eli wielozadaniowo�� nie jest aktywowana, to 
                    		;nie mo�na pozwoli� na wykonanie si� tej procedury.
  JNE WIELOZADANIOWOSC_JEST_AKTYWOWANA 
  JMP KONIEC_PRZERWANIE_0 
  WIELOZADANIOWOSC_JEST_AKTYWOWANA: 
  MOV AL, LICZNIK_TYKOW 	;Pobranie zmiennej przechowuj�cej liczb� wywo�a�
                                ;przerwania zegarowego.		
  INC BYTE PTR LICZNIK_TYKOW ;Inkrementacja jej warto�ci.
  CMP AL, STALA_KWANTU    	;Por�wnanie ze sta�� okre�laj�c� liczb� przerwa�
                                ;zegarowych do prze��czenia zada�.
  JA ODPOWIEDNI_CZAS_NA_PRZELACZENIE ;Je�eli aktualna warto�� jest od niej wi�ksza
                                     ;nale�y prze��czy� zadania.
  MOV AL, 60H            	;Je�eli jeszcze nie czas na prze��czenie,
                                ;nale�y wys�a� do kontrolera przerwa� informacje
                                ;o obs�u�onym przerwaniu.
  OUT 20H, AL
  JMP NIE_MOZNA_PRZELACZYC_ZADAN_ 
  ODPOWIEDNI_CZAS_NA_PRZELACZENIE: 
  MOV BYTE PTR LICZNIK_TYKOW, 0 ;Wyzerowanie zmiennej przechowuj�cej liczb�
                                ;wywo�a� przerwania zegarowego
;Pobierany jest selektor TSS aktualnie wykonuj�cego si� zadania:
  MOV BX, OFFSET KOLEJKA_ZADAN
  CALL ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA
;Rotacja kolejki zada�:
  CALL PRZELACZ_ZADANIA 
;Rejestr DI zawiera selektor TSS zadania ustawionego na pierwszej pozycji kolejki zada� dzi�ki 
;wywo�aniu procedury  PRZELACZ_ZADANIA, natomiast CX zawiera selektor  TSS  obecnego 
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
;maszynowej, by m�c zmienia� dynamicznie jej parametr wskazuj�cy selektor TSS.
;Do zmiany tego parametru nale�a�o przygotowa� deskryptor opisuj�cy segment kodu
;(nie mo�na korzysta� z rejestru CS, gdy� zawarto�ci segmentu kodu nie mo�na modyfikowa�).
  MOV AX, 64  
  MOV GS, AX    
  MOV [GS:_SELEKTOR_], DI   
  KONIEC_PRZERWANIE_0:    
;Wys�anie do kontrolera przerwa� informacji o tym, �e obs�uga obecnego przerwania
;zosta�a zako�czona:
  MOV AL, 60H  
  OUT 20H, AL  	
  CMP BYTE PTR INT_ON, 0    
  JE PRZERWANIE_ZEGARA_DALEJ2    
;Poni�ej nast�puje prze��czenie na nowe zadanie:
    POLECENIE       	DB 0EAH         
    OFFSET_         	DW 12            
    _SELEKTOR_      	DW 40H
  PRZERWANIE_ZEGARA_DALEJ2: 
  NIE_MOZNA_PRZELACZYC_ZADAN_: 
  PRZYWROC_REG 0
  IRETD  
PRZERWANIE0 ENDP


PRZYGOTUJ_NASTEPNE_ZADANIE PROC
;Obliczenie adresu TSS dla dodanego zadania:
  MOV DI, OFFSET TSSY_ZADAN 
  XOR AX, AX
  XOR DX, DX
  MOV BX, 104
  MOV AL, LICZNIK_ZADAN  
  MUL BX
  ADD DI, AX 
  INC BYTE PTR LICZNIK_ZADAN 	;Inkrementowana zmienna przechowuj�ca 
				;liczb� uruchomionych zada�. 
  MOV WORD PTR [DS:DI+4CH],16 	;Selektor segmentu programu (CS).
  MOV WORD PTR [DS:DI+20H],OFFSET ETYKIETA_ZA_FORK ;Offset w segmencie progr. 
  MOV WORD PTR [DS:DI+50H],48 	;Selektor segmentu stosu (SS).
;Obliczenie szczytu stosu:
  XOR AX, AX
  XOR DX,DX
  MOV AL, LICZNIK_ZADAN
  MOV BX, 300  
  MUL BX
  MOV WORD PTR [DS:DI+38H], AX	;Offset w segmencie stosu.
  MOV WORD PTR [DS:DI+54H], 8	;Selektor segmentu danych (DS).
  MOV WORD PTR [DS:DI+48H], 32	;Selektor segmentu danych (ES).
  MOV DWORD PTR [DS:DI+36], 00000000000000000000001000000000B   ;EFLAGS z ustawionym IF.
  XOR ECX, ECX  
  MOV DWORD PTR [DS:DI+40], ECX ;Zerowany jest obraz EAX w TSS tworzonego zadania- 
;dzi�ki temu zadania b�d� mog�y okre�li� czy s� potomne czy macierzyste.	
  RET
PRZYGOTUJ_NASTEPNE_ZADANIE ENDP

FORK PROC
;Procedura ma za zadanie uruchomi� nowe zadanie - kopi� zadania macierzystego.
  CALL  PRZYGOTUJ_NASTEPNE_ZADANIE 
  XOR AX, AX    
  MOV AL, LICZNIK_ZADAN   
  DEC AL     
  XOR DX, DX       
  MOV BX, 8    
  MUL BX       
  ADD AX, 56   
  MOV BX,AX      
  XOR AX, AX     
  SHL EAX, 16      
  MOV AX, BX         
  PUSH AX      
  CALL DODAJ_ZADANIE_DO_KOLEJKI_ZADAN 
  POP AX ;W AX, po powrocie do zadania macierzystego, znajduje si� selektor TSS zadania potomnego.
  RET  
FORK ENDP

CREATE_STR_MESSAGE PROC
;Parametry procedury:
;DS:BX - adres tekstu wiadomo�ci.
  PUSH AX    
  PUSH DX    
  PUSH CX  
;Poni�sze czynno�ci organizuj� pami�� na wiadomo��:
  MOV AX, 8  
  MOV ES, AX   
  MOV DI, OFFSET PULA_DYNAMICZNA_WIADOMOSCI   
  MOV DX, 81+4   	;81 bajt�w tekstu, 2 bajty ID procesu nadawcy, 2 bajty wielko�� wiadomo�ci
			;plus dodatkowe 2 bajty adresu wiadomo�ci.
  MOV AL, CZY_PULA_JUZ_ZAINICJOWANA 
  CMP AL, 0      
  JNE PULA_JUZ_ZOSTALA_ZAINICJOWANA 
;Gdy pula nie jest zainicjowana, to nast�pi teraz jej inicjacja:
  MOV CX, 2   
  CALL INICJUJ_PULE_DYNAMICZNA  
  MOV BYTE PTR CZY_PULA_JUZ_ZAINICJOWANA, 1 
  PULA_JUZ_ZOSTALA_ZAINICJOWANA:       
  CALL POBIERZ_ELEMENT_Z_PULI  
  CMP DI, 0     
  JNE ZWROCONY_ZOSTAL_ELEMENT   
  ZWROCONY_ZOSTAL_ELEMENT:   
;Ustawienie na pocz�tkowych bajtach wiadomo�ci: ID zadania nadawcy, wielko��, offset
;wiadomo�ci w segmencie danych:
  PUSH BX
  MOV BX, OFFSET KOLEJKA_ZADAN
  CALL ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA
  POP BX  
  MOV [ES:DI], CX             	;Identyfikator procesu wysy�aj�cego.
  MOV [ES:DI+2], DX           	;Wielko�� wiadomo�ci.
  MOV [ES:DI+4], DI  
;Skopiowanie tekstu do wiadomo�ci:
  PUSH DI   
  MOV SI, BX     
  ADD DI, 6  
  MOV CX, 81    
  REP MOVSB    
  POP DI      
  POP CX     
  POP DX      
  POP AX         
;Rejestry ES:DI wskazuj� na pocz�tek wiadomo�ci.
  RET    
CREATE_STR_MESSAGE ENDP

DESTROY_STR_MESSAGE PROC
;Parametry procedury:
;AX - offsetwiadomo�ci w segmencie danych (3 pole inicjowane na pocz�tku wiadomo�ci).
  MOV AX, 8   
  MOV ES, AX    
  MOV DI, OFFSET PULA_DYNAMICZNA_WIADOMOSCI   
  CALL DOLOZ_ELEMENT_DO_PULI             
  RET                  
DESTROY_STR_MESSAGE ENDP

WAIT_FOR_MSG PROC
;Procedura oczekuje, a� w elemencie kolejki zada� aktualnego zadania, w polu wiadomo�ci 
;pojawi si� warto�� 2. W przypadku wyzerowanego pola, procedura ustawia go na 1, co 
;b�dzie znakiem dla procesu nadawcy, �e mo�e przes�a� wiadomo��.
;Przerwanie zegarowe w tym miejscu mo�e doprowadzi� do nieprzewidywalnych efekt�w, wi�c 
;przerwania s� wy��czane:
  CLI    
  PUSH BX
  MOV BX, OFFSET KOLEJKA_ZADAN 
  CALL ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA
  POP BX    
;Procedura w rejestrze si zwr�ci�a offset w segmencie danych elementu kolejki zada� dla aktualnego zadania. 
;Nale�y zbada� jego pole przechowuj�ce informacje o wiadomo�ciach.
  MOV AX, 8    
  MOV DS, AX        
  MOV EAX, [DS:SI]       
  ROR EAX, 16   
;Gdy pole to jest r�wne 2, oznacza to, �e zadanie otrzyma�o ju� wiadomo��:
  CMP AX, 2     
  JE JEST_JUZ_WIADOMOSC     
;Je�eli nie, to ustawiane jest ono na warto�� 1, co oznacza przyzwolenie na wys�anie wiadomo�ci do zadania:
  MOV AX, 1              
  ROL EAX, 16         
  MOV [DS:SI], EAX         
  STI           
;Cyklicznie sprawdzany stan pola wiadomo�ci zadania, a� do uzyskania
;warto�ci 2 (co oznacza otrzymanie wiadomo�ci):
  CZEKAJ_DALEJ:    
    CLI  
    PUSH BX 
    MOV BX, OFFSET KOLEJKA_ZADAN     
    CALL ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA 
    POP BX  
    MOV EAX, [DS:SI]    
    ROR EAX, 16        
    CMP AX, 2           
    STI       
    JNE CZEKAJ_DALEJ          
  JEST_JUZ_WIADOMOSC:        
  STI                
;Gdy wiadomo�� dotrze, pole wiadomo�ci ustawiane na 0- stan taki blokuje przesy�anie wiadomo�ci do zadania:
  XOR AX, AX                
  ROL EAX, 16      
  MOV [DS:SI], EAX       
  RET             
WAIT_FOR_MSG ENDP

SEND_MSG PROC
;Parametry procedury:
;AX - ID zadania docelowego (jego selekotr TSS),
;ES:DI - adres wiadomo�ci.
;Procedura musi odnale�� w�a�ciwe zadanie, do kt�rego nale�y przes�a� wiadomo�� (wpis w kolejce zada�),
;poczeka� do momentu a� w polu wiadomo�ci zadania adresata zostanie za�adowana warto�� 1, wtedy
;tworzy deskryptor w GDT opisuj�cy wiadomo��, po czym w obrazie rejestru EBX w TSS adresata umieszcza
;selektor do segmentu wiadomo�ci
  PUSH DI      
;Poni�sza p�tla oczekuje, a� zadanie adresata ustawi warto�� pola wiadomo�ci (jako �e pole selektor TSS i pole 
;wiadomo�ci granicz� ze sob�, p�tla ��czy wyszukiwanie w�a�ciwego elementu kolejki zada� wraz 
;z warunkiem sprawdzenia czy proces adresata ustawi� pole wiadomo�ci na 1):
  NIE_MOZNA_WYSLAC_JESZCZE_WIADOMOSCI:   
  MOV BX, AX     
;Ustalenie formatu elementu kolejki zada� adresata:
  MOV AX, 1      
  SHL EAX, 16    
  MOV AX, BX                  	;TSS proc. adresata.
  CLI        
  MOV DI, KOLEJKA_ZADAN.POCZATEK_      
  CALL ZNAJDZ_ELEMENT_O_OKRESLONYM_POLU_DANYCH    
  STI                  
  CMP SI, 0                     
  JE NIE_MOZNA_WYSLAC_JESZCZE_WIADOMOSCI      
  CLI              
;Ta cz�� kodu wykona si� po odnalezieniu zadania adresata, kt�re akceptuje wiadomo�ci.
;W tym momencie AX przechowuje TSS zadania adresata, ES:SI adres elementu kolejki zada�.
;Procedura musi zawiadomi� proces adresata o oczekuj�cej wiadomo�ci- ustawi� pole wiadomo�ci na 2:
  MOV BX, AX                  	;sel. TSS do bx.
  MOV AX, 2                   
  SHL EAX, 16                
  MOV AX, BX                 
  MOV [ES:SI], EAX     		;Na miejsce elementu kolejki zada� wskazuj�cego zadanie
				;adresata umieszczana nowa warto��- sel. TSS + pole wiadomo�ci ustawione na 2.
  POP DI        
  MOV DX, [ES:DI+2]          	;Pobierany rozmiar wiadomo�ci.
  CALL USTAW_DESKRYPTOR_WIADOMOSCI ;Tworzony jest deskryptor opisuj�cy segment wiadomo�ci.
;W tym momencie procedura musi uzyska� dost�p do segmentu TSS zadania adresata, aby w obrazie EBX 
;umie�ci� selektor do stworzonego segmentu wiadomo�ci. W tym celu tworzony jest nowy deskryptor pozwalaj�cy 
;na zapis do TSS zadania adresata. W pierwszej kolejno�ci na miejsce GDT_DESKRYPTOR_TSS kopiowany jest 
;deskryptor TSS zadania adresata:
  MOV BX, 8              
  MOV DS, BX       
  MOV ES, BX        
  MOV DI, 80     
  MOV SI, AX       
  CLD             
  PUSH DI           
  MOVSD      
  MOVSD          
  POP DI    
;A teraz ustawiany jest atrybut tego deskryptora tak, by mo�liwy by� zapis:
  MOV BL, 92H        
  MOV [DI].ATTR_1, BL     
;Za pomoc� nowo utworzonego deskryptora aktualizowana jest warto�� obrazu EBX w TSS zadania adresata 
;(tak by zawiera� selektor segmentu wiadomo�ci):
  MOV BX, 80        
  MOV ES, BX        
  XOR DI, DI          
  MOV EBX, 72 			;Deskryptor wiadomo�ci.
  MOV [ES:DI+52], EBX   
  STI         
  RET            
SEND_MSG ENDP

USTAW_DESKRYPTOR_WIADOMOSCI PROC
;Parametry procedury:
;DX - rozmiar wiadomo�ci,
;AX - offset wiadomo�ci w segmencie danych.
  PUSH AX       
  MOV AX, 8   
  MOV DS, AX     
  XOR EAX,EAX         
  MOV AX,DANE   
  SHL EAX,4      
  XOR EBP, EBP       
  MOV BP, DI        
  ADD EAX,  EBP               	;EAX zawiera adres liniowy wiadomo�ci.
  MOV BX,OFFSET GDT_DESKRYPTOR_WIADOMOSCI    
  MOV [BX].BASE_1,AX       
  ROL EAX,16         
  MOV [BX].BASE_M,AL     
  INC DX         
  MOV [BX].LIMIT, DX     
  DEC DX             
  POP AX          
  RET        
USTAW_DESKRYPTOR_WIADOMOSCI ENDP

ZNAJDZ_ELEMENT_O_OKRESLONYM_POLU_DANYCH PROC
;Parametry procedury:
;DI - adres pierwszego elementu kolejki,
;EAX - zawarto�� szukanego pola danych.
;Wyniki:
;SI - adres szukanego elementu (lub 0 gdy elementu nie odnaleziono).
  PUSH AX  
  PUSH DI     
  PUSH BX     
  MOV BX, ES   
  PUSH BX      
  MOV BX, 8     
  MOV ES, BX    
  CMP DI, 0      
  JNE PETLA_POSZUKIWANIA_ZN_ELEM ;Je�eli kolejka jest pusta, to nie ma czego szuka�.
  MOV SI, 0  
  JMP KONIEC_PROCEDURY_ZN_ELEM  
  PETLA_POSZUKIWANIA_ZN_ELEM:   
    CMP EAX, [ES:DI]     	;Je�eli dana z EAX jest inna od pola danych wskazanego
                    		;elementu par� rejestr�w ES:DI, to nale�y kontynuowa�
                    		;poszukiwanie od nast�pnego elementu.
    JNE NIE_JEST_TO_JESZCZE_TEN_ELEMENT  
;Je�eli program dotrze tutaj, to znaczy, ze znalaz� w�a�ciwy element.
    MOV SI, DI 		;�adowany jest do rejestru SI adres tego elementu.
    JMP KONIEC_PROCEDURY_ZN_ELEM    
    NIE_JEST_TO_JESZCZE_TEN_ELEMENT:    
    MOV DI, [ES:DI+WIELKOSC_ELEMENTU] 	;O WIELKOSC_ELEMENTU powy�ej adresu elementu
                    			;znajduje si� wska�nik na nast�pny element.
    CMP DI, 0          	;Je�eli odnaleziono koniec kolejki, to nale�y opu�ci� procedur�.          
    JNE MOZNA_DALEJ_ZN_ELEM     
    MOV SI, 0           
    JMP KONIEC_PROCEDURY_ZN_ELEM 	;Gdy wska�nik nast�pnego elementu jest null-em,
                   			;to nast�puje wyj�cie z procedury.
    MOZNA_DALEJ_ZN_ELEM:      
  JMP PETLA_POSZUKIWANIA_ZN_ELEM         
  KONIEC_PROCEDURY_ZN_ELEM:          
  POP AX                        
  MOV ES, AX                
  POP BX                   
  POP DI                        
  POP AX                     
  RET                            
ZNAJDZ_ELEMENT_O_OKRESLONYM_POLU_DANYCH ENDP

PROGRAM_SIZE=$-BEGIN
PROGRAM	ENDS

STK	SEGMENT STACK 'STACK'
  DB 256 DUP (0)
STK	ENDS

STOSY_ZADAN SEGMENT
  DB 1000 DUP (0)
STOSY_ZADAN ENDS

END	MAIN

