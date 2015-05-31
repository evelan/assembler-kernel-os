.386P
;Selektory segmentów, gdzie umieszczone bêd¹ struktury danych stronicowania zadania g³ównego:
SELEKTOR_TABLICY_STRON 			EQU 72
SELEKTOR_KATALOGU_STRON 		EQU 80
;Selektory segmentów, gdzie umieszczone bêd¹ struktury danych stronicowania zadania 1:
SELEKTOR_TABLICY_STRON_1 		EQU 88
SELEKTOR_KATALOGU_STRON_1 		EQU 96
;Selektory segmentów, gdzie umieszczone bêd¹ struktury danych stronicowania zadania 2:
SELEKTOR_TABLICY_STRON_2 		EQU 104
SELEKTOR_KATALOGU_STRON_2 		EQU 112
;Selektor segmentu danych obu zadañ:
SELEKTOR_SEGMENTU_DANYCH_ZADAN 		EQU 120
;Struktura opisuj¹ca deskryptor segmentu
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
;Globalna tablica deskryptorów  (w komentarzach znajduj¹ siê selektory segmentów)
  INCLUDE GDT.TXT
  GDT_HIMEM	DESKR <0FFFFH,0H,10H,92H,0,0>	;Selektor 40, pamiêæ rozszerzona
  GDT_TSS_0	DESKR <103,0,0,89H>		;Selektor 48, deskryptor TSS_0
  GDT_TSS_1	DESKR <103,0,0,89H>		;Selektor 56, deskryptor TSS_1
  GDT_TSS_2  	DESKR <103,0,0,89H>     	;Selektor 64, deskryptor TSS_2
;Elementy stronicowania dla zadania g³ównego
  GDT_TABLICA_STRON		DESKR <4095,0H,1EH,92H,0,0> 		;72
  GDT_KATALOG_STRON 		DESKR <4095,0H,1FH,92H,0,0>     	;80
;Elementy stronicowania dla zadania 1
  GDT_TABLICA_STRON1		DESKR <4095,0C000H,10H,92H,0,0>    	;88
  GDT_KATALOG_STRON1 		DESKR <4095,0D000H,10H,92H,0,0>  	;96
;Elementy stronicowania dla zadania 2
  GDT_TABLICA_STRON2 		DESKR <4095,0A000H,10H,92H,0,0>   	;104
  GDT_KATALOG_STRON2 		DESKR <4095,0B000H,10H,92H,0,0>  	;112
;Deskryptor ten opisuje segment danych dwóch uruchomionych zadañ. Gdyby stronicowanie nie by³o uruchomione, 
;obydwa zadania mia³yby ten sam segment danych
  GDT_SEGMENT_DANYCH_ZADAN 	DESKR <4095,00000H,10H,92H,0,0>      	;120
;Stosy obydwu zadañ
  GDT_STACK_1			DESKR <4095,08000H,10H,92H,0,0>  	;128
  GDT_STACK_2			DESKR <4095,07000H,10H,92H,0,0>  	;136
;Deskryptor stworzony dla zadania g³ównego, aby mog³o skopiowaæ odpowiedni napis do obydwu segmentów danych zadañ
  GDT_DANE_ZADAN  		DESKR <3000H,00000H,10H,92H,0,0>  	;144
  GDT_KOPIA_PAMIECI_H 		DESKR <0FFFFH, 0000H,18H,92H,0,0> 	;152

  GDT_SIZE=$-GDT_NULL		;Rozmiar GDT

  PDESKR		DQ	0		;Pseudodeskryptor
  ORG_IDT    	DQ    0
  INFO		DB 'POWROT Z TRYBU CHRONIONEGO $'
  T1		DB 'ZADANIE PIERWOTNE PRZED PRZELACZENIEM ZADANIA'
  T2		DB 'ZADANIE ZAGNIEZDZONE 1, TEKST SPOD ADRESU LINIOWEGO 100000H !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  '
  T2_2      	DB 'ZADANIE ZAGNIEZDZONE 2, TEN SAM ADRES LINIOWY A INNY TEKST ???? :) - OCHRONA ZAPEWNIONA PRZEZ STRONICOWANIE DZIALA  '
  T3		DB 'ZADANIE PIERWOTNE PO POWROCIE Z ZADANIA ZAGNIEZDZONEGO'
  TSS_0		DB 	104	DUP(0)	;Segment stanu zadania 0 (proc. main)
  TSS_1		DB 	104 	DUP(0)	;Segment stanu zadania 1
  TSS_2      	DB 	104  	DUP(0)	;Segment stanu zadania 2
  TASK0_OFFS	DW	0		;4-bajtowy adres dla prze³¹czenia
  TASK0_SEL	DW	48		;na zadanie 0 przez TSS.
  TASK1_OFFS	DW	0		;4-bajtowy adres dla prze³¹czenia
  TASK1_SEL	DW	56		;na zadanie 1 przez TSS_1.
  TASK2_OFFS	DW	0		;4-bajtowy adres dla prze³¹czenia
  TASK2_SEL	DW	64		;na zadanie 1 przez TSS_1.
  A20     	DB 0
  FAST_A20 	DB 0
  DANE_SIZE=$-GDT_NULL			;Rozmiar segmentu danych
DANE	ENDS

PROGRAM	SEGMENT 'CODE' USE16
ASSUME CS:PROGRAM,DS:DANE
BEGIN	LABEL WORD

INCLUDE MAKRA.TXT

MAIN	PROC
  CZY_DOSTEPNY_FAST_A20
  CLI
  INICJOWANIE_DESKRYPTOROW
  XOR EAX,EAX                     		
  MOV AX,DANE                     		
  SHL EAX,4                     			
  MOV EBP,EAX                   	
;Okreœlenie adresu liniowego segmentu stanu zadania TSS_0 i zapis do
;deskryptora GDT_TSS_0 w tablicy GDT
  XOR EAX,EAX                			
  MOV AX,OFFSET TSS_0        		
  ADD EAX,EBP                			
  MOV BX,OFFSET GDT_TSS_0    		
  MOV [BX].BASE_1,AX         		
  ROL EAX,16                 			
  MOV [BX].BASE_M,AL         		
;Okreœlenie adresu liniowego segmentu stanu zadania TSS_1
  XOR EAX,EAX                			
  MOV AX,OFFSET TSS_1        		
  ADD EAX,EBP                			
  MOV BX,OFFSET GDT_TSS_1    		 
  MOV [BX].BASE_1,AX         		 
  ROL EAX,16                 			 
  MOV [BX].BASE_M,AL         		 
;Okreœlenie adresu liniowego segmentu stanu zadania TSS_2
  XOR EAX,EAX                			
  MOV AX,OFFSET TSS_2        		
  ADD EAX,EBP                			
  MOV BX,OFFSET GDT_TSS_2    		
  MOV [BX].BASE_1,AX         		 
  ROL EAX,16                 			
  MOV [BX].BASE_M,AL         		

  MOV DWORD PTR TSS_0+1CH, 1F0000H   	   ;Chocia¿ wiêkszoœæ danych w segmencie
                                           ;TSS dla zadania g³ównego nie trzeba inicjowaæ, ustawienie pola okreœlaj¹cego
                                           ;wartoœæ rejestru CR3 jest niezbêdne
;Segmentu stanu zadania TSS_0 nie trzeba inicjalizowaæ w ca³oœci natomiast niezbêdna jest inicjalizacja segmentu stanu
;zadania TSS_1  i TSS_2
  MOV WORD PTR TSS_1+4CH,16		;Selektor segmentu programu (CS)   		
  MOV WORD PTR TSS_1+20H,OFFSET ZADANIE_1;Offset w segmencie progr.    	
  MOV WORD PTR TSS_1+50H,128		;Selektor segmentu stosu (SS)        		
  MOV WORD PTR TSS_1+38H, 4095		;Offset w segmencie stosu            	
  MOV WORD PTR TSS_1+54H, SELEKTOR_SEGMENTU_DANYCH_ZADAN ;Selektor
              						;segmentu danych (DS)  	
  MOV WORD PTR TSS_1+48H,32		;Selektor segmentu danych (ES) 		
  MOV DWORD PTR TSS_1+1CH, 10D000H 	;Pole okresla zawartosc rejestru CR3  	
;TSS_2:
  MOV WORD PTR TSS_2+4CH,16		;Selektor segmentu programu (CS)    		
  MOV WORD PTR TSS_2+20H,OFFSET ZADANIE_2;Offset w segmencie progr.   	
  MOV WORD PTR TSS_2+50H,136		;Selektor segmentu stosu (SS)       		
  MOV WORD PTR TSS_2+38H, 4095		;Offset w segmencie stosu           	
  MOV WORD PTR TSS_2+54H, SELEKTOR_SEGMENTU_DANYCH_ZADAN  ;Selektor segmentu 
;danych (DS) 
  MOV WORD PTR TSS_2+48H,32		;Selektor segmentu danych (ES)  		
  MOV DWORD PTR TSS_2+1CH, 10B000H 	;Pole okreœla zawartoœæ rejestru CR3	
;Przygotowanie do prze³¹czenia w tryb protected
  CLI                 							
  A20_ON		
  AKTYWACJA_PM
  MOV AX,32                            		
  MOV ES,AX                            		
  MOV AX,40                            		
  MOV GS,AX                            		
  MOV FS,AX                            		
  CALL PM_WYMAZ_EKRAN 			;Wymazanie ekranu     
  KOPIUJ_PAMIEC_H
  CALL PRZYGOTOWANIE_STRONICOWANIA	;Przygotowanie wszystkich elementów 
					;stronicowania  zadañ i uruchomienie stronicowania.  
;Segment danych zadania pierwszego wype³niany jest tekstem T2
  MOV AX, 144              			
  MOV ES, AX               			
  MOV DI, 1000H            			
  MOV SI, OFFSET T2        			
  MOV ECX, 114             			
  CLD                      				
  REP MOVSB                			
;Analogiczna czynnoœæ dla zadania 2- segment wype³niany tekstem T2_2:
  MOV DI, 2000H            			
  MOV SI, OFFSET T2_2      			
  MOV ECX, 114             			
  REP MOVSB                			
;Za³adowanie rejestru zadania TR selektorem segmentu stanu zadania TSS nr 0:
  MOV AX,48               			
  LTR AX                  			
;Prze³¹czenie na zadanie nr 1 oraz 2 rozkazem JMP:
  JMP DWORD PTR TASK1_OFFS		
  JMP DWORD PTR TASK2_OFFS		
;Zakoñczenie programu g³ównego:
  PRZYWROC_PAMIEC_H
  MIEKI_POWROT_RM
  POWROT_DO_RM 1,0
MAIN ENDP

PRZYGOTOWANIE_STRONICOWANIA PROC	
;Tworzenie elementów stronicowania dla zadania g³ównego:
  MOV AX, SELEKTOR_TABLICY_STRON    	
  MOV ES, AX                        		
  XOR DI, DI                        		
;Ustawienie odpowiednich pól PTE:
  XOR EAX, EAX                      		
  MOV AL, 00000011B 		;0, D, A, PCD, PWT, U/S, R/W, P    	
  MOV AH, 0000B       		;AV, G               				
  MOV ECX, 2048/4     		;Liczba stron w 2 MB pamiêci		
  XOR EDX, EDX                                            		
  CLD                                                     				
;Tworzenie tablicy stron dla pierwszych 2MB
  TWORZENIE_TABLICY_STRON:                               		
    AND EAX, 00000FFFH                                  		
    OR EAX, EDX                                         		
    STOSD                                               		
    ADD EDX, 1000H                                      		
  LOOP TWORZENIE_TABLICY_STRON                           			
;Utworzenie jednego wpisu PDE w katalogu stron
  MOV AX, SELEKTOR_KATALOGU_STRON                        		
  MOV ES, AX                                             		
  XOR DI, DI                                             				
  XOR EAX, EAX                                           				
  MOV EDX, 1E0000H 		;Adres zerowej tablicy stron       		 
  MOV AL, 00000011B   		;PS, 0, A, PCD, PWT, U/S, R/W, P 	 
  MOV AH, 0000B       		;AV, G                           			 
  OR EAX, EDX                                            		
  STOSD                                                  				
  MOV EAX, 1F0000H 		;Adres katalogu stron                		
  MOV CR3, EAX                                           		
  MOV EAX, CR0                                           		
  OR EAX, 80000000H                                      			
  MOV CR0, EAX          		;Ustawienie 32-bitu rejestru CR0 		
  JMP $+2               		;Zalecana czynnoœæ po w³¹czeniu stronicowania   
;Elementy stronicowania zadania 1:
  MOV AX, SELEKTOR_TABLICY_STRON_1                     			
  MOV ES, AX                                           			
  XOR DI, DI                                           				
;Ustawienie odpowiednich pól PTE
  XOR EAX, EAX                                         			
  MOV AL, 00000011B 		;0, D, A, PCD, PWT, U/S, R/W, P 		
  MOV AH, 0000B       		;AV, G                           			 
  MOV ECX, 2048/4     		;Liczba stron w 2 MB pamiêci		 
  XOR EDX, EDX                                           	
  CLD                                                    				   
;Tworzenie tablicy stron dla pierwszych 2MB:
  TWORZENIE_TABLICY_STRON_1:                             		
    AND EAX, 00000FFFH                                  		
    OR EAX, EDX                                        			
    CMP ECX, 256                                        		
    JNE DALEJ_1                                         		
    ADD EAX, 1000H    ;Nastêpuje tu przesuniecie adresu w PTE, które powinno wskazywaæ na 
		      ;adres 1MB wskazuje na 1MB+4KB (adres liniowy 1MB okreœla segment danych zadania)
    DALEJ_1:              							
    CMP ECX, 258          						
    JNE DALEJ_1_1         						
    SUB EAX, 1000H 	;Nie mo¿na pozwoliæ, ¿eby zadanie 1 mia³o dostêp do segmentu 
			;danych zadania 2 (odpowiednia ramka jest pomijana w przestrzeni adresowej)						      
    DALEJ_1_1:        							
    STOSD             							
    ADD EDX, 1000H    							
  LOOP TWORZENIE_TABLICY_STRON_1 					
;Utworzenie jednego wpisu PDE w katalogu stron:
  MOV AX, SELEKTOR_KATALOGU_STRON_1   				
  MOV ES, AX                          					
  XOR DI, DI                          					
  XOR EAX, EAX                        					
  MOV EDX, 10C000H 		;adres zerowej tablicy stron         		  
  MOV AL, 00000011B		;PS, 0, A, PCD, PWT, U/S, R/W, P  	   
  MOV AH, 0000B       		;AV, G                             			  
  OR EAX, EDX                                               		
  STOSD                                                     				
;elementy stronicowania zadania 2
  MOV AX, SELEKTOR_TABLICY_STRON_2 
  MOV ES, AX 
  XOR DI, DI                                                				
;Ustawiane s¹ odpowiednie pola PTE
  XOR EAX, EAX                                              		
  MOV AL, 00000011B		;0, D, A, PCD, PWT, U/S, R/W, P      	
  MOV AH, 0000B       		;AV, G                               			
  MOV ECX, 2048/4     		;Liczba stron w 2 MB pamiêci          		
  XOR EDX, EDX                                             
  CLD                                                       				
;Tworzenie tablicy stron dla pierwszych 2MB
  TWORZENIE_TABLICY_STRON_2:   
    AND EAX, 00000FFFH                                     		
    OR EAX, EDX                                            		
    CMP ECX, 256                                           		 
    JNE DALEJ_2                                            		 
    ADD EAX, 2000H     	;Nastêpuje tu przesuniecie adresu w PTE, które powinno wskazywaæ na 
			;adres 1MB wskazuje na 1MB+8KB (adres liniowy 1MB okreœla 
			;segment danych zadania). 
    DALEJ_2:                                                      	
    CMP ECX, 257	                                              	
    JNE DALEJ_2_2	                                                     
    SUB EAX, 1000H 	;Nie mo¿na pozwoliæ, ¿eby zadanie 2 mia³o dostêp do segmentu danych 
;zadania 1 (odpowiednia strona jest pomijana w przestrzeni adresowej). 
    DALEJ_2_2:        							
    STOSD             							
    ADD EDX, 1000H    							
  LOOP TWORZENIE_TABLICY_STRON_2  					
;Tworzenie jednego wpisu PDE w katalogu stron
  MOV AX, SELEKTOR_KATALOGU_STRON_2  				
  MOV ES, AX                         						
  XOR DI, DI                         						
  XOR EAX, EAX                       						
  MOV EDX, 10A000H 		;Adres zerowej tablicy stron 			  
  MOV AL, 00000011B 		;PS, 0, A, PCD, PWT, U/S, R/W, P	  
  MOV AH, 0000B       		;AV, G                         			  
  OR EAX, EDX                                            		
  STOSD                                                  		
  RET  
PRZYGOTOWANIE_STRONICOWANIA ENDP

;Procedura wykonywana w zadaniu nr 1:
ZADANIE_1	PROC             						
  MOV BX,0                 						
  MOV CX, 114              						
  MOV AL,[BX]              						
  MOV SI,0                 						 
  PETLA2:                          						
    MOV ES:[SI+1280],AL      					
    MOV AL,0001010B          					
    MOV ES:[SI+1281],AL     					 
    ADD BX,1                 						
    ADD SI,2                 						
    MOV AL,[BX]              						
  LOOP PETLA2              						
  MOV AX, 8
  MOV DS, AX						
  JMP DWORD PTR TASK0_OFFS
ZADANIE_1	ENDP            						

ZADANIE_2	PROC            						
  MOV BX,0                						
  MOV CX, 114             						
  MOV AL,[BX]             						
  MOV SI,0                						
  PETLA2_:                        						
    MOV ES:[SI+2560],AL     					
    MOV AL,10000101B        					
    MOV ES:[SI+2561],AL     					
    ADD BX,1                						
    ADD SI,2                						
    MOV AL,[BX]             						
  LOOP PETLA2_            						
  MOV AX, 8
  MOV DS, AX
  JMP DWORD PTR TASK0_OFFS
ZADANIE_2	ENDP

INCLUDE PROC.TXT

PROGRAM_SIZE=$-BEGIN
PROGRAM	ENDS

STK	SEGMENT STACK 'STACK'
  DB 256 DUP (0)
STK	ENDS
END	MAIN

