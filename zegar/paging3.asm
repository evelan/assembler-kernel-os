.386P
;Selektory obszar�w pami�ci, gdzie umieszczone b�d� struktury danych stronicowania dla zadania:
SELEKTOR_TABLICY_STRON 		EQU 40
SELEKTOR_KATALOGU_STRON 		EQU 48
;Struktura opisuj�ca deskryptor segmentu:
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
;Globalna tablica deskryptor�w  (w komentarzach znajduj� si� selektory segment�w):
INCLUDE GDT.TXT
;Dwa deskryptory wskazuj�ce segmenty tablicy i katalogu stron:
  GDT_TABLICA_STRON DESKR <4095,0H, 1AH, 92H, 0, 0>     		;40
  GDT_KATALOG_STRON DESKR <4095,0H, 1BH, 92H, 0, 0>      		;48
;Deskryptor segmentu zawieraj�cego 3 strony, na kt�rych zostanie zaprezentowany mechanizm pami�ci wirtualnej:
  OBSZARY_PODLEGAJACE_PAMIECI_WIRTUALNEJ DESKR <3000H,0F000H,1FH,92H,0,0> 	;56
  GDT_SIZE = $ - GDT_NULL
;Tablica deskryptor�w przerwa� IDT
  IDT	LABEL WORD
    TRAP 	13 	DUP(<EXC_0>)	;Wyj�tki obs�ugiwane przez jedn� procedur� exc_.
    EXC13   TRAP <EXC_13>
    EXC14   TRAP <EXC_14>   		;wyj�tek wywo�any, gdy nast�pi odwo�anie
                               					;do nieobecnej strony- ma kluczowe znaczenie
                               					;dla pami�ci wirtualnej.
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
;Poni�sza zmienna przechowuje adresy liniowe 2 stron, kt�re w danym momencie
;mog� si� znajdowa� w pami�ci wirtualnej - prosta tablica zachowanych stron:
  ADRESY_W_PAMIECI_WIRTUALNEJ  	DD 2 	DUP 	(0)     
;Symulowana pami�� dyskowa - tablica w pami�ci mog�ca pomie�ci� 2 strony (wirtualny dysk)
  PAMIEC_WIRTUALNA			DB 8192  DUP (0)   
;Zmienna wprowadzona aby przechowa� rejestry eax, ebx, ecx, edx, esi, edi
;w chwili gdy korzystanie ze stosu jest niewygodne (procedura obs�ugi przerwania
;14 otrzymuje na stosie parametry kod b��du, offset powrotu, segment powrotu, EFLAGS
  SCHOWEK_REJESTROW            	DD 6     DUP (0)
;Zmienna przechowuj�ca informacje o liniach, w kt�rych b�dzie odbywa� si� wydruk komunikatu 
;wy�wietlanego przez procedur� obs�ugi wyj�tku 14:
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

EXC_13 PROC			;Procedura obs�ugi wyj�tku nr 13
  MOV AX,32			;(og�lne naruszenie mechanizmu ochrony)
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
  POP AX   			;AX zawiera kod b��du wed�ug schematu:
               			;pierwszy bit: gdy 0- b��d spowodowany nieobecn� stron� gdy 1- obecna strona
                		;bit 2: gdy 0- b��d odczytu, gdy 1 b��d zapisu
                		;bit 3: gdy 0- wywo�a� program na poziomie uprzywilejowania 0, gdy 1- na poziomie user
                		;RSVD                                                       
  TEST AX, 1           		;Je�eli zerowy bit rejestru AX jest wyzerowany, oznacza to
                        	;�e wyj�tek powsta� na skutek napotkania nieobecnej strony.  	
  JZ STRONA_JEST_NIEOBECNA   							
  MOV BX, OFFSET TEKST14_B  						
  MOV DI, 960               							
  CALL WYPISZ_TEKST         						
  JMP KONIEC                							     
  STRONA_JEST_NIEOBECNA:      							
;Wypisanie informacji o tym, ze dzia�a mechanizm pami�ci wirtualnej:
  MOV BX, OFFSET TEKST14      						
  MOV DI, 960                 							
  ADD DI, LINIA_WYDRUKU_INFO  ;Wydruk w kolejnej linii
  ADD LINIA_WYDRUKU_INFO, 160    						
  INC BYTE PTR [TEKST14]         					
  CALL   WYPISZ_TEKST            						    
  POP AX 			;Zdj�cie drugiej cz�ci przekazanego kodu b��du 
;(gdy� jest on 32-bitowy).              
  POP BX 			;Zdj�cie offsetu powrotu.                 			
  POP AX 			;Zdj�cie starszej cz�ci offsetu powrotu (poniewa� dzia�amy w 16 bitowym
             			;trybie chronionym nie b�dzie ona potrzebna).       		
  PUSH BX 			;Od�o�enie m�odszej cz�ci offsetu powrotu (przygotowanie stanu do
 				;wykonania p�niejszej instrukcji IRET).             	
  MOV EAX, CR2  		;Rejestr CR2 zawiera adres liniowy pocz�tku strony kt�ra jest nieobecna 
;(spowodowa�a wyj�tek)   
;Poni�ej nast�pi poszukiwanie w tablicy opisuj�cej strony znajduj�ce si� w pami�ci wirtualnej,  
;indeksu przechowywanej strony:
  MOV ECX, 2  			;Tablica mo�e zawiera� 2 adresy przechowywanych stron, 
				;wi�c licznik p�tli ustawiany na 2. 
  MOV DX, ES    						
  PUSH DX       						      
  XOR EDI, EDI  
  SPRAWDZANIE_OBECNOSCI_STRONY_W_PRZESTRZENI_WIRTUALNEJ: 
;W pierwszej kolejno�ci nale�y ustali� pozycj� strony na �dysku wirtualnym� (dwuelementowa tablica
; adresy_w_pamieci_wirtualnej zawiera adresy aktualnie przechowywanych stron)
    MOV EBX, [ADRESY_W_PAMIECI_WIRTUALNEJ+DI]        	
    CMP EBX, EAX    		;Sprawdzenie czy znaleziono odpowiedni� pozycj� (EAX zawiera adres
				;strony, kt�ra wygenerowa�a wyj�tek, zachowany z CR2 )    			
    JNE NIE_ZNALEZIONO            			
;Je�eli odpowiednia pozycja zostanie odnaleziona nast�puje wywo�anie procedury, kt�ra przywr�ci 
;potrzebna stron� do pami�ci.
    SHR DI, 2    		;Dzielenie przez 4 - rejestr di zawiera� offset w tablicy
                        	;przechowuj�cej adresy zachowanych stron (adresy s� 4 bajtowe)
                        	;aby uzyska� indeks w tej tablicy nale�y podzieli� przez 4.
;Rejestr di zawiera indeks strony, kt�r� nale�y przywr�ci� natomiast w rejestrze EBX zawarty jest adres logiczny tej strony.
    CALL WYMIEN_STRONY      				
    JMP WYMIANA_ZAKONCZONA    			
    NIE_ZNALEZIONO:           				
    ADD DI, 4   		;Adres nast�pnej pozycji tablicy   	
  LOOP  SPRAWDZANIE_OBECNOSCI_STRONY_W_PRZESTRZENI_WIRTUALNEJ 
  WYMIANA_ZAKONCZONA:                             	
  POP DX                                                      	
  MOV ES, DX                                                  	
  POP_REG   							
  IRET      								
EXC_14 ENDP

WYMIEN_STRONY PROC
;Parametry procedury:
;DI ma zawiera� indeks na dysku wirtualnym strony, kt�r� nale�y przywr�ci�
;EBX ma natomiast zawiera� jej adres liniowy.

;Nale�y odnale�� pierwsz� dost�pn� stron� w pami�ci w celu za�adowania w jej miejsce 
;strony, do kt�rej dost�p wygenerowa� wyj�tek.
;Dla uproszczenia tylko 3 strony pocz�wszy od 511 PTE podlegaj� pami�ci wirtualnej.
  MOV AX, SELEKTOR_TABLICY_STRON            		
  MOV ES, AX                                			
  XOR ESI, ESI                              			
  MOV SI, 511*4   		;ES:SI wskazuj� na pierwsze PTE, kt�re podlega
                               	;mechanizmowi pami�ci wirtualnej.
;Nast�puje poszukiwanie pierwszej dost�pnej strony:
  SZUKANIE_OBECNEJ_STRONY:        			
    TEST DWORD PTR [ES:SI], 1         			
    JNZ OBECNA_STRONA_ODNALEZIONA     		
    ADD SI, 4                         			
  JMP  SZUKANIE_OBECNEJ_STRONY         		
  OBECNA_STRONA_ODNALEZIONA:           		
  PUSH CX                              				
  PUSH SI   							
;Obliczanie offsetu w segmencie obszary_podlegajace_pamieci_wirtualnej:
  SHL ESI, 10             	;Mno�enie przez 1024                        
  SHL DI, 2   			;Mno�enie DI przez 4 w celu uzyskania offsetu.     
  MOV [ADRESY_W_PAMIECI_WIRTUALNEJ+DI], ESI ;Adres liniowy strony, kt�ra zostanie 
;przeniesiona na �wirtualny dysk� zapisywany jest w miejsce adresu przywracanej 
;strony (w dalszej cz�ci jej zawarto�� b�dzie r�wnie� zachowywana w pami�ci wirtualnej)
  SHR DI, 2   			;Przywr�cenie indeksu  (dzielenie przez 4).			                                                             
  SUB ESI, 1FF000H 		;Obliczany adres wzgl�dem pocz�tku segmentu podlegaj�cego 
                                 ;pami�ci wirtualnej.					
  MOV AX, 56 
  MOV ES, AX      		;ES:SI wskazuje pocz�tek strony, kt�ra musi zosta� 
;zachowana w pami�ci wirtualnej.

  MOV CX, 1024       							
;DI dot�d zawiera� indeks w tablicy przechowuj�cej stron� umieszczon� w pami�ci wirtualnej, aby uzyska� offset w tej
;tablicy nale�y pomno�y� ten rejestr razy 4096:
  SHL DI, 12    ;mno�enie razy 4096      					
  ADD DI, OFFSET PAMIEC_WIRTUALNA  ;Uzyskany adres w segmencie danych.   	
;Poni�sza p�tla zachowuje stron� dot�d dost�pn� i przywraca stron�, do kt�rej dost�p wygenerowa� wyj�tek:
  KOPIOWANIE_STRONY_DO_BUFORA:        				
    MOV EAX, [ES:SI]   	;EAX zawiera 4 kolejne bajty strony, kt�r� nale�y zachowa� 
;w pami�ci wirtualnej       
    MOV EDX, [DS:DI]   	;EDX zawiera 4 kolejne bajty strony, kt�ra jest przywracana do pami�ci                               
    MOV [ES:SI], EDX   	;Przywr�cenie 4 bajt�w strony.		
    MOV [DS:DI], EAX   	;Zachowanie 4 bajt�w strony.   				
    ADD SI, 4            						
    ADD DI, 4            							
  LOOP KOPIOWANIE_STRONY_DO_BUFORA          			
  POP SI  			;SI zawiera offset PTE, kt�re nale�y ustawi� na nieobecne.  
  POP CX               							
  SHR EBX, 12 			;BX zawiera offset PTE, kt�re nale�y ustawi� na
                          	;dost�pne  (gdy� strona zosta�a przywr�cona)   		
  SHL BX, 2                 							
  MOV AX,   SELEKTOR_TABLICY_STRON              			
  MOV ES, AX                                    		
  AND DWORD PTR [ES:SI], 0FFFFFFFEH  ;Wyzerowanie bitu P w PTE strony,
                                     ;kt�ra zosta�a zachowana na dysku wirtualnym.
  OR DWORD PTR [ES:BX], 1 	;Ustawienie bitu P w PTE strony,
                                ;kt�ra zosta�a przywr�cona do pami�ci.
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
;Zapisanie 4096 jedynek do strony o adresie 1FF000h- strona ta jest w pami�ci:
  MOV AL, 1 
  MOV ECX, 4096              						
  REP STOSB      		;stosb automatycznie zwi�ksza rejestr DI.
;zapisanie 4096 tr�jek do strony o adresie 200000- strony nie ma, zostanie wywo�any mechanizm pami�ci wirtualnej:	
  MOV AL, 3            							
  MOV ECX, 4096        						
  REP STOSB   			;stosb automatycznie zwi�ksza rejestr DI.
;Zapisanie 4096 si�demek do strony o adresie 201000- strony nie ma, zostanie wywo�any mechanizm pami�ci wirtualnej:  
  MOV AL, 7                        					
  MOV ECX, 4096                    					
  REP STOSB  			;stosb automatycznie zwi�ksza rejestr DI.	 
;Sprawdzenie warunku, czy mechanizm pami�ci wirtualnej zadzia�a� w 100% prawid�owo. Dodanie wszystkich bajt�w 
;3 stron do siebie powinno wynie��: ;4096*1 + 4096*3 + 4096*7= 45056 czyli w przeliczeniu na system 
;szesnastkowy B000. Dost�p do wszystkich 3 stron poci�gnie za sob� konieczno�� wykorzystania
;mechanizm�w pami�ci wirtualnej:
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
;Prze��czenie procesora w tryb rzeczywisty:
  MIEKI_POWROT_RM
  POWROT_DO_RM 1,1

PRZYGOTOWANIE_STRONICOWANIA PROC                   	
  MOV AX, SELEKTOR_TABLICY_STRON                  			
  MOV ES, AX                                      			
  XOR DI, DI                                      			
;Ustawienie odpowiednich p�l PTE:
  XOR EAX, EAX         							
  MOV AL, 00000011B   	;0, D, A, PCD, PWT, U/S, R/W, P      	 
  MOV AH, 0000B       	;AV, G                               	 
  MOV ECX, 2048/4     	;Ilo�� stron w 2 MB pami�ci             		
  XOR EDX, EDX                             				
  CLD                                      					
;Tworzenie tablicy stron dla pierwszych 2 MB pami�ci:
  TWORZENIE_TABLICY_STRON:     					
    AND EAX, 00000FFFH        						
    OR EAX, EDX               						
    STOSD                     						
    ADD EDX, 1000H            						
  LOOP TWORZENIE_TABLICY_STRON 					 
;Poni�ej tworzone s� dwie strony wskazuj�ce na ta sama ramk�, co ostatnia strona utworzona w powy�szej p�tli, 
;dodatkowo w obu stronach bit P (obecno�ci) zostaje wyzerowany:
  SUB EDX, 1000H          						
  AND EAX, 00000FFEH      						
  OR EAX, EDX             							
  STOSD             	;W przestrzeni adresowej pierwsza strona powy�ej 2MB oznaczona jako nieobecna  			
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

