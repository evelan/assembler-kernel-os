.386P
SELEKTOR_TABLICY_STRON EQU  40	;Deklaracja sta³ej przechowuj¹cej selektor do obszaru               		                                       		;pamiêci gdzie znajdzie siê tablica stron.
SELEKTOR_KATALOGU_STRON EQU 48 ;Deklaracja sta³ej przechowuj¹cej selektor do obszaru
                               				;pamiêci gdzie znajdzie siê katalog stron.       

selektor_tablicy_wskaznikow_katalogow_stron equ 64
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
  INCLUDE GDT.TXT
  GDT_TABLICA_STRON 	DESKR <0FFFFH,00000H, 12H, 92H, 0, 0> 		;40
  GDT_KATALOG_STRON 	DESKR <16383,00000H, 11H, 92H, 0, 0>      	;48
  GDT_DESKRYPTOR_ZMIENNEGO_ADRESU DESKR <0FFFFH,0H,11H,92H,0,0>	;56
  GDT_TABLICA_WSKAZNIKOW_KATALOGOW_STRON DESKR <31,0F000H,11H,92H,0,0> 	;64
  GDT_SIZE = $ - GDT_NULL
  PDESKR	 	DQ 0
  ORG_IDT      DQ 0
  TEKST	 	DB 'PRACA W TRYBIE CHRONIONYM !!!',0
  TEKST2 	DB 'STRONICOWANIE DZIALA PRAWIDLOWO, OBSLUGUJE CALA PAMIEC O WARTOSCI HEX:', 0
  INFO		DB 'POWROT Z TRYBU CHRONIONEGO $'
  ILOSC_PAMIECI DD 0
  A20     	DB 0
  FAST_A20 	DB 0
  ELEMENT_STRONICOWANIA PDTE <11B, 0, 0, 0, 0, 0>
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
  MOV AX,20H			;Za³adowanie selektora	       
  MOV ES,AX			;segmentu pamiêci obrazu. 
  CALL PM_WYMAZ_EKRAN                        			 
  MOV BX,OFFSET TEKST		;Wyprowadzenie na ekran tekstu.  
  MOV DI, 840                                				
  CALL  WYPISZ_TEKST                         				 
  CALL WYKRYCIE_ILOSCI_PAMIECI               				
  CALL PRZYGOTOWANIE_STRONICOWANIA           				
  MOV BX,OFFSET TEKST2		;Wyprowadzenie na ekran tekstu.  
  MOV DI, 800+ 80*2                          				
  CALL  WYPISZ_TEKST  
  MIEKI_POWROT_RM   
;MOV EAX, CR4
  DB 0FH                                                      	
  DB 20H                                                      	
  DB 0E0H                                                     	
  AND AL, 11011111B                                              	
;MOV CR4, EAX
  DB 0FH                                                       	
  DB 22H                                                       	
  DB 0E0H                                                      	             
  POWROT_DO_RM 1,0

INCLUDE PROC.TXT
INCLUDE PAGING.TXT


PRZYGOTOWANIE_STRONICOWANIA PROC
  MOV AX, SELEKTOR_TABLICY_STRON                  			
  MOV ES, AX                                      			
  CLD                                             			
  MOV EAX, ILOSC_PAMIECI                          			
  XOR EDX, EDX                                    			
  MOV ECX, 4096                                   			
  DIV ECX                                         			
  MOV ECX, EAX 			;ECX zawiera iloœæ PTE, które nale¿y dodaæ. 	
  PUSH CX                                                  		
  ROL ECX, 16                                              		
  PUSH CX                                                  		
  ROL ECX, 16                                              		
  XOR DI, DI                                               		
;Tworzenie tablic stron:
  MOV SI, OFFSET ELEMENT_STRONICOWANIA                     		
  XOR EDX, EDX                                             		
  TWORZENIE_TABLICY_STRON:                                 		
    PUSH SI                                               		
    PUSH DI                                               		
    MOVSD                                               		
    MOVSD                                               		
    POP DI                                                	
    POP SI                                                		
    CMP DI, 0FFF8H                                        		
    JB NIE_PRZEKROCZONA_WARTOSC_REJESTRU_INDEKSOWEGO   
    MOV BX, OFFSET GDT_TABLICA_STRON                   			
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
    MOV AX, ES
    MOV ES, AX                                      			
    XOR DI, DI                                         			
    JMP  NASTEPNY_PRZEBIEG                             		
    NIE_PRZEKROCZONA_WARTOSC_REJESTRU_INDEKSOWEGO:
    ADD DI, 8                                             		
    NASTEPNY_PRZEBIEG:                                    		
    ADD EDX, 1H                                           		
    PUSHA                                                 		
    MOV AL, DL                                         			
    SHL AL, 4 ; 4 OSTATNIE BITY ADRESU                 			
    MOV [SI].CZTERY_OSTATNIE_BITY_ADRESU, AL           			
    ROR EDX, 4                                         		
    MOV [SI].SLOWO_ADRESU, DX                          			
    ROR EDX, 16                                        			
    PUSH DX                                            		
    AND DL, 00001111B                                 		
    MOV [SI].CZTERY_PIERWSZE_BITY_ADRESU, DL           		
    POP DX                                             		
    ROR EDX, 12                                        		
    POPA
  DEC ECX                                                  		
  JNZ TWORZENIE_TABLICY_STRON                             		
  POP AX                                                   		
  SHL EAX, 16                                              		
  POP AX        		;EAX zawiera iloœæ dodanych PTE	
; nale¿y teraz obliczyæ iloœæ PDE, które trzeba dodaæ.
  XOR EDX, EDX                                           		
  MOV EBX, 512                                           		
  DIV EBX			;EAX zawiera iloœæ pe³nych tablic stron, nale¿y jeszcze zbadaæ resztê z
; dzielenia.                                      
  CMP EDX, 0                                               		
  JE NIE_MA_RESZTY                                         		
  INC EAX                                               		
  NIE_MA_RESZTY:                                           		
  MOV ECX, EAX 			;Liczba PDE przek³adana do rejestru ECX (licznika pêtli) 
  MOV AX, SELEKTOR_KATALOGU_STRON                  			
  MOV ES, AX                                       			
  XOR DI, DI                                       			
  XOR EAX, EAX                                     			
  MOV EDX, 120H 		;Adres zerowej tablicy stron     			
  MOV SI, OFFSET ELEMENT_STRONICOWANIA             			
  MOV [SI].ATRYBUTY, 11B                           			
  MOV [SI].CZTERY_OSTATNIE_BITY_ADRESU, 0          			
  MOV [SI].SLOWO_ADRESU, 12H                       			
  MOV [SI].CZTERY_PIERWSZE_BITY_ADRESU, 0          			
  TWORZENIE_KATALOGU_STRON:                        			
    PUSH SI                                      				
    MOVSD                                       				
    MOVSD                                       				
    POP SI                                        			
    ADD EDX, 1H 		;Nastêpna tablica stron.          			
    PUSHA                                         			
    MOV AL, DL                                 				
    SHL AL, 4 			; 4 ostatnie bity adresu         		
    MOV [SI].CZTERY_OSTATNIE_BITY_ADRESU, AL   				
    ROR EDX, 4                                				
    MOV [SI].SLOWO_ADRESU, DX                  				
    ROR EDX, 16                                				
    MOV [SI].CZTERY_PIERWSZE_BITY_ADRESU, DL   				
    ROR EDX, 12                                				
    POPA                                          			
  LOOP   TWORZENIE_KATALOGU_STRON                  			
  MOV AX, SELEKTOR_TABLICY_WSKAZNIKOW_KATALOGOW_STRON   		
  MOV ES, AX                                            		
  XOR DI, DI                                            		
  MOV SI, OFFSET ELEMENT_STRONICOWANIA                  		
  MOV [SI].ATRYBUTY, 1B                                 		
  MOV [SI].CZTERY_OSTATNIE_BITY_ADRESU, 0               		
  MOV [SI].SLOWO_ADRESU, 11H                            		
  MOV [SI].CZTERY_PIERWSZE_BITY_ADRESU, 0               		
  MOV EDX, 110H                                         		
  MOV ECX, 4                                            		
  TWORZENIE_TABLICY_WSKAZNIKOW_KATALOGOW_STRON:         	
    PUSH SI                                            			
    MOVSD                                            			
    MOVSD                                            			
    POP SI                                             			
    ADD EDX, 1H ; NASTEPNY KATALOG                     			
    PUSHA                                              			
    MOV AL, DL                                      			
    SHL AL, 4 ; 4 OSTATNIE BITY ADRESU              			
    MOV [SI].CZTERY_OSTATNIE_BITY_ADRESU, AL        			
    ROR EDX, 4                                      			
    MOV [SI].SLOWO_ADRESU, DX                       			
    ROR EDX, 16                                     			
    MOV [SI].CZTERY_PIERWSZE_BITY_ADRESU, DL        			
    ROR EDX, 12                                     			
    POPA                                               			
  LOOP   TWORZENIE_TABLICY_WSKAZNIKOW_KATALOGOW_STRON	
  MOV EAX, 11F000H		 ; Adres tablicy wskaŸników katalogów stron.
  MOV CR3, EAX                                                	
;MOV EAX, CR4
  DB 0FH                                                      	
  DB 20H                                                      	
  DB 0E0H                                                     	
  OR AL, 100000B                                              	
;MOV CR4, EAX
  DB 0FH                                                       	
  DB 22H                                                       	
  DB 0E0H                                                      	
  MOV EAX, CR0                                                	
  OR EAX, 80000000H                                           	
  MOV CR0, EAX        		;Ustawienie 32-bitu rejestru cr0.     
  JMP $+2               		
  MOV EAX, CR3                                                         
  MOV CR3, EAX                                                         
  RET                                                                     
PRZYGOTOWANIE_STRONICOWANIA ENDP
            			

PROGRAM_SIZE = $ - START			
PROGRAM ENDS					 
STK     SEGMENT STACK 'STACK'
DB 256 DUP (?)
STK     ENDS
END START

