.386P
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
;Globalna tablica deskryptor�w  (w komentarzach znajduj� si� selektory segment�w)
INCLUDE GDT.TXT
GDT_INT       	DESKR <INT_SIZE-1,,,10011010B,01000000B>  ;40
GDT_TSS_0	DESKR <103,0,0,89H>			;Selektor 48, deskryptor TSS_0
GDT_TSS_2     	DESKR <137,0,0,0E9H>   			;Selektor 56, dekskryptor TSS_2
GDT_INT_STACK 	DESKR <255,0,0,92H,01000000B,0>		;Selektor 64
GDT_SIZE=$-GDT_NULL					;Rozmiar GDT

;Tablica deskryptor�w przerwa�
IDT		LABEL WORD	;Pocz�tek IDT.
  TRAP 	13 	DUP(<EXC_,40>)
  TRAP       	<EXC_13,40>    ;#GP
  TRAP  	18    DUP(<EXC_,40>)
; ...
IDT_SIZE=$-IDT			;Rozmiar tablicy IDT.

PDESKR		DQ 0		;Pseudodeskryptor
ORG_IDT       	DQ 0
INFO		DB 'POWROT Z TRYBU CHRONIONEGO $'
INFO1		DB 'PRZELACZENIE W TRYB PROTECTED $'
;Dwie poni�sze zmienne pos�u�� do zachowania oryginalnego adresu segmentu i przesuni�cia
;elementu wektora przerwa� 1ch:
SEGMENT_PRZERWANIA_1CH DW 0
OFFSET_PRZERWANIA_1CH  DW 0


TSS_0		DB 104	DUP(0) ;Segment stanu zadania 0 (proc. main)
TSS_2         	DB 137  DUP(0) ;Segment stanu zadania 2 (104 bajty +34bajty na map� IR)
TASK0_OFFS	DW 0		;4-bajtowy adres dla prze��czenia
TASK0_SEL	DW 48		;na zadanie 0 przez TSS
TASK2_OFFS	DW 0		;4-bajtowy adres dla prze��czenia
TASK2_SEL	DW 59		;na zadanie 1 przez TSS_1
DANE_SIZE=$-GDT_NULL		;Rozmiar segmentu danych
DANE	ENDS

PROGRAM	SEGMENT  'CODE' USE16
	ASSUME CS:PROGRAM,DS:DANE
BEGIN	LABEL WORD

INCLUDE MAKRA.TXT

MAIN	PROC
  INICJOWANIE_DESKRYPTOROW
  MOV AX,SEG DANE           					
  SHL EAX,4					
  MOV EBP,EAX	
  INICJACJA_TSS0
;      VIF VM     IOPL  IF  
  INICJACJA_TSS2 00000000000010100011001000000000B
;Zgodnie z budow� TSS pod offsetem 100 wzgl�dem jego pocz�tku znajduje si� podw�jne s�owo,
;kt�rego starsze 2 bajty wskazuj� na pocz�tek mapy zezwole� I/O oraz na koniec 32-bajtowej
;binarnej mapy przekierowa� przerwa�. Poni�ej nast�puje za�adowanie tego pola (starszych
;16 bit�w) warto�ci� 136, co wskazuje na to, �e binarna mapa IR b�dzie
;znajdowa�a si� na pozycji 136-32= 104 wzgl�dem pocz�tku TSS:
  MOV EAX, 136                   
  SHL EAX, 16                    
  MOV DWORD PTR TSS_2+100, EAX   
  MOV BYTE PTR TSS_2+136, 0FFH   
;Wype�nienie pierwszych 4 bajt�w binarnej mapy przekierowa� przerwa� warto�ci�, kt�rej
;binarna reprezentacja ma wy��cznie wyzerowany bit na pozycji 1ch (oznacza to, �e przerwanie
;programowe 1ch b�dzie obs�ugiwane w trybie wirtualnym z wykorzystaniem tablicy wektor�w
;przerwa�)
  MOV EAX, 11101111111111111111111111111111B    
  MOV DWORD PTR TSS_2+104, EAX                  
;Wyprowadzenie na ekran tekstu info1
  MOV AH,9  								
  MOV DX,OFFSET INFO1 							
  INT 21H       								
  CLI  
  INICJACJA_DESKR_PRZERWAN               					 
;Zachowanie s�owa okre�laj�cego segment i offset oryginalnej procedury obs�ugi przerwania programowego 1ch:
  MOV AX, 0        
  MOV ES, AX       
  MOV AX, ES:70H   		;4*1ch= 70h- pod t� pozycj� znajduje si� offset. 
  MOV OFFSET_PRZERWANIA_1CH, AX	;Zachowanie offsetu.                
  MOV AX, OFFSET PRZERWANIE_1CH	;Przesuni�cie procedury.     
  MOV ES:70H, AX               	;Zmiana przesuni�cia w tablicy wektor�w przerwa�. 
  MOV AX, ES:72H               	;Pobranie adresu segmentu.              
  MOV SEGMENT_PRZERWANIA_1CH, AX ;Zachowanie oryginalnego adresu segmentu procedury. 
  MOV AX, KOD_REAL            	;Segment, w kt�rym znajduje si� nasza procedura.      
  MOV ES:72H, AX              	;Zapisanie w tablicy wektor�w przerwa� nowej warto�ci
                                   				;adresu segmentu.                        		
  AKTYWACJA_PM	
  MOV AX,32                           					
  MOV ES,AX                            					
  MOV AX,40                            					
  MOV GS,AX                            					
  MOV FS,AX                            					
;Instrukcja MOV EAX, CR4 zapisana w kodzie maszynowym:
  DB 0FH                                                      	
  DB 20H                                                      	
  DB 0E0H                                                     	
  OR EAX, 11B 		;Ustawiane 2 ostatnie bity
;Instrukcja MOV CR4, EAX zapisana w kodzie maszynowym:
  DB 0FH                                                       	
  DB 22H                                                       	
  DB 0E0H                                                      	
  CALL PM_WYMAZ_EKRAN 	;Wymazanie ekranu    	    
;Za�adowanie rejestru zadania TR selektorem segmentu stanu zadania TSS nr 0:
  MOV AX,48               							
  LTR AX                  							
;Prze��czenie na zadanie nr 1 rozkazem JMP:
  JMP DWORD PTR TASK2_OFFS   
  MIEKI_POWROT_RM						
;Procesor pracuje w trybie real
  DB 0FH                                                      	
  DB 20H                                                      	
  DB 0E0H                                                     	
  AND EAX, 0FFFFFFFCH 	;Kasowane 2 ostatnie bity
;Instrukcja MOV CR4, EAX zapisana w kodzie maszynowym:
  DB 0FH                                                       	
  DB 22H                                                       	
  DB 0E0H              
  MOV AX, DANE                							
  MOV DS,AX  
  MOV AX,STK                  							
  MOV SS,AX    	
  MOV AX, 0
  MOV ES, AX				
;Odtworzenie oryginalnego elementu tablicy wektor�w przerwa� dla przerwania 1ch:
  MOV AX, OFFSET_PRZERWANIA_1CH   
  MOV ES:70H, AX                  
  MOV AX, SEGMENT_PRZERWANIA_1CH  
  MOV ES:72H, AX                  
  POWROT_DO_RM 0,1
MAIN	ENDP

INCLUDE PROC.TXT
PROGRAM_SIZE=$-BEGIN
PROGRAM	ENDS
;Poni�szy segment zawiera procedury obs�ugi wyj�tk�w i kod wirtualnego monitora:
PRZERWANIA SEGMENT  USE32
ASSUME CS:PRZERWANIA
BEGIN2 LABEL DWORD
INCLUDE VM86.TXT
;W tej wersji programu procedura wirtualnego monitora zosta�a ograniczona do minimum.
VIRTUALNY_MONITOR PROC
  RET
VIRTUALNY_MONITOR ENDP
;Procedura obs�ugi wi�kszo�ci wyj�tk�w:
EXC_ 	PROC
  IRETD
EXC_ ENDP
;Procedura obs�ugi wyj�tku 13- prze��cza procesor w tryb real:
EXC_13	PROC					
  DB 66H
  DB 0EAH
  DW 0
  DW 48             
  IRETD          
EXC_13	ENDP		
INT_SIZE=$-BEGIN2
PRZERWANIA ENDS

KOD_REAL	SEGMENT 'CODE' USE16
ASSUME CS:KOD_REAL
BEGIN3	LABEL WORD
  JMP REAL_DALEJ           							
;Tablice przechowuj�ce wypisywane ci�gi znak�w:
  TXT_REAL DB 'PRZY POMOCY WYWOLANEGO PRZERWANIA 1CH TEKST TEN WIDOCZNY JEST NA EKRANIE', 0
  TXT_REAL2 DB 'JAK WIDAC PRZEKIEROWANIE PRZERWANIA DO TRYBU WIRTUALNEGO DZIALA        ',0
  TXT_REAL3 DB 'KONCZYMY PROGRAM WYWOLUJAC PRZERWANIE 13, KTORE ZOSTANIE OBSLUZONE Z POZIOMU      TRYBU PROTECTED ',0
  REAL_DALEJ:
;Pos�uguj�c si� przerwaniem 1ch wypisujemy tekst na ekranie- SI zawiera przesuni�cie ci�gu znak�w, 
;di natomiast przesuni�cie w segmencie ekranu pocz�wszy, od kt�rego nast�pi wypisywanie.
;Warto podkre�li�, �e wywo�anie tego przerwania spowoduje, �e procesor skorzysta z tablicy wektor�w przerwa� 
;a nie IDT (wyzerowany bit 1ch w mapie IR).
  MOV SI, OFFSET TXT_REAL            
  XOR DI, DI                         
  INT 1CH                            
  MOV SI, OFFSET TXT_REAL2           
  MOV DI, 160                        
  INT 1CH                            
  MOV SI, OFFSET TXT_REAL3           
  MOV DI, 480                        
  INT 1CH                            
  INT 13                  	;Wywo�anie przerwania 13 spowoduje zako�czenie
                                ;programu- procesor skorzysta z IDT gdy� bit 13
                                ;w mapie IR  jest ustawiony.   
;Procedura obs�ugi przerwania 1ch
PRZERWANIE_1CH PROC
;Rejestr ES �adowany 16 starszymi bitami adresu trybu tekstowego:
  MOV AX, 0B800H          
  MOV ES, AX              
;Wypisywanie znak�w spod adresu CS:SI a� do napotkania bajtu r�wnego 0:
  REAL_PETLA:
    MOV AL, [CS:SI]  
    CMP AL, 0        
    JE REAL_KONIEC_PETLI   
    MOV [ES:DI], AL        
    INC DI                 
    INC DI                 
    INC SI                 
    JMP REAL_PETLA           
  REAL_KONIEC_PETLI:        
  IRET                     
PRZERWANIE_1CH ENDP

V86_SIZE=$-BEGIN3
KOD_REAL ENDS

STK	SEGMENT STACK 'STACK'	;Dla programu g��wnego.
  DB 256 DUP (0)
STK	ENDS

STK_V86 SEGMENT         	;Dla v86
  DB 256 DUP (0)
STK_V86 ENDS

STK_INT SEGMENT         	;Dla procedur obs�ugi wyj�tk�w (32-bitowy)
  DB 256 DUP (0)
STK_INT ENDS

END	MAIN

