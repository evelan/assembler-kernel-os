.486P
WIELKOSC_ELEMENTU 	EQU 4  ;Wielkoœæ pola danych w elemencie kolejki.
STALA_KWANTU     	EQU 20 ;Po ilu przerwaniach zegarowych nast¹pi zmiana zadañ.
ZMIANA_KODU	  	EQU 1		

INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
;Globalna tablica deskryptorów  (w komentarzach znajduj¹ siê selektory segmentów)
INCLUDE GDT.TXT
GDT_TSS_0	DESKR <103,0,0,89H>		;Selektor 40
;Poni¿szy deskryptor opisuje adres bazowy stosów dodawanych zadañ:
GDT_STOSY_Z  	DESKR <1000,0,0,92H,0,0>     	;Selektor 48
;Deskryptory opisuj¹ce TSS-y tworzonych zadañ:
GDT_TSS1      	DESKR <103,0,0,89H>         	;Selektor 56
GDT_ZAPIS_CS  	DESKR<PROGRAM_SIZE-1,,,92H>  	;Selektor 64
GDT_DESKRYPTOR_WIADOMOSCI DESKR <,,,92H>   	;Selektor 72
GDT_DESKRYPTOR_TSS        DESKR <>          	;Selektor 80
GDT_SIZE=$-GDT_NULL				;Rozmiar GDT
INCLUDE DANE.TXT
TXT_Z1 		DB 'PING-                                        ZADANIE 2 OTRZYMALO WIADOMOSC      ', 0
TXT_Z2 		DB 'PONG-                                        ZADANIE 1 OTRZYMALO WIADOMOSC      ', 0
TASK0_OFFS	DW	0		;4-bajtowy adres dla prze³¹czenia
TASK0_SEL	DW	48		;na zadanie 0 przez TSS.
CZY_PULA_JUZ_ZAINICJOWANA DB 0  	;Program demonstruje wysy³anie wiadomoœci jednakowej
                                	;wielkoœci, wiêc inicjacja puli zostanie zapamiêtana
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
  CALL FORK             	;Procedura tworzy kopiê zadania. Proces macierzysty w rejestrze 
				;AX bêdzie zawiera³ identyfikator (selektor TSS) zadania potomnego.
  ETYKIETA_ZA_FORK:  
  CMP AX, 0               	;W zale¿noœci, czy wykonuje siê zadanie macierzyste czy 
				;te¿ potomne podejmowane s¹ inne dzia³ania.
  JE ZNAJDUJEMY_SIE_W_PROCESIE_POTOMNYM   
  ZNAJDUJEMY_SIE_W_PROCESIE_MACIERZYSTYM:  
  MOV BX, OFFSET TXT_Z1   
  CALL CREATE_STR_MESSAGE	;Utworzenie wiadomoœci tekstowej z ci¹giem
				;znaków skopiowanym z TXT_Z1.  
  CALL SEND_MSG           	;Wysy³anie utworzonej powy¿ej wiadomoœci
                                ;do zadania potomnego.
  CALL WAIT_FOR_MSG      	;Oczekiwanie na wiadomoœæ.
  MOV DS, BX             	;Po opuszczeniu powy¿szej procedury rejestr BX zawiera deskryptor
				;segmentu wiadomoœci- ³adowany jest on do rejestru DS.
  XOR DI, DI  
  MOV AX, [DS:DI]        	;Pierwsze s³owo wiadomoœci zawiera identyfikator (selektor TSS) 
;procesu nadawcy.
  MOV CX, 32    
  MOV ES, CX              	;ES za³adowany selektorem pamiêci ekranu.
  MOV BX, DI  
  ADD BX, 6               	;Pocz¹wszy od tego offsetu w segmencie wiadomoœci 
;rozpoczyna siê tekst przes³any do zadania.
  PUSH AX  
  MOV DX, [DS:DI+2]      	;Wielkoœæ wiadomoœci.
  PUSH DX    
  MOV DI, [DS:DI+4]    		;Adres elementu sterty, który pos³u¿y³ do utworzenia wiadomoœci.
  PUSH DI   
  XOR DI, DI 
  MOV DL, ' '   
  PM_WYPISZ_TEKST_I_DL      	;Wypisanie tekstu wiadomoœci.
  POP SI     
  POP DX   
  CALL DESTROY_STR_MESSAGE 	;Zwolnienie pamiêci zajmowanej przez wiadomoœæ. 
  MOV AX, 8 
  MOV DS, AX   
;Sprawdzenie czy u¿ytkownik wcisn¹³ klawisz- czy ma nast¹piæ zakoñczenie programu:
  MOV AL, 0       
  MOV AH, CZY_MOZNA_KONCZYC      
  CMP AL, AH      
  POP AX       
  JNE KONIEC_DZIALANIA_PROCESU_MACIERZYSTEGO 
  JMP ZNAJDUJEMY_SIE_W_PROCESIE_MACIERZYSTYM  
  ZNAJDUJEMY_SIE_W_PROCESIE_POTOMNYM: ;Proces potomny rozpocznie siê
                                      ;od wykonania poni¿szego kodu:
  CALL WAIT_FOR_MSG      	;Oczekiwanie na wiadomoœæ.
  MOV DS, BX              	;Po opuszczeniu powy¿szej procedury rejestr BX zawiera 
				;deskryptor segmentu wiadomoœci- ³adowany jest on 
				;do rejestru DS. 
;Analogiczne czynnoœci jak w zadaniu macierzystym polegaj¹ce na skompletowaniu niezbêdnych
;informacji z przes³anej wiadomoœci:
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
  PM_WYPISZ_TEKST_I_DL        	;Wypisanie tekstu wiadomoœci.
  POP SI    
  POP DX   
  CALL DESTROY_STR_MESSAGE ;Zwolnienie pamiêci zajmowanej przez wiadomoœæ. 
;Czynnoœci zwi¹zane z utworzeniem wiadomoœci do procesu macierzystego:
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
;Przywrócenie w³aœciwego stanu rejestru IDTR:
  POWROT_DO_RM 0,1
MAIN	ENDP

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
;Nale¿y koniecznie zwróciæ uwagê na fakt, ¿e nie zostaje zachowany rejestr BX.
  ZACHOWAJ_REG 0
  CMP BYTE PTR INT_ON, 0 	;Je¿eli wielozadaniowoœæ nie jest aktywowana, to 
                    		;nie mo¿na pozwoliæ na wykonanie siê tej procedury.
  JNE WIELOZADANIOWOSC_JEST_AKTYWOWANA 
  JMP KONIEC_PRZERWANIE_0 
  WIELOZADANIOWOSC_JEST_AKTYWOWANA: 
  MOV AL, LICZNIK_TYKOW 	;Pobranie zmiennej przechowuj¹cej liczbê wywo³añ
                                ;przerwania zegarowego.		
  INC BYTE PTR LICZNIK_TYKOW ;Inkrementacja jej wartoœci.
  CMP AL, STALA_KWANTU    	;Porównanie ze sta³¹ okreœlaj¹c¹ liczbê przerwañ
                                ;zegarowych do prze³¹czenia zadañ.
  JA ODPOWIEDNI_CZAS_NA_PRZELACZENIE ;Je¿eli aktualna wartoœæ jest od niej wiêksza
                                     ;nale¿y prze³¹czyæ zadania.
  MOV AL, 60H            	;Je¿eli jeszcze nie czas na prze³¹czenie,
                                ;nale¿y wys³aæ do kontrolera przerwañ informacje
                                ;o obs³u¿onym przerwaniu.
  OUT 20H, AL
  JMP NIE_MOZNA_PRZELACZYC_ZADAN_ 
  ODPOWIEDNI_CZAS_NA_PRZELACZENIE: 
  MOV BYTE PTR LICZNIK_TYKOW, 0 ;Wyzerowanie zmiennej przechowuj¹cej liczbê
                                ;wywo³añ przerwania zegarowego
;Pobierany jest selektor TSS aktualnie wykonuj¹cego siê zadania:
  MOV BX, OFFSET KOLEJKA_ZADAN
  CALL ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA
;Rotacja kolejki zadañ:
  CALL PRZELACZ_ZADANIA 
;Rejestr DI zawiera selektor TSS zadania ustawionego na pierwszej pozycji kolejki zadañ dziêki 
;wywo³aniu procedury  PRZELACZ_ZADANIA, natomiast CX zawiera selektor  TSS  obecnego 
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
  MOV AX, 64  
  MOV GS, AX    
  MOV [GS:_SELEKTOR_], DI   
  KONIEC_PRZERWANIE_0:    
;Wys³anie do kontrolera przerwañ informacji o tym, ¿e obs³uga obecnego przerwania
;zosta³a zakoñczona:
  MOV AL, 60H  
  OUT 20H, AL  	
  CMP BYTE PTR INT_ON, 0    
  JE PRZERWANIE_ZEGARA_DALEJ2    
;Poni¿ej nastêpuje prze³¹czenie na nowe zadanie:
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
  INC BYTE PTR LICZNIK_ZADAN 	;Inkrementowana zmienna przechowuj¹ca 
				;liczbê uruchomionych zadañ. 
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
;dziêki temu zadania bêd¹ mog³y okreœliæ czy s¹ potomne czy macierzyste.	
  RET
PRZYGOTUJ_NASTEPNE_ZADANIE ENDP

FORK PROC
;Procedura ma za zadanie uruchomiæ nowe zadanie - kopiê zadania macierzystego.
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
  POP AX ;W AX, po powrocie do zadania macierzystego, znajduje siê selektor TSS zadania potomnego.
  RET  
FORK ENDP

CREATE_STR_MESSAGE PROC
;Parametry procedury:
;DS:BX - adres tekstu wiadomoœci.
  PUSH AX    
  PUSH DX    
  PUSH CX  
;Poni¿sze czynnoœci organizuj¹ pamiêæ na wiadomoœæ:
  MOV AX, 8  
  MOV ES, AX   
  MOV DI, OFFSET PULA_DYNAMICZNA_WIADOMOSCI   
  MOV DX, 81+4   	;81 bajtów tekstu, 2 bajty ID procesu nadawcy, 2 bajty wielkoœæ wiadomoœci
			;plus dodatkowe 2 bajty adresu wiadomoœci.
  MOV AL, CZY_PULA_JUZ_ZAINICJOWANA 
  CMP AL, 0      
  JNE PULA_JUZ_ZOSTALA_ZAINICJOWANA 
;Gdy pula nie jest zainicjowana, to nast¹pi teraz jej inicjacja:
  MOV CX, 2   
  CALL INICJUJ_PULE_DYNAMICZNA  
  MOV BYTE PTR CZY_PULA_JUZ_ZAINICJOWANA, 1 
  PULA_JUZ_ZOSTALA_ZAINICJOWANA:       
  CALL POBIERZ_ELEMENT_Z_PULI  
  CMP DI, 0     
  JNE ZWROCONY_ZOSTAL_ELEMENT   
  ZWROCONY_ZOSTAL_ELEMENT:   
;Ustawienie na pocz¹tkowych bajtach wiadomoœci: ID zadania nadawcy, wielkoœæ, offset
;wiadomoœci w segmencie danych:
  PUSH BX
  MOV BX, OFFSET KOLEJKA_ZADAN
  CALL ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA
  POP BX  
  MOV [ES:DI], CX             	;Identyfikator procesu wysy³aj¹cego.
  MOV [ES:DI+2], DX           	;Wielkoœæ wiadomoœci.
  MOV [ES:DI+4], DI  
;Skopiowanie tekstu do wiadomoœci:
  PUSH DI   
  MOV SI, BX     
  ADD DI, 6  
  MOV CX, 81    
  REP MOVSB    
  POP DI      
  POP CX     
  POP DX      
  POP AX         
;Rejestry ES:DI wskazuj¹ na pocz¹tek wiadomoœci.
  RET    
CREATE_STR_MESSAGE ENDP

DESTROY_STR_MESSAGE PROC
;Parametry procedury:
;AX - offsetwiadomoœci w segmencie danych (3 pole inicjowane na pocz¹tku wiadomoœci).
  MOV AX, 8   
  MOV ES, AX    
  MOV DI, OFFSET PULA_DYNAMICZNA_WIADOMOSCI   
  CALL DOLOZ_ELEMENT_DO_PULI             
  RET                  
DESTROY_STR_MESSAGE ENDP

WAIT_FOR_MSG PROC
;Procedura oczekuje, a¿ w elemencie kolejki zadañ aktualnego zadania, w polu wiadomoœci 
;pojawi siê wartoœæ 2. W przypadku wyzerowanego pola, procedura ustawia go na 1, co 
;bêdzie znakiem dla procesu nadawcy, ¿e mo¿e przes³aæ wiadomoœæ.
;Przerwanie zegarowe w tym miejscu mo¿e doprowadziæ do nieprzewidywalnych efektów, wiêc 
;przerwania s¹ wy³¹czane:
  CLI    
  PUSH BX
  MOV BX, OFFSET KOLEJKA_ZADAN 
  CALL ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA
  POP BX    
;Procedura w rejestrze si zwróci³a offset w segmencie danych elementu kolejki zadañ dla aktualnego zadania. 
;Nale¿y zbadaæ jego pole przechowuj¹ce informacje o wiadomoœciach.
  MOV AX, 8    
  MOV DS, AX        
  MOV EAX, [DS:SI]       
  ROR EAX, 16   
;Gdy pole to jest równe 2, oznacza to, ¿e zadanie otrzyma³o ju¿ wiadomoœæ:
  CMP AX, 2     
  JE JEST_JUZ_WIADOMOSC     
;Je¿eli nie, to ustawiane jest ono na wartoœæ 1, co oznacza przyzwolenie na wys³anie wiadomoœci do zadania:
  MOV AX, 1              
  ROL EAX, 16         
  MOV [DS:SI], EAX         
  STI           
;Cyklicznie sprawdzany stan pola wiadomoœci zadania, a¿ do uzyskania
;wartoœci 2 (co oznacza otrzymanie wiadomoœci):
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
;Gdy wiadomoœæ dotrze, pole wiadomoœci ustawiane na 0- stan taki blokuje przesy³anie wiadomoœci do zadania:
  XOR AX, AX                
  ROL EAX, 16      
  MOV [DS:SI], EAX       
  RET             
WAIT_FOR_MSG ENDP

SEND_MSG PROC
;Parametry procedury:
;AX - ID zadania docelowego (jego selekotr TSS),
;ES:DI - adres wiadomoœci.
;Procedura musi odnaleŸæ w³aœciwe zadanie, do którego nale¿y przes³aæ wiadomoœæ (wpis w kolejce zadañ),
;poczekaæ do momentu a¿ w polu wiadomoœci zadania adresata zostanie za³adowana wartoœæ 1, wtedy
;tworzy deskryptor w GDT opisuj¹cy wiadomoœæ, po czym w obrazie rejestru EBX w TSS adresata umieszcza
;selektor do segmentu wiadomoœci
  PUSH DI      
;Poni¿sza pêtla oczekuje, a¿ zadanie adresata ustawi wartoœæ pola wiadomoœci (jako ¿e pole selektor TSS i pole 
;wiadomoœci granicz¹ ze sob¹, pêtla ³¹czy wyszukiwanie w³aœciwego elementu kolejki zadañ wraz 
;z warunkiem sprawdzenia czy proces adresata ustawi³ pole wiadomoœci na 1):
  NIE_MOZNA_WYSLAC_JESZCZE_WIADOMOSCI:   
  MOV BX, AX     
;Ustalenie formatu elementu kolejki zadañ adresata:
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
;Ta czêœæ kodu wykona siê po odnalezieniu zadania adresata, które akceptuje wiadomoœci.
;W tym momencie AX przechowuje TSS zadania adresata, ES:SI adres elementu kolejki zadañ.
;Procedura musi zawiadomiæ proces adresata o oczekuj¹cej wiadomoœci- ustawiæ pole wiadomoœci na 2:
  MOV BX, AX                  	;sel. TSS do bx.
  MOV AX, 2                   
  SHL EAX, 16                
  MOV AX, BX                 
  MOV [ES:SI], EAX     		;Na miejsce elementu kolejki zadañ wskazuj¹cego zadanie
				;adresata umieszczana nowa wartoœæ- sel. TSS + pole wiadomoœci ustawione na 2.
  POP DI        
  MOV DX, [ES:DI+2]          	;Pobierany rozmiar wiadomoœci.
  CALL USTAW_DESKRYPTOR_WIADOMOSCI ;Tworzony jest deskryptor opisuj¹cy segment wiadomoœci.
;W tym momencie procedura musi uzyskaæ dostêp do segmentu TSS zadania adresata, aby w obrazie EBX 
;umieœciæ selektor do stworzonego segmentu wiadomoœci. W tym celu tworzony jest nowy deskryptor pozwalaj¹cy 
;na zapis do TSS zadania adresata. W pierwszej kolejnoœci na miejsce GDT_DESKRYPTOR_TSS kopiowany jest 
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
;A teraz ustawiany jest atrybut tego deskryptora tak, by mo¿liwy by³ zapis:
  MOV BL, 92H        
  MOV [DI].ATTR_1, BL     
;Za pomoc¹ nowo utworzonego deskryptora aktualizowana jest wartoœæ obrazu EBX w TSS zadania adresata 
;(tak by zawiera³ selektor segmentu wiadomoœci):
  MOV BX, 80        
  MOV ES, BX        
  XOR DI, DI          
  MOV EBX, 72 			;Deskryptor wiadomoœci.
  MOV [ES:DI+52], EBX   
  STI         
  RET            
SEND_MSG ENDP

USTAW_DESKRYPTOR_WIADOMOSCI PROC
;Parametry procedury:
;DX - rozmiar wiadomoœci,
;AX - offset wiadomoœci w segmencie danych.
  PUSH AX       
  MOV AX, 8   
  MOV DS, AX     
  XOR EAX,EAX         
  MOV AX,DANE   
  SHL EAX,4      
  XOR EBP, EBP       
  MOV BP, DI        
  ADD EAX,  EBP               	;EAX zawiera adres liniowy wiadomoœci.
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
;EAX - zawartoœæ szukanego pola danych.
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
  JNE PETLA_POSZUKIWANIA_ZN_ELEM ;Je¿eli kolejka jest pusta, to nie ma czego szukaæ.
  MOV SI, 0  
  JMP KONIEC_PROCEDURY_ZN_ELEM  
  PETLA_POSZUKIWANIA_ZN_ELEM:   
    CMP EAX, [ES:DI]     	;Je¿eli dana z EAX jest inna od pola danych wskazanego
                    		;elementu par¹ rejestrów ES:DI, to nale¿y kontynuowaæ
                    		;poszukiwanie od nastêpnego elementu.
    JNE NIE_JEST_TO_JESZCZE_TEN_ELEMENT  
;Je¿eli program dotrze tutaj, to znaczy, ze znalaz³ w³aœciwy element.
    MOV SI, DI 		;£adowany jest do rejestru SI adres tego elementu.
    JMP KONIEC_PROCEDURY_ZN_ELEM    
    NIE_JEST_TO_JESZCZE_TEN_ELEMENT:    
    MOV DI, [ES:DI+WIELKOSC_ELEMENTU] 	;O WIELKOSC_ELEMENTU powy¿ej adresu elementu
                    			;znajduje siê wskaŸnik na nastêpny element.
    CMP DI, 0          	;Je¿eli odnaleziono koniec kolejki, to nale¿y opuœciæ procedurê.          
    JNE MOZNA_DALEJ_ZN_ELEM     
    MOV SI, 0           
    JMP KONIEC_PROCEDURY_ZN_ELEM 	;Gdy wskaŸnik nastêpnego elementu jest null-em,
                   			;to nastêpuje wyjœcie z procedury.
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

