.386P
;Selektory obszarów pamiêci, gdzie umieszczone bêd¹ struktury danych stronicowania dla zadania:
SELEKTOR_TABLICY_STRON 		EQU 40
SELEKTOR_KATALOGU_STRON 		EQU 48
;Struktura opisuj¹ca deskryptor segmentu:
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
;Globalna tablica deskryptorów  (w komentarzach znajduj¹ siê selektory segmentów):
INCLUDE GDT.TXT
;Dwa deskryptory wskazuj¹ce segmenty tablicy i katalogu stron:
  GDT_TABLICA_STRON DESKR <4095,0H, 1AH, 92H, 0, 0>     		;40
  GDT_KATALOG_STRON DESKR <4095,0H, 1BH, 92H, 0, 0>      		;48
;Deskryptor segmentu zawieraj¹cego 3 strony, na których zostanie zaprezentowany mechanizm pamiêci wirtualnej:
  OBSZARY_PODLEGAJACE_PAMIECI_WIRTUALNEJ DESKR <3000H,0F000H,1FH,92H,0,0> 	;56
  GDT_SIZE = $ - GDT_NULL
;Tablica deskryptorów przerwañ IDT
  IDT	LABEL WORD
    TRAP 	13 	DUP(<EXC_0>)	;Wyj¹tki obs³ugiwane przez jedn¹ procedurê exc_.
    EXC13   TRAP <EXC_13>
    EXC14   TRAP <EXC_14>   		;wyj¹tek wywo³any, gdy nast¹pi odwo³anie
                               					;do nieobecnej strony- ma kluczowe znaczenie
                               					;dla pamiêci wirtualnej.
  IDT_SIZE = $ - IDT
  PDESKR		DQ 0
  ORG_IDT    	DQ 0
  TEKST	  	DB 'TRYB CHRONIONY',0
  TEKST13 	DB 'OGOLNE NARUSZENIE MECHANIZMU OCHRONY'
  TEKST14   	DB '0 NATRAFIONO NA NIEOBECNA STRONE- DZIALA MECHANIZM PAMIECI WIRTUALNEJ',0
  TEKST14_B  	DB 'BLAD NARUSZENIA ZASAD STRONICOWANIA ', 0
  WYNIK      	DB 'WYNIK DODAWANIA BAJTOW ZE STRON:', 0
  ATRYB13 	DB 0FAH
  INFO		DB 'POWROT Z TRYBU CHRONIONEGO $'
;Poni¿sza zmienna przechowuje adresy liniowe 2 stron, które w danym momencie
;mog¹ siê znajdowaæ w pamiêci wirtualnej - prosta tablica zachowanych stron:
  ADRESY_W_PAMIECI_WIRTUALNEJ  	DD 2 	DUP 	(0)     
;Symulowana pamiêæ dyskowa - tablica w pamiêci mog¹ca pomieœciæ 2 strony (wirtualny dysk)
  PAMIEC_WIRTUALNA			DB 8192  DUP (0)   
;Zmienna wprowadzona aby przechowaæ rejestry eax, ebx, ecx, edx, esi, edi
;w chwili gdy korzystanie ze stosu jest niewygodne (procedura obs³ugi przerwania
;14 otrzymuje na stosie parametry kod b³êdu, offset powrotu, segment powrotu, EFLAGS
  SCHOWEK_REJESTROW            	DD 6     DUP (0)
;Zmienna przechowuj¹ca informacje o liniach, w których bêdzie odbywa³ siê wydruk komunikatu 
;wyœwietlanego przez procedurê obs³ugi wyj¹tku 14:
  LINIA_WYDRUKU_INFO           	DW 0   
  A20     	DB 0
  FAST_A20 	DB 0
  DANE_SIZE = $ - GDT_NULL
DANE	ENDS

PROGRAM	SEGMENT 'CODE' USE16
  ASSUME CS:PROGRAM, DS:DANE, SS:STK
POCZ	LABEL WORD

INCLUDE MAKRA.TXT

EXC_0 PROC
EXC_0 ENDP

EXC_13 PROC			;Procedura obs³ugi wyj¹tku nr 13
  MOV AX,32			;(ogólne naruszenie mechanizmu ochrony)
  MOV ES,AX
  MOV BX,OFFSET TEKST13
  MOV CX,36
  MOV AL,[BX]
  MOV SI,0
  PETLA13:MOV ES:[SI+1000],AL
    MOV AL,ATRYB13
    MOV ES:[SI+1001],AL
    ADD BX,1
    ADD SI,2
    MOV AL,[BX]  
  LOOP PETLA13
  JMP KONIEC
EXC_13 ENDP

EXC_14 PROC
  PUSH_REG     		                                      			
  POP AX   			;AX zawiera kod b³êdu wed³ug schematu:
               			;pierwszy bit: gdy 0- b³¹d spowodowany nieobecn¹ stron¹ gdy 1- obecna strona
                		;bit 2: gdy 0- b³¹d odczytu, gdy 1 b³¹d zapisu
                		;bit 3: gdy 0- wywo³a³ program na poziomie uprzywilejowania 0, gdy 1- na poziomie user
                		;RSVD                                                       
  TEST AX, 1           		;Je¿eli zerowy bit rejestru AX jest wyzerowany, oznacza to
                        	;¿e wyj¹tek powsta³ na skutek napotkania nieobecnej strony.  	
  JZ STRONA_JEST_NIEOBECNA   							
  MOV BX, OFFSET TEKST14_B  						
  MOV DI, 960               							
  CALL WYPISZ_TEKST         						
  JMP KONIEC                							     
  STRONA_JEST_NIEOBECNA:      							
;Wypisanie informacji o tym, ze dzia³a mechanizm pamiêci wirtualnej:
  MOV BX, OFFSET TEKST14      						
  MOV DI, 960                 							
  ADD DI, LINIA_WYDRUKU_INFO  ;Wydruk w kolejnej linii
  ADD LINIA_WYDRUKU_INFO, 160    						
  INC BYTE PTR [TEKST14]         					
  CALL   WYPISZ_TEKST            						    
  POP AX 			;Zdjêcie drugiej czêœci przekazanego kodu b³êdu 
;(gdy¿ jest on 32-bitowy).              
  POP BX 			;Zdjêcie offsetu powrotu.                 			
  POP AX 			;Zdjêcie starszej czêœci offsetu powrotu (poniewa¿ dzia³amy w 16 bitowym
             			;trybie chronionym nie bêdzie ona potrzebna).       		
  PUSH BX 			;Od³o¿enie m³odszej czêœci offsetu powrotu (przygotowanie stanu do
 				;wykonania póŸniejszej instrukcji IRET).             	
  MOV EAX, CR2  		;Rejestr CR2 zawiera adres liniowy pocz¹tku strony która jest nieobecna 
;(spowodowa³a wyj¹tek)   
;Poni¿ej nast¹pi poszukiwanie w tablicy opisuj¹cej strony znajduj¹ce siê w pamiêci wirtualnej,  
;indeksu przechowywanej strony:
  MOV ECX, 2  			;Tablica mo¿e zawieraæ 2 adresy przechowywanych stron, 
				;wiêc licznik pêtli ustawiany na 2. 
  MOV DX, ES    						
  PUSH DX       						      
  XOR EDI, EDI  
  SPRAWDZANIE_OBECNOSCI_STRONY_W_PRZESTRZENI_WIRTUALNEJ: 
;W pierwszej kolejnoœci nale¿y ustaliæ pozycjê strony na „dysku wirtualnym” (dwuelementowa tablica
; adresy_w_pamieci_wirtualnej zawiera adresy aktualnie przechowywanych stron)
    MOV EBX, [ADRESY_W_PAMIECI_WIRTUALNEJ+DI]        	
    CMP EBX, EAX    		;Sprawdzenie czy znaleziono odpowiedni¹ pozycjê (EAX zawiera adres
				;strony, która wygenerowa³a wyj¹tek, zachowany z CR2 )    			
    JNE NIE_ZNALEZIONO            			
;Je¿eli odpowiednia pozycja zostanie odnaleziona nastêpuje wywo³anie procedury, która przywróci 
;potrzebna stronê do pamiêci.
    SHR DI, 2    		;Dzielenie przez 4 - rejestr di zawiera³ offset w tablicy
                        	;przechowuj¹cej adresy zachowanych stron (adresy s¹ 4 bajtowe)
                        	;aby uzyskaæ indeks w tej tablicy nale¿y podzieliæ przez 4.
;Rejestr di zawiera indeks strony, któr¹ nale¿y przywróciæ natomiast w rejestrze EBX zawarty jest adres logiczny tej strony.
    CALL WYMIEN_STRONY      				
    JMP WYMIANA_ZAKONCZONA    			
    NIE_ZNALEZIONO:           				
    ADD DI, 4   		;Adres nastêpnej pozycji tablicy   	
  LOOP  SPRAWDZANIE_OBECNOSCI_STRONY_W_PRZESTRZENI_WIRTUALNEJ 
  WYMIANA_ZAKONCZONA:                             	
  POP DX                                                      	
  MOV ES, DX                                                  	
  POP_REG   							
  IRET      								
EXC_14 ENDP

WYMIEN_STRONY PROC
;Parametry procedury:
;DI ma zawieraæ indeks na dysku wirtualnym strony, któr¹ nale¿y przywróciæ
;EBX ma natomiast zawieraæ jej adres liniowy.

;Nale¿y odnaleŸæ pierwsz¹ dostêpn¹ stronê w pamiêci w celu za³adowania w jej miejsce 
;strony, do której dostêp wygenerowa³ wyj¹tek.
;Dla uproszczenia tylko 3 strony pocz¹wszy od 511 PTE podlegaj¹ pamiêci wirtualnej.
  MOV AX, SELEKTOR_TABLICY_STRON            		
  MOV ES, AX                                			
  XOR ESI, ESI                              			
  MOV SI, 511*4   		;ES:SI wskazuj¹ na pierwsze PTE, które podlega
                               	;mechanizmowi pamiêci wirtualnej.
;Nastêpuje poszukiwanie pierwszej dostêpnej strony:
  SZUKANIE_OBECNEJ_STRONY:        			
    TEST DWORD PTR [ES:SI], 1         			
    JNZ OBECNA_STRONA_ODNALEZIONA     		
    ADD SI, 4                         			
  JMP  SZUKANIE_OBECNEJ_STRONY         		
  OBECNA_STRONA_ODNALEZIONA:           		
  PUSH CX                              				
  PUSH SI   							
;Obliczanie offsetu w segmencie obszary_podlegajace_pamieci_wirtualnej:
  SHL ESI, 10             	;Mno¿enie przez 1024                        
  SHL DI, 2   			;Mno¿enie DI przez 4 w celu uzyskania offsetu.     
  MOV [ADRESY_W_PAMIECI_WIRTUALNEJ+DI], ESI ;Adres liniowy strony, która zostanie 
;przeniesiona na „wirtualny dysk” zapisywany jest w miejsce adresu przywracanej 
;strony (w dalszej czêœci jej zawartoœæ bêdzie równie¿ zachowywana w pamiêci wirtualnej)
  SHR DI, 2   			;Przywrócenie indeksu  (dzielenie przez 4).			                                                             
  SUB ESI, 1FF000H 		;Obliczany adres wzglêdem pocz¹tku segmentu podlegaj¹cego 
                                 ;pamiêci wirtualnej.					
  MOV AX, 56 
  MOV ES, AX      		;ES:SI wskazuje pocz¹tek strony, która musi zostaæ 
;zachowana w pamiêci wirtualnej.

  MOV CX, 1024       							
;DI dot¹d zawiera³ indeks w tablicy przechowuj¹cej stronê umieszczon¹ w pamiêci wirtualnej, aby uzyskaæ offset w tej
;tablicy nale¿y pomno¿yæ ten rejestr razy 4096:
  SHL DI, 12    ;mno¿enie razy 4096      					
  ADD DI, OFFSET PAMIEC_WIRTUALNA  ;Uzyskany adres w segmencie danych.   	
;Poni¿sza pêtla zachowuje stronê dot¹d dostêpn¹ i przywraca stronê, do której dostêp wygenerowa³ wyj¹tek:
  KOPIOWANIE_STRONY_DO_BUFORA:        				
    MOV EAX, [ES:SI]   	;EAX zawiera 4 kolejne bajty strony, któr¹ nale¿y zachowaæ 
;w pamiêci wirtualnej       
    MOV EDX, [DS:DI]   	;EDX zawiera 4 kolejne bajty strony, która jest przywracana do pamiêci                               
    MOV [ES:SI], EDX   	;Przywrócenie 4 bajtów strony.		
    MOV [DS:DI], EAX   	;Zachowanie 4 bajtów strony.   				
    ADD SI, 4            						
    ADD DI, 4            							
  LOOP KOPIOWANIE_STRONY_DO_BUFORA          			
  POP SI  			;SI zawiera offset PTE, które nale¿y ustawiæ na nieobecne.  
  POP CX               							
  SHR EBX, 12 			;BX zawiera offset PTE, które nale¿y ustawiæ na
                          	;dostêpne  (gdy¿ strona zosta³a przywrócona)   		
  SHL BX, 2                 							
  MOV AX,   SELEKTOR_TABLICY_STRON              			
  MOV ES, AX                                    		
  AND DWORD PTR [ES:SI], 0FFFFFFFEH  ;Wyzerowanie bitu P w PTE strony,
                                     ;która zosta³a zachowana na dysku wirtualnym.
  OR DWORD PTR [ES:BX], 1 	;Ustawienie bitu P w PTE strony,
                                ;która zosta³a przywrócona do pamiêci.
  MOV EAX, CR3            	;FLASH Cachingu            		
  MOV CR3, EAX                       				
  RET
WYMIEN_STRONY ENDP

START:
  CZY_DOSTEPNY_FAST_A20
  CLI
  XOR EAX,EAX	
  INICJOWANIE_DESKRYPTOROW			
  MOV AX, DANE           					
  SHL EAX,4					
  MOV EBP,EAX		                            				
  INICJACJA_IDTR
  A20_ON
  AKTYWACJA_PM
  MOV AX,32             		 				
  MOV ES,AX              						
  CALL PM_WYMAZ_EKRAN    					
  MOV DI, 680            						
  MOV BX, OFFSET TEKST   						
  CALL  WYPISZ_TEKST     					      
  CALL PRZYGOTOWANIE_STRONICOWANIA      		    
  MOV AX, 56                            				
  MOV ES, AX                            				
  XOR SI, SI                            				
  XOR DI, DI                            				
;Zapisanie 4096 jedynek do strony o adresie 1FF000h- strona ta jest w pamiêci:
  MOV AL, 1 
  MOV ECX, 4096              						
  REP STOSB      		;stosb automatycznie zwiêksza rejestr DI.
;zapisanie 4096 trójek do strony o adresie 200000- strony nie ma, zostanie wywo³any mechanizm pamiêci wirtualnej:	
  MOV AL, 3            							
  MOV ECX, 4096        						
  REP STOSB   			;stosb automatycznie zwiêksza rejestr DI.
;Zapisanie 4096 siódemek do strony o adresie 201000- strony nie ma, zostanie wywo³any mechanizm pamiêci wirtualnej:  
  MOV AL, 7                        					
  MOV ECX, 4096                    					
  REP STOSB  			;stosb automatycznie zwiêksza rejestr DI.	 
;Sprawdzenie warunku, czy mechanizm pamiêci wirtualnej zadzia³a³ w 100% prawid³owo. Dodanie wszystkich bajtów 
;3 stron do siebie powinno wynieœæ: ;4096*1 + 4096*3 + 4096*7= 45056 czyli w przeliczeniu na system 
;szesnastkowy B000. Dostêp do wszystkich 3 stron poci¹gnie za sob¹ koniecznoœæ wykorzystania
;mechanizmów pamiêci wirtualnej:
  XOR DI, DI                   						
  MOV ECX, 4096*3              					
  XOR EAX, EAX                   						
  XOR BX, BX                   						
  PETLA_DODAWANIA_WARTOSCI_ZE_STRON: 		
    MOV BL, [ES:DI]                           			
    ADD AX, BX                                				
    INC DI                                    				
  LOOP PETLA_DODAWANIA_WARTOSCI_ZE_STRON       
  CALL DRUKUJ_HEX                              			
  MOV DI, 1840                                 				
  MOV BX, OFFSET WYNIK                         				
  CALL WYPISZ_TEKST                            			
;Prze³¹czenie procesora w tryb rzeczywisty:
  MIEKI_POWROT_RM
  POWROT_DO_RM 1,1

PRZYGOTOWANIE_STRONICOWANIA PROC                   	
  MOV AX, SELEKTOR_TABLICY_STRON                  			
  MOV ES, AX                                      			
  XOR DI, DI                                      			
;Ustawienie odpowiednich pól PTE:
  XOR EAX, EAX         							
  MOV AL, 00000011B   	;0, D, A, PCD, PWT, U/S, R/W, P      	 
  MOV AH, 0000B       	;AV, G                               	 
  MOV ECX, 2048/4     	;Iloœæ stron w 2 MB pamiêci             		
  XOR EDX, EDX                             				
  CLD                                      					
;Tworzenie tablicy stron dla pierwszych 2 MB pamiêci:
  TWORZENIE_TABLICY_STRON:     					
    AND EAX, 00000FFFH        						
    OR EAX, EDX               						
    STOSD                     						
    ADD EDX, 1000H            						
  LOOP TWORZENIE_TABLICY_STRON 					 
;Poni¿ej tworzone s¹ dwie strony wskazuj¹ce na ta sama ramkê, co ostatnia strona utworzona w powy¿szej pêtli, 
;dodatkowo w obu stronach bit P (obecnoœci) zostaje wyzerowany:
  SUB EDX, 1000H          						
  AND EAX, 00000FFEH      						
  OR EAX, EDX             							
  STOSD             	;W przestrzeni adresowej pierwsza strona powy¿ej 2MB oznaczona jako nieobecna  			
  MOV EBX, 200000H  							
  MOV ADRESY_W_PAMIECI_WIRTUALNEJ,  EBX    			
  STOSD                                    				
  ADD EBX, 1000H                           				
  MOV [ADRESY_W_PAMIECI_WIRTUALNEJ+4], EBX 			
;Utworzenie jednego wpisu PDE w katalogu stron:
  MOV AX, SELEKTOR_KATALOGU_STRON           				
  MOV ES, AX                                				
  XOR DI, DI                                				
  XOR EAX, EAX                              				
  MOV EDX, 1A0000H 		;Adres zerowej tablicy stron.       	 
  MOV AL, 00000011B   		;PS, 0, A, PCD, PWT, U/S, R/W, P 
  MOV AH, 0000B      		;AV, G                  				 
  OR EAX, EDX         							
  STOSD               							
  MOV EAX, 1B0000H 		;Adres katalogu stron       		
  MOV CR3, EAX     							
  MOV EAX, CR0     							
  OR EAX, 80000000H      						
  MOV CR0, EAX         		;Ustawienie 32-bitu rejestru CR0.  	
  JMP $+2            
  RET
PRZYGOTOWANIE_STRONICOWANIA ENDP
	
INCLUDE PROC.TXT
	
PROGRAM_SIZE = $ - POCZ
PROGRAM ENDS

STK	SEGMENT STACK 'STACK'
  DB 256 DUP(?)
STK	ENDS
END START

