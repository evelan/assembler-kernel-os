.386P
SELEKTOR_TABLICY_STRON EQU 40 	;Deklaracja sta�ej przechowuj�cej selektor do obszaru
                          	;pami�ci gdzie znajdzie si� tablica stron.
SELEKTOR_KATALOGU_STRON EQU 48 	;Deklaracja sta�ej przechowuj�cej selektor do obszaru
                           	;pami�ci gdzie znajdzie si� katalog stron.       
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
  INCLUDE GDT.TXT
;Poni�sze dwa segmenty wskazuj� na obszar pami�ci przeznaczony dla tablicy i katalogu stron:
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
  CALL PM_WYMAZ_EKRAN          	;Wywo�anie procedury czyszcz�cej ekran.	
;Czynno�ci zwi�zane z poinformowaniem u�ytkownika o tym, �e tryb chroniony zosta� uaktywniony:
  MOV BX,OFFSET TEKST         	;Za�adowanie offsetu napisu do wydrukowania na ekranie.
  MOV DI, 840                   ;Ustalenie przesuni�cia wzgl�dem pocz�tku pami�ci  
;ekranu, od kt�rego b�dzie drukowany tekst.      		
  CALL  WYPISZ_TEKST            ;Procedura drukuj�ca tekst o offsecie zawartym w BX. 	
  CALL PRZYGOTOWANIE_STRONICOWANIA   ;wywo�anie procedury inicjuj�cej stronicowanie  
;Czynno�ci zwi�zane z wy�wietleniem informacji o tym, �e stronicowanie zosta�o aktywowane:
  MOV BX,OFFSET TEKST2    								
  MOV DI, 840+ 80*2      								
  CALL  WYPISZ_TEKST      
  MIEKI_POWROT_RM
  POWROT_DO_RM 1,0

PRZYGOTOWANIE_STRONICOWANIA PROC		;Procedura inicjuj�ca stronicowanie. 
  MOV AX, SELEKTOR_TABLICY_STRON 		;Za�adowanie rejestru segmentowego ES 	 
  MOV ES, AX                    		;selektorem obszaru pami�ci, gdzie zostanie umieszczona tablica stron   
  XOR DI, DI                            	;Wyzerowanie rejestru indeksowego DI.       
;Poni�ej ustawiane s� odpowiednie pola PTE:
  XOR EAX, EAX                                				 	
  MOV AL, 00000011B   		;0, D, A, PCD, PWT, U/S, R/W, P     				
  MOV AH, 0000B       		;AVL, G                                                
  MOV ECX, 1024/4     		;Liczba stron w 1 MB pami�ci.     	 		  	
  XOR EDX, EDX            	;EBX b�dzie przechowywa� kolejne adresy ramek.	 	
  CLD                           ;Wyczyszczenie flagi kierunku.         	 		 	
;Tworzenie tablicy stron dla pierwszego MB pami�ci (sama tablica stron znajduje si� poza tym obszarem):
  TWORZENIE_TABLICY_STRON:		
    AND EAX, 00000FFFH;Zerowany adres strony, atrybuty zostawiane. 	
    OR EAX, EDX            	;Stworzenie PTE- adres ramki przechowywany 
;jest w EDX natomiast atrybuty w EAX. 		 
    STOSD 			;Od�o�enie PTE z EAX pod adres ES:DI. 		 
    ADD EDX, 1000H         	;Obliczenie adresu nast�pnej ramki pami�ci. 	 
  LOOP TWORZENIE_TABLICY_STRON  ;Nast�pny przebieg p�tli. 			 
;Utworzenie jednego wpisu PDE do katalogu stron:
  MOV AX, SELEKTOR_KATALOGU_STRON ;Za�adowanie rejestru segmentowego ES 
  MOV ES, AX                    ;selektorem obszaru pami�ci, w kt�rym b�dzie si� znajdowa� katalog stron.
  XOR DI, DI                    ;Wyzerowanie rejestru indeksowego DI.	 
  XOR EAX, EAX         				        				
  MOV EDX, 20E000H    		 ;Adres wcze�niej przygotowanej tablicy storn. 	
;Ustalenie atrybut�w PDE:
  MOV AL, 00000011B   		;PS, 0, A, PCD, PWT, U/S, R/W, P       		   
  MOV AH, 0000B       		;AV, G                                  				   
  OR EAX, EDX      		;Utworzenie PDE- w EDX znajdowa� si� adres tablicy stron
                    	   	;EAX natomiast zawiera atrybuty PDE.      
  STOSD               		;Od�o�enie PDE zawartego w eax pod adres ES:DI
  MOV EAX, 20F000H		;Adres katalogu stron.    	  
  MOV CR3, EAX     									  
  MOV EAX, CR0    								              
  OR EAX, 80000000H   
  MOV CR0, EAX       		;Ustawienie 32-bitu rejestru CR0.    
  JMP $+2           		;zalecana czynno�� po uruchomieniu stronicowania	    	
  RET                           ;Powr�t z procedury.
PRZYGOTOWANIE_STRONICOWANIA ENDP

INCLUDE PROC.TXT
 									
 PROGRAM_SIZE = $ - START			
 PROGRAM ENDS					
 STK     SEGMENT STACK 'STACK' 
 	DB 256 DUP (?)
 STK     ENDS
END START

