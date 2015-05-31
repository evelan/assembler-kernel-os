.386P
SELEKTOR_TABLICY_STRON EQU  40	;Deklaracja sta³ej przechowuj¹cej selektor do obszaru   
				;pamiêci gdzie znajdzie siê tablica stron.
SELEKTOR_KATALOGU_STRON EQU 48 	;Deklaracja sta³ej przechowuj¹cej selektor do obszaru
                               	;pamiêci gdzie znajdzie siê katalog stron.       
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
  INCLUDE GDT.TXT
  GDT_TABLICA_STRON 	DESKR <0FFFFH,0000H, 12H, 92H, 0, 0> 		;40
  GDT_KATALOG_STRON 	DESKR <4095,00000H, 11H, 92H, 0, 0>      	;48
  GDT_DESKRYPTOR_ZMIENNEGO_ADRESU DESKR <0FFFFH,0H,11H,92H,0,0>		;56
  GDT_SIZE = $ - GDT_NULL
  PDESKR	 		DQ 0
  ORG_IDT     		DQ 0
  TEKST	 		DB 'PRACA W TRYBIE CHRONIONYM !!!',0
  TEKST2 		DB 'STRONICOWANIE DZIALA PRAWIDLOWO, OBSLUGUJE CALA PAMIEC O ROZMIARZE HEX:', 0
  INFO			DB 'POWROT Z TRYBU CHRONIONEGO $'
  ILOSC_PAMIECI 	DD 0
  A20     		DB 0
  FAST_A20 		DB 0
  DANE_SIZE = $ - GDT_NULL
DANE	ENDS

PROGRAM	SEGMENT USE16
ASSUME CS:PROGRAM,DS:DANE

INCLUDE MAKRA.TXT

START:
  CZY_DOSTEPNY_FAST_A20
  CLI
  INICJOWANIE_DESKRYPTOROW	
  A20_ON
  AKTYWACJA_PM		
  MOV AX,20H		;Za³adowanie selektora	       
  MOV ES,AX		;segmentu pamiêci obrazu. 
  CALL PM_WYMAZ_EKRAN                        			 
  MOV BX,OFFSET TEKST	;Wyprowadzenie na ekran tekstu.  
  MOV DI, 840                                				
  CALL  WYPISZ_TEKST                         				 
  CALL WYKRYCIE_ILOSCI_PAMIECI               				
  CALL PRZYGOTOWANIE_STRONICOWANIA           				
  MOV BX,OFFSET TEKST2	;Wyprowadzenie na ekran tekstu.  
  MOV DI, 800+ 80*2                          				
  CALL  WYPISZ_TEKST  
  MIEKI_POWROT_RM                       				
  POWROT_DO_RM 1,0

INCLUDE PROC.TXT
INCLUDE PAGING.TXT


PRZYGOTOWANIE_STRONICOWANIA PROC                      	
  MOV AX, SELEKTOR_TABLICY_STRON                     			
  MOV ES, AX                                         			
  MOV EAX, ILOSC_PAMIECI                             			
  XOR EDX, EDX                                       			
  MOV ECX, 4096                                      			
  DIV ECX                                            			
  MOV ECX, EAX 		;ECX zawiera liczbê PTE, które nale¿y dodaæ	 
  PUSH ECX                                           			
  XOR DI, DI                                         			
;Ustawienie odpowiednich pól PTE
  XOR EAX, EAX                                       			
  MOV AL, 00000011B   	; 0, D, A, PCD, PWT, U/S, R/W, P   	 
  MOV AH, 0000B       	; AV, G                     
  XOR EDX, EDX                                       			
;Tworzenie tablicy stron
  TWORZENIE_TABLICY_STRON:     					
    AND EAX, 00000FFFH        						
    OR EAX, EDX               						
    MOV [ES:DI], EAX          						
    CMP DI, 0FFFCH            						
    JB NIE_PRZEKROCZONA_WARTOSC_REJESTRU_INDEKSOWEGO   
    MOV BX, OFFSET GDT_TABLICA_STRON                			
    PUSH EAX                                        			
    MOV AH, [BX].BASE_H                          				
    SHL EAX, 8                                   				
    MOV AH, [BX].BASE_M                          				
    SHL EAX, 8                                   				
    MOV AX, [BX].BASE_1                          				
    ADD EAX, 10000H                              				
    ROL EAX, 8                                   				
    MOV  [BX].BASE_H, AL                         				
    ROL EAX, 8                                   				
    MOV [BX].BASE_M, AL                          				
    ROL EAX, 16                                  				
    MOV [BX].BASE_1, AX                          				
    MOV AX, ES    		;Prze³adowanie rejestru segmentowego
    MOV ES, AX                                   				
    POP EAX                                         			
    XOR DI, DI                                      			
    JMP  NASTEPNY_PRZEBIEG                          			
    NIE_PRZEKROCZONA_WARTOSC_REJESTRU_INDEKSOWEGO:     	
    ADD DI, 4                                          			 
    NASTEPNY_PRZEBIEG:                                			
    ADD EDX, 1000H 
  DEC ECX                                   			
  JNZ TWORZENIE_TABLICY_STRON                         			
  POP EAX 		;EAX zawiera liczbê dodanych PTE            	
;Nale¿y teraz obliczyæ liczbê PDE, które trzeba dodaæ
  XOR EDX, EDX                                    			
  MOV EBX, 1024                                    			
  DIV EBX 		;EAX zawiera iloœæ pe³nych tablic stron, nale¿y jeszcze zbadaæ resztê z dzielenia. 
  CMP EDX, 0             								
  JE NIE_MA_RESZTY       								
  INC EAX             								
  NIE_MA_RESZTY:         								
  MOV ECX, EAX 		; liczba PDE kopiowana do rejestru ECX (licznika pêtli) 
  MOV AX, SELEKTOR_KATALOGU_STRON         					
  MOV ES, AX                              					
  XOR DI, DI                              					
  XOR EAX, EAX                            					
  MOV EDX, 120000H 	;Adres zerowej tablicy stron  			
  MOV AL, 00000011B   	; PS, 0, A, PCD, PWT, U/S, R/W, P 		 
  MOV AH, 0000B       	; AV, G    						
  TWORZENIE_KATALOGU_STRON:       					
    AND EAX, 0FFFH                  						
    OR EAX, EDX                     						
    STOSD                           						
    ADD EDX, 1000H 		;Nastêpna tablica stron  				 
  LOOP   TWORZENIE_KATALOGU_STRON   					
  MOV EAX, 110000H 		;Adres katalogu stron  			
  MOV CR3, EAX                              				
  MOV EAX, CR0                              				
  OR EAX, 80000000H                         				
  MOV CR0, EAX          	;Ustawienie 32-bitu rejestru CR0. 		
  JMP $+2               
  RET                                             			
PRZYGOTOWANIE_STRONICOWANIA ENDP    
            			

PROGRAM_SIZE = $ - START			
PROGRAM ENDS					 
STK     SEGMENT STACK 'STACK'
DB 256 DUP (?)
STK     ENDS
END START

