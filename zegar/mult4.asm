.386P
WIELKOSC_ELEMENTU EQU 2
STALA_KWANTU      EQU 20
CZAS_ZAKONCZENIA_ZADANIA_UPRZYWILEJOWANEGO EQU 160
DWIE_KOLEJKI      EQU 0

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
GDT_TSS6    	DESKR <103,0,0,89H>       	;Selektor 96
GDT_TSS7    	DESKR <103,0,0,89H>          	;Selektor 104
GDT_TSS8     	DESKR <103,0,0,89H>          	;Selektor 112
GDT_TSS9   	DESKR <103,0,0,89H>          	;Selektor 120
;Deskryptor umo¿liwiaj¹cy modyfikacjê kodu:
GDT_ZAPIS_CS 	DESKR <PROGRAM_SIZE-1,,,92H> 	;Selektor 128
GDT_SIZE=$-GDT_NULL		;Rozmiar GDT
INCLUDE DANE.TXT
KOLEJKA_ZADAN_UPRZYWILEJOWANYCH KOLEJKA_ZADAN_ <>
INFO2   	DB  '        AKTYWNE ZWYKLE ZADANIE NUMER ', 0
INFO2B   	DB 'WYKONUJE SIE ZADANIE UPRZYWILEJOWANE ', 0
INFO3   	DB 'ZAD0   ZAD1   ZAD2   ZAD3   ZAD4   ZAD5   ZAD6   ZAD7   ZAD8   ZAD9', 0
TASK0_OFFS	DW 0			;4-bajtowy adres dla prze³¹czenia
TASK0_SEL	DW 48			;na zadanie 0 przez TSS.
LICZNIK_CZASU	DD 0
DANE_SIZE=$-GDT_NULL			;Rozmiar segmentu danych.
DANE	ENDS

PROGRAM	SEGMENT 'CODE' USE16
ASSUME CS:PROGRAM,DS:DANE
BEGIN	LABEL WORD

INCLUDE MAKRA.TXT

MAIN	PROC
  INCLUDE KOD.TXT
  MOV KOLEJKA_ZADAN_UPRZYWILEJOWANYCH.ADRES_PULI_, DI
  MOV CX, 10
  CALL INICJUJ_PULE_DYNAMICZNA
;Dodanie zadania g³ównego do kolejki zadañ:
  MOV AX, 40 
  MOV CX, 128   
  MOV GS, CX  
;Nale¿y zwróciæ szczególn¹ uwagê na poni¿szy kod- selektor TSS zadania g³ównego
;zapisywany jest jako parametr skoku odleg³ego w kodzie schedulera
  MOV [GS:_SELEKTOR_], AX 
  MOV BX, OFFSET KOLEJKA_ZADAN   
  CALL DODAJ_ZADANIE_DO_KOLEJKI_ZADAN       
;Uruchomienie dodatkowych 3 zwyk³ych zadañ:
  CALL URUCHOM_KOLEJNE_ZADANIE 
  CALL URUCHOM_KOLEJNE_ZADANIE 
  CALL URUCHOM_KOLEJNE_ZADANIE   
  MOV BYTE PTR INT_ON, 1      
;Poni¿ej nastêpuje wypisanie tekstu:  'ZAD0   ZAD1   ZAD2   ZAD3   ZAD4   ZAD5   ZAD6   ZAD7   ZAD8   ZAD9'
  XOR DI, DI
  MOV BX, OFFSET INFO3
  MOV DL, ' '
  PM_WYPISZ_TEKST_I_DL
;Pozostawienie tylko pierwszego napisu (ZAD0):
  MOV DL, '0'
  ZNACZ_ELEMENT
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

;Procedura zawiera kod zadañ zwyk³ych:
ZADANIE PROC
  MOV AX, 8
  MOV DS, AX
  XOR EBX, EBX  
  ZADANIE_PETLA:
    ZNACZ_ELEMENT  		
    MOV BX, OFFSET INFO2
    MOV DI, 2*80
    PM_WYPISZ_TEKST_I_DL       
  JMP ZADANIE_PETLA
ZADANIE ENDP

;Procedura zawiera kod zadañ uprzywilejowanych:
ZADANIE_UP	PROC
  MOV AX, 8     
  MOV DS, AX      
  MOV ECX, LICZNIK_CZASU	;Pobranie wartoœci licznika czasu w chwili pierwszego 
;wywo³ania zadania. 
  ZADANIE_PETLA_UP:    
    CLI          
    ZNACZ_ELEMENT      
    MOV BX, OFFSET INFO2B     
    MOV DI, 2*80                
    PM_WYPISZ_TEKST_I_DL         
    STI                 
;Sprawdzenie, czy zadanie uprzywilejowane nie przekroczy³o przyznanego mu czasu
    MOV EBX, LICZNIK_CZASU      
    SUB EBX, ECX        
    CMP EBX, CZAS_ZAKONCZENIA_ZADANIA_UPRZYWILEJOWANEGO
    JA KONIEC_ZAD_UP           
  JMP ZADANIE_PETLA_UP     
  KONIEC_ZAD_UP:       
  CALL ZAKONCZ_ZADANIE_UPRZYWILEJOWANE     
ZADANIE_UP ENDP


INCLUDE PROC.TXT

INCLUDE MULT.TXT


PRZERWANIE1 PROC
  ZACHOWAJ_REG 1
;Odczyt kodu naciœniêcia (b¹dŸ zwolnienia) klawisza:
  SPRAWDZ_BUFOR_KLAWIATURY
  IN AL, 60H
  TEST AL, 10000000B
  JNZ PRZERWANIE_1_DALEJ 	;Gdy jest uruchomionych ju¿ 10 zadañ i zosta³ naciœniêty klawisz, 
;to nale¿y zakoñczyæ program.
  CMP BYTE PTR LICZNIK_ZADAN, 9  
  JB MOZNA_URUCHOMIC_KOLEJNE_ZADANIE  
  MOV BYTE PTR CZY_MOZNA_KONCZYC, 1  
  JMP PRZERWANIE_1_DALEJ  
  MOZNA_URUCHOMIC_KOLEJNE_ZADANIE: 
;Dodanie do kolejki zadañ uprzywilejowanych kolejnego zadania:
  MOV BX, OFFSET KOLEJKA_ZADAN_UPRZYWILEJOWANYCH   
  CALL URUCHOM_KOLEJNE_ZADANIE      
  PRZERWANIE_1_DALEJ:   
  IN AL, 61H        		;Odczyt bajtu z portu 61h.
  OR AL, 10000000B  		; Suma logiczna otrzymanego bajtu
                    				 ;z ustawionym najstarszym bitem .
  OUT 61H, AL       		;Zablokowanie klawiatury.
  AND AL, 7FH       		;Wyczyszczenie ostatniego bitu.
  OUT 61H, AL       		;Odblokowanie klawiatury.	
  MOV AL, 20H    
  OUT 20H, AL   
  PRZYWROC_REG 1
  IRETD
PRZERWANIE1 ENDP


;Procedura obs³ugi przerwania zegarowego- scheduler:
PRZERWANIE0 PROC
  ZACHOWAJ_REG 1
;Procedura przy ka¿dym wywo³aniu inkrementuje wartoœæ licznika czasu:
  INC DWORD PTR LICZNIK_CZASU  
  CMP BYTE PTR INT_ON, 0 	;Je¿eli wielozadaniowoœæ nie jest aktywowana, to 
                    		;nie mo¿na pozwoliæ na wykonanie siê tej procedury.
  JNE WIELOZADANIOWOSC_JEST_AKTYWOWANA 
  JMP KONIEC_PRZERWANIE_0 
  WIELOZADANIOWOSC_JEST_AKTYWOWANA:  
;Sprawdzenie warunku, czy aby nie nadesz³a pora na prze³¹czenie zadañ:
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
;W przypadku, gdy jakiekolwiek zadanie znajduje siê w kolejce zadañ uprzywilejowanych
;scheduler ignoruje procesy kolejki zadañ zwyk³ych:
  MOV DX, KOLEJKA_ZADAN_UPRZYWILEJOWANYCH.POCZATEK_  
  CMP DX, 0      
  JNE WYKONUJE_SIE_ZADANIE_UPRZYWILEJOWANE    
;Za³adowanie rejestru bx adresem w³aœciwej kolejki zadañ:
  MOV BX, OFFSET KOLEJKA_ZADAN   
  JMP OKRESLONA_KOLEJKA_ZADAN  
  WYKONUJE_SIE_ZADANIE_UPRZYWILEJOWANE:    
;za³adowanie rejestru bx adresem w³aœciwej kolejki zadañ:
  MOV BX, OFFSET KOLEJKA_ZADAN_UPRZYWILEJOWANYCH   
  OKRESLONA_KOLEJKA_ZADAN:   
;Rotacja kolejki zadañ:
  CALL PRZELACZ_ZADANIA
; W tej chwili nale¿y okreœliæ czy mo¿na uruchomiæ zadanie, które znalaz³o siê na pierwszej pozycji kolejki zadañ
;(ze wzglêdu na fakt, ¿e w Intelowskiej architekturze nie mo¿na wywo³ywaæ rekursywnie zadañ).
; W tym celu ID procesu uzyskany z procedury  PRZELACZ_ZADANIA porównywany jest z wartoœci¹
; pola _SELEKTOR_ rozkazu skoku odleg³ego (wartoœæ tego pola okreœla zadanie, na które ostatnio zosta³o 
;dokonane prze³¹czenie- zadanie, w kontekœcie którego nast¹pi³o wywo³anie schedulera):
  MOV CX, 128 
  MOV GS, CX    
  MOV CX, [GS:_SELEKTOR_]    
  CMP CX, DI     
  JNE ZADANIA_SA_ROZNE     
;Wys³anie do kontrolera przerwañ informacji o zakoñczeniu obs³ugi przerwania:
  MOV AL, 60H      
  OUT 20H, AL      
  JMP NIE_MOZNA_PRZELACZYC_ZADAN_  
  ZADANIA_SA_ROZNE:               
;Poni¿sza sekwencja rozkazów wykona siê w przypadku, gdy zadania s¹ ró¿ne.
;Aby prze³¹czyæ zadania potrzebny jest selektor TSS nowego zadania, na które ma nast¹piæ 
;prze³¹czenie- czyli wartoœæ, która znajduje siê obecnie w rejestrze DI. Nale¿y zmodyfikowaæ 
;wartoœæ selektora TSS w instrukcji skoku odleg³ego (nast¹pi prze³¹czenie 
;na w³aœciwe zadanie). Instrukcja skoku odleg³ego zosta³a zapisana w formie 
;maszynowej, by móc zmieniaæ dynamicznie jej parametr wskazuj¹cy selektor TSS.
;Do zmiany tego parametru nale¿a³o przygotowaæ deskryptor opisuj¹cy segment kodu
;(nie mo¿na korzystaæ z rejestru CS, gdy¿ zawartoœci segmentu kodu nie mo¿na modyfikowaæ).

  MOV AX, 128        
  MOV GS, AX    
  MOV [GS:_SELEKTOR_], DI   
  KONIEC_PRZERWANIE_0:    
;Wys³anie do kontrolera przerwañ informacji o tym, ¿e obs³uga obecnego przerwania
;zosta³a zakoñczona:
;Poni¿ej nastêpuje prze³¹czenie na nowe zadanie:
  MOV AL, 60H
  OUT 20H, AL
  CMP BYTE PTR INT_ON, 0
  JE PRZERWANIE_ZEGARA_DALEJ2
    POLECENIE       	DB 0EAH         
    OFFSET_         	DW 12            
    _SELEKTOR_      	DW 40H
  PRZERWANIE_ZEGARA_DALEJ2: 
  NIE_MOZNA_PRZELACZYC_ZADAN_: 
  PRZYWROC_REG 1
  IRETD  
PRZERWANIE0 ENDP


ZNAJDZ_ELEMENT_O_OKRESLONYM_POLU_DANYCH PROC
;Parametry procedury:
;DI - adres pocz¹tkowego elementu kolejki,
;AX - szukane pole danych.
;Wyniki:
;SI - adres szukanego elementu (0 gdy nie zosta³ znaleziony).
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
  CMP AX, [ES:DI]     			;Je¿eli dana z AX jest inna od pola danych elementu 
					;wskazanego par¹ rejestrów ES:DI, to nale¿y kontynuowaæ
					;poszukiwanie od nastêpnego elementu.
  JNE NIE_JEST_TO_JESZCZE_TEN_ELEMENT 
;Je¿eli program dotrze tutaj, to znaczy, ¿e znaleziony zosta³ w³aœciwy element:
  MOV SI, DI 				;£adowany jest do rejestru SI adres elementu. 
  JMP KONIEC_PROCEDURY_ZN_ELEM  
  NIE_JEST_TO_JESZCZE_TEN_ELEMENT: 
  MOV DI, [ES:DI+WIELKOSC_ELEMENTU] 	;O WIELKOSC_ELEMENTU powy¿ej adresu elementu
                              		;znajduje siê wskaŸnik na nastêpny element. 
  CMP DI, 0          			;Je¿eli osi¹gniêto koniec kolejki, to nale¿y opuœciæ procedurê. 
  JNE MOZNA_DALEJ_ZN_ELEM  
  MOV SI, 0

  JMP KONIEC_PROCEDURY_ZN_ELEM 		;Gdy wskaŸnik nastêpnego elementu jest null-em,
                                    	;to nastêpuje wyjœcie z procedury 
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

USUN_ELEMENT_Z_KOLEJKI PROC
;Parametry procedury:
;SI - adres usuwanego elementu,
;DI - adres pocz¹tku kolejki,
;CX - adres koñca kolejki,
;DX - rozmiar pola danych elementu.
;Wyniki:
;BX - nowy pocz¹tek kolejki,
;CX - adres usuniêtego elementu.
  PUSH AX 
  PUSH SI 
  MOV AX, ES   
  PUSH AX 
  MOV AX, 8   
  MOV ES, AX 
  MOV BX, DI  		;Do rejestru BX zostaje zapisany adres pocz¹tku kolejki.
  CMP SI, DI   		;Sprawdzenie warunku, czy usuwany element nie jest pierwszym.
  JNE USOWANY_ELEMENT_NIE_JEST_PIERWSZYM 
;Je¿eli program dotrze w to miejsce, to oznacza, ¿e usuwany jest pierwszy element kolejki. W tym przypadku do rejestru 
;DI zawieraj¹cego adres pierwszego elementu wpisywana jest wartoœæ z pola nastêpny element usuwanego elementu.
  PUSH SI 
  ADD SI, DX      		;Otrzymywany jest w ten sposób adres pola nastêpnego elementu.
  MOV DI, [ES:SI] 		;Po wykonaniu siê tej instrukcji adres pocz¹tku kolejki
                              				;wskazuje na adres elementu nastêpnego.
  MOV BX, DI       		;Adres pocz¹tku kolejki ³adowany do rejestru BX. 
  POP SI  
  JMP KONIEC_PROCEDURY_US_ELEM  
  USOWANY_ELEMENT_NIE_JEST_PIERWSZYM: 
  PUSH DI 			;Zapamiêtanie adresu pierwszego elementu kolejki. 
  CALL ZNAJDZ_ELEMENT_POPRZEDZAJACY  
;Rejestr di zawiera teraz adres elementu poprzedzaj¹cego element usuwany.
  CMP SI, CX      		;Je¿eli element usuwany jest ostatni, to procedura musi zadbaæ 
;o uaktualnienie koñca kolejki (poprzez zwrócenie nowego koñca). 
  JNE USOWANY_ELEMENT_NIE_JEST_OSTATNIM    
  MOV CX, DI     		;Teraz cx wskazuje na nowy koniec kolejki. 
  MOV WORD PTR [ES:DI+WIELKOSC_ELEMENTU], 0
  USOWANY_ELEMENT_NIE_JEST_OSTATNIM:   
  ADD DI, DX 			;Dodawana jest do adresu elementu (zwróconego  przez procedurê
                       		;ZNAJDZ_ELEMENT_POPRZEDZAJACY) wielkoœæ pola danych.          
                       		;Otrzymany w ten sposób zosta³ adres pola nastêpnego elementu.
  ADD SI, DX    
  MOV AX, [ES:SI]  		;Do rejestru AX chowane jest pole nastêpnego elementu
                             	;z elementu usuwanego
  SUB SI, DX   
  MOV [ES:DI], AX 		;W elemencie poprzedzaj¹cym element usuwany, ustawiane
                            	;jest pole nastêpnego elementu, na pole nastêpnego elementu
                            	;zawarte w elemencie usuwanym.
  POP DI     			;Rejestr DI zawiera adres pierwszego elementu kolejki.
  KONIEC_PROCEDURY_US_ELEM:
  CMP BX, 0    			;Je¿eli pocz¹tek kolejki jest ustawiony na 0,
                     		;to koniec kolejki te¿ nale¿y wyzerowaæ.
  JNE MOZNA_KONCZYC  
  XOR CX, CX       
  MOZNA_KONCZYC:  
  POP AX    
  MOV ES, AX      
  POP SI     
  POP AX    
  RET          
USUN_ELEMENT_Z_KOLEJKI ENDP


ZNAJDZ_ELEMENT_POPRZEDZAJACY  PROC
;Parametry procedury:
;SI - adres elementu, wzglêdem którego poszukiwany jest element poprzedzaj¹cy,
;DI - adres pocz¹tku kolejki,
;DX - rozmiar pola danych elementu.
;Wyniki:
;DI - adres poszukiwanego elementu.
  PUSH AX 
  CMP DI, 0  
  JE KONIEC_PETLI_ZN_ELEM_POP ;Je¿eli kolejka jest pusta, to nie ma czego szukaæ.
;W pêtli poszukiwany jest element, którego pole nastêpnego elementu jest równe wartoœci rejestru SI:
  PETLA_ZN_ELEM_POP:          
    ADD DI, DX  		;Otrzymywane jest w ten sposób pole nastêpnego elementu
                        	;(adres elementu + wielkoœæ pola danych = pole nastêpnego elementu).
    MOV AX, [ES:DI] 		;Pole nastêpnego elementu zapisywane do rejestru AX.
    CMP AX, SI      		;Porównanie, czy rejestr AX, nie wskazuje elementu,
                            	;dla którego szukany jest element poprzedzaj¹cy
                            	;(jeœli tak, to ten element w³aœnie zosta³ odnaleziony).
    JNE TO_JESZCZE_NIE_JEST_ELEMENT_POPRZEDZAJACY  
    SUB DI, DX 		;W tej chwili di zawiera adres elementu poprzedzaj¹cego.
    JMP KONIEC_PETLI_ZN_ELEM_POP  
    TO_JESZCZE_NIE_JEST_ELEMENT_POPRZEDZAJACY: 
    MOV DI, AX 
    CMP DI, 0 
    JE KONIEC_PETLI_ZN_ELEM_POP   
    JMP PETLA_ZN_ELEM_POP  
  KONIEC_PETLI_ZN_ELEM_POP: 
  POP AX 
  RET  
ZNAJDZ_ELEMENT_POPRZEDZAJACY  ENDP


USUN_ZADANIE_Z_KOLEJKI_ZADAN PROC
;Parametry procedury:
;AX - ID zadania,
;DS:BX - adres kolejki zadañ.
  PUSH AX  
  PUSH DX
  PUSH BX
  PUSH CX 
  PUSH SI  
  PUSH DI 
  MOV CX, ES 
  PUSH CX   
  MOV CX, 8  
  MOV ES, CX  
  MOV DI,  [BX].POCZATEK_ 
  CALL ZNAJDZ_ELEMENT_O_OKRESLONYM_POLU_DANYCH  
;SI wskazuje adres znalezionego elementu.
  CMP SI, 0     		;Sprawdzenie, czy element znajduje siê w kolejce.
  JE NIE_MA_TAKIEGO_ELEMENTU   
;Przygotowania do usuniêcia elementu z kolejki zadañ:
  MOV DI, [BX].POCZATEK_     
  MOV CX, [BX].KONIEC_       
  MOV DX, WIELKOSC_ELEMENTU    
;SI= adres usuwanego elementu, DI= adres pocz¹tku kolejki, CX= adres koñca kolejki, DX= rozmiar pola danych.
  PUSH BX    
  CALL USUN_ELEMENT_Z_KOLEJKI ;Usuniêcie elementu z kolejki zadañ.
  POP DI    
;W przypadku usuniêcia elementu pierwszego lub ostatniego, nale¿y zmieniæ odpowiednie pola zmiennej 
;KOLEJKA_ZADAN:
  MOV [DI].POCZATEK_, BX 
  MOV [DI].KONIEC_, CX    
;SI zawiera adres usuniêtego z kolejki elementu.
  MOV DI, [DI].ADRES_PULI_     
  CALL DOLOZ_ELEMENT_DO_PULI    
  NIE_MA_TAKIEGO_ELEMENTU:    
  POP CX        
  MOV ES, CX     
  POP DI           
  POP SI   
  POP CX     
  POP BX      
  POP DX       
  POP AX    
  RET    
USUN_ZADANIE_Z_KOLEJKI_ZADAN ENDP

;Po up³ywie okreœlonego czasu zadania uprzywilejowane wywo³uj¹ t¹ procedurê 
;w celu zakoñczenia swojego dzia³ania:
ZAKONCZ_ZADANIE_UPRZYWILEJOWANE PROC
  CLI   
  MOV BX, OFFSET KOLEJKA_ZADAN_UPRZYWILEJOWANYCH 
  CALL  ZWROC_SELEKTOR_TSS_AKTUALNEGO_ZADANIA  
  MOV AX, CX   
  CALL USUN_ZADANIE_Z_KOLEJKI_ZADAN  
  STI  
;Pêtla oczekuje na wywo³anie schedulera, który dokona prze³¹czenia zadañ, ostatecznie
;koñcz¹c zadanie usuniête w procedurze:
  CZEKANIE_NA_DZIALANIE_SCHEDULERA:  
  JMP CZEKANIE_NA_DZIALANIE_SCHEDULERA   
  RET   
ZAKONCZ_ZADANIE_UPRZYWILEJOWANE ENDP

PRZYGOTUJ_NASTEPNE_ZADANIE PROC
;Parametry procedury:
;BX - adres kolejki zadañ.

;Obliczenie adresu TSS dla dodawanego zadania:
  PUSH BX      
  MOV DI, OFFSET TSSY_ZADAN   
  XOR AX, AX             
  XOR DX, DX           
  MOV BX, 104        
  MOV AL, LICZNIK_ZADAN   
  MUL BX                   
  ADD DI, AX              
  INC BYTE PTR LICZNIK_ZADAN   
  MOV WORD PTR [DS:DI+4CH],16 ;Selektor segmentu programu (cs). 
  POP BX               
;W zale¿noœci od parametru procedury wywo³ywane jest albo zadanie uprzywilejowane
;albo zadanie zwyk³e:
  MOV AX, OFFSET KOLEJKA_ZADAN_UPRZYWILEJOWANYCH   
  CMP BX, AX  
  JNE DODAWANE_JEST_NORMALNE_ZADANIE    
  MOV WORD PTR [DS:DI+20H],OFFSET ZADANIE_UP ;Offset w segmencie progr.
  JMP DODANO_WPIS_EIP     
  DODAWANE_JEST_NORMALNE_ZADANIE:    
  MOV WORD PTR [DS:DI+20H],OFFSET ZADANIE	;Offset w segmencie progr. 
  DODANO_WPIS_EIP:  
  MOV WORD PTR [DS:DI+50H],48			;Selektor segmentu stosu (SS). 
  XOR AX, AX  
  XOR DX,DX   
  MOV AL, LICZNIK_ZADAN   
  MOV BX, 100  
  MUL BX 
  MOV WORD PTR [DS:DI+38H], AX			;Offset w segmencie stosu. 
  MOV WORD PTR [DS:DI+54H], 8			;Selektor segmentu danych (DS).
  MOV WORD PTR [DS:DI+48H], 32			;Selektor segmentu danych (ES).
  MOV DWORD PTR [DS:DI+36], 00000000000000000000001000000000B ;EFLAGS z
								;ustawionym IF
  MOV DL, LICZNIK_ZADAN  
  ADD DL, '0' 
  MOV DWORD PTR [DS:DI+48], EDX  
  RET
PRZYGOTUJ_NASTEPNE_ZADANIE ENDP

URUCHOM_KOLEJNE_ZADANIE PROC
  PUSH BX 
  CALL  PRZYGOTUJ_NASTEPNE_ZADANIE  
  XOR AX, AX  
  MOV AL, LICZNIK_ZADAN 
  DEC AL 
  XOR DX, DX    
  MOV BX, 8  
  MUL BX  
  ADD AX, 56  
  POP BX   
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

