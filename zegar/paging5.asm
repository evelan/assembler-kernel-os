.386P
SELEKTOR_TABLICY_STRON EQU  40	 ;Deklaracja sta³ej przechowuj¹cej selektor do obszaru
                                ;pamiêci gdzie znajdzie siê tablica stron.
SELEKTOR_KATALOGU_STRON EQU 48   ;Deklaracja sta³ej przechowuj¹cej selektor do obszaru
                               	;pamiêci gdzie znajdzie siê katalog stron.
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
  INCLUDE GDT.TXT
  GDT_TABLICA_STRON 	DESKR <0FFFFH,00000H, 12H, 92H, 0, 0>       ;40
  GDT_KATALOG_STRON 	DESKR <4095,00000H, 11H, 92H, 0, 0>         ;48
  GDT_DESKRYPTOR_ZMIENNEGO_ADRESU DESKR <0FFFFH,0H,11H,92H,0,0>	    ;56
  GDT_SIZE = $ - GDT_NULL
  PDESKR	 	DQ 0
  ORG_IDT      DQ 0
  TEKST	 	DB 'PRACA W TRYBIE CHRONIONYM !!!',0
  TEKST2 	DB 'STRONICOWANIE DZIALA PRAWIDLOWO, OBSLUGUJE CALA PAMIEC O WARTOSCI HEX:', 0
  INFO		DB 'POWROT Z TRYBU CHRONIONEGO $'
  ILOSC_PAMIECI DD 0
  A20     	DB 0
  FAST_A20 	DB 0
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
  MOV BX,OFFSET TEKST	        ;Wyprowadzenie na ekran tekstu.
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
  AND AL, 11101111B                                             	
;MOV CR4, EAX
  DB 0FH                                                    		
  DB 22H                                                     		
  DB 0E0H                                                    	           
  POWROT_DO_RM 1,0

INCLUDE PROC.TXT
INCLUDE PAGING.TXT

PRZYGOTOWANIE_STRONICOWANIA PROC                 	
  MOV EAX, ILOSC_PAMIECI                        				
  XOR EDX, EDX                                  				
  MOV ECX, 4096* 1024                           				
  DIV ECX                                       				
  MOV ECX, EAX 		;ECX zawiera iloœæ elementów katalogu stron.	 
  MOV AX, SELEKTOR_KATALOGU_STRON            				
  MOV ES, AX                                 				
  XOR DI, DI                                 				
  XOR EAX, EAX                              				
  XOR EDX, EDX                               				
  MOV AL, 10000011B   		; PS, D, A, PCD, PWT, U/S, R/W, P     	
  MOV AH, 0000B       		; AV,G                               
  TWORZENIE_KATALOGU_STRON:                                 	
    AND EAX, 0FFFH                                            	
    OR EAX, EDX                                               	
    STOSD                                                     	
    ADD EDX, 4096*1024 		;(strony po 4 MB) 	
  LOOP   TWORZENIE_KATALOGU_STRON                           	
  MOV EAX, 110000H 			; Adres katalogu stron                   	
  MOV CR3, EAX                                              	
;MOV EAX, CR4
  DB 0FH                                                    		
  DB 20H                                                    		
  DB 0E0H                                                   		
  OR AL, 10000B                                             		
;MOV CR4, EAX
  DB 0FH                                                    		
  DB 22H                                                     		
  DB 0E0H                                                    		
  MOV EAX, CR0                                              		
  OR EAX, 80000000H                                         		
  MOV CR0, EAX          		;Ustawienie 32-bitu rejestru cr0.   		
  JMP $+2               
  RET                      							
PRZYGOTOWANIE_STRONICOWANIA ENDP 
            			

PROGRAM_SIZE = $ - START			
PROGRAM ENDS					 
STK     SEGMENT STACK 'STACK'
DB 256 DUP (?)
STK     ENDS
END START

