.386P
SELEKTOR_TABLICY_STRON EQU 40 	;Deklaracja sta³ej przechowuj¹cej selektor do obszaru
                          	;pamiêci gdzie znajdzie siê tablica stron.
SELEKTOR_KATALOGU_STRON EQU 48 	;Deklaracja sta³ej przechowuj¹cej selektor do obszaru
                           	;pamiêci gdzie znajdzie siê katalog stron.       
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
  INCLUDE GDT.TXT
;Poni¿sze dwa segmenty wskazuj¹ na obszar pamiêci przeznaczony dla tablicy i katalogu stron:
  GDT_TABLICA_STRON DESKR <4095,0E000H, 20H, 92H, 0, 0>;40
  GDT_KATALOG_STRON DESKR <4095,0F000H, 20H, 92H, 0, 0>;48
  GDT_SIZE = $ - GDT_NULL

  PDESKR	DQ 0
  TEKST		DB 'PRACA W TRYBIE CHRONIONYM !!!',0
  TEKST2  	DB 'STRONICOWANIE DZIALA PRAWIDLOWO !!!', 0
  INFO		DB 'POWROT Z TRYBU CHRONIONEGO $'
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
  CALL PM_WYMAZ_EKRAN          	;Wywo³anie procedury czyszcz¹cej ekran.	
;Czynnoœci zwi¹zane z poinformowaniem u¿ytkownika o tym, ¿e tryb chroniony zosta³ uaktywniony:
  MOV BX,OFFSET TEKST         	;Za³adowanie offsetu napisu do wydrukowania na ekranie.
  MOV DI, 840                   ;Ustalenie przesuniêcia wzglêdem pocz¹tku pamiêci  
;ekranu, od którego bêdzie drukowany tekst.      		
  CALL  WYPISZ_TEKST            ;Procedura drukuj¹ca tekst o offsecie zawartym w BX. 	
  CALL PRZYGOTOWANIE_STRONICOWANIA   ;wywo³anie procedury inicjuj¹cej stronicowanie  
;Czynnoœci zwi¹zane z wyœwietleniem informacji o tym, ¿e stronicowanie zosta³o aktywowane:
  MOV BX,OFFSET TEKST2    								
  MOV DI, 840+ 80*2      								
  CALL  WYPISZ_TEKST      
  MIEKI_POWROT_RM
  POWROT_DO_RM 1,0

PRZYGOTOWANIE_STRONICOWANIA PROC		;Procedura inicjuj¹ca stronicowanie. 
  MOV AX, SELEKTOR_TABLICY_STRON 		;Za³adowanie rejestru segmentowego ES 	 
  MOV ES, AX                    		;selektorem obszaru pamiêci, gdzie zostanie umieszczona tablica stron   
  XOR DI, DI                            	;Wyzerowanie rejestru indeksowego DI.       
;Poni¿ej ustawiane s¹ odpowiednie pola PTE:
  XOR EAX, EAX                                				 	
  MOV AL, 00000011B   		;0, D, A, PCD, PWT, U/S, R/W, P     				
  MOV AH, 0000B       		;AVL, G                                                
  MOV ECX, 1024/4     		;Liczba stron w 1 MB pamiêci.     	 		  	
  XOR EDX, EDX            	;EBX bêdzie przechowywa³ kolejne adresy ramek.	 	
  CLD                           ;Wyczyszczenie flagi kierunku.         	 		 	
;Tworzenie tablicy stron dla pierwszego MB pamiêci (sama tablica stron znajduje siê poza tym obszarem):
  TWORZENIE_TABLICY_STRON:		
    AND EAX, 00000FFFH;Zerowany adres strony, atrybuty zostawiane. 	
    OR EAX, EDX            	;Stworzenie PTE- adres ramki przechowywany 
;jest w EDX natomiast atrybuty w EAX. 		 
    STOSD 			;Od³o¿enie PTE z EAX pod adres ES:DI. 		 
    ADD EDX, 1000H         	;Obliczenie adresu nastêpnej ramki pamiêci. 	 
  LOOP TWORZENIE_TABLICY_STRON  ;Nastêpny przebieg pêtli. 			 
;Utworzenie jednego wpisu PDE do katalogu stron:
  MOV AX, SELEKTOR_KATALOGU_STRON ;Za³adowanie rejestru segmentowego ES 
  MOV ES, AX                    ;selektorem obszaru pamiêci, w którym bêdzie siê znajdowa³ katalog stron.
  XOR DI, DI                    ;Wyzerowanie rejestru indeksowego DI.	 
  XOR EAX, EAX         				        				
  MOV EDX, 20E000H    		 ;Adres wczeœniej przygotowanej tablicy storn. 	
;Ustalenie atrybutów PDE:
  MOV AL, 00000011B   		;PS, 0, A, PCD, PWT, U/S, R/W, P       		   
  MOV AH, 0000B       		;AV, G                                  				   
  OR EAX, EDX      		;Utworzenie PDE- w EDX znajdowa³ siê adres tablicy stron
                    	   	;EAX natomiast zawiera atrybuty PDE.      
  STOSD               		;Od³o¿enie PDE zawartego w eax pod adres ES:DI
  MOV EAX, 20F000H		;Adres katalogu stron.    	  
  MOV CR3, EAX     									  
  MOV EAX, CR0    								              
  OR EAX, 80000000H   
  MOV CR0, EAX       		;Ustawienie 32-bitu rejestru CR0.    
  JMP $+2           		;zalecana czynnoœæ po uruchomieniu stronicowania	    	
  RET                           ;Powrót z procedury.
PRZYGOTOWANIE_STRONICOWANIA ENDP

INCLUDE PROC.TXT
 									
 PROGRAM_SIZE = $ - START			
 PROGRAM ENDS					
 STK     SEGMENT STACK 'STACK' 
 	DB 256 DUP (?)
 STK     ENDS
END START

