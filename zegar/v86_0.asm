.386P
INCLUDE STRUKT.TXT
DANE	SEGMENT USE16
INCLUDE GDT.TXT
GDT_INT    	DESKR <INT_SIZE-1,,,10011010B,01000000B>  ;Selektor 40, 
							  ;segment procedur obs³ugi wyj¹tków. 
GDT_TSS_0	DESKR <103,0,0,89H>			;Selektor 48, deskryptor TSS_0
GDT_TSS_2     	DESKR <103,0,0,89H>          		;Selektor 56, dekskryptor TSS_2
GDT_INT_STACK 	DESKR <255,0,0,92H,01000000B,0> 	;Selektor 64
GDT_SIZE=$-GDT_NULL					;Rozmiar GDT
;Tablica deskryptorów przerwañ:
IDT		LABEL WORD					
  TRAP            <EXC_0,40>
  TRAP 	31 	DUP(<EXC_,40>)
IDT_SIZE=$-IDT			;Rozmiar tablicy IDT

PDESKR		DQ 0		;Pseudodeskryptor
ORG_IDT   	DQ 0
INFO		DB 'POWROT Z TRYBU CHRONIONEGO $'
INFO1		DB 'PRZELACZENIE W TRYB PROTECTED $'
TSS_0		DB 104	DUP(0);SEGMENT STANU ZADANIA 0 (PROC. MAIN)
TSS_2       	DB 104  DUP (0) ;Segment stanu zadania 2.
TASK0_OFFS	DW 0		;4-bajtowy adres dla prze³¹czenia
TASK0_SEL	DW 48		;na zadanie 0 przez TSS.
TASK2_OFFS	DW 0		;4-bajtowy adres dla prze³¹czenia
TASK2_SEL	DW 56		;na zadanie 1 przez TSS_2

DANE_SIZE=$-GDT_NULL		;Rozmiar segmentu danych.
DANE	ENDS

PROGRAM	SEGMENT  'CODE' USE16
ASSUME CS:PROGRAM,DS:DANE
BEGIN	LABEL WORD

INCLUDE MAKRA.TXT

MAIN	PROC
  XOR EAX,EAX	
  INICJOWANIE_DESKRYPTOROW			
  MOV AX,SEG DANE           					
  SHL EAX,4					
  MOV EBP,EAX				
  INICJACJA_TSS0	
;                              V  IOPL 					
  INICJACJA_TSS2 00000000000000100011000000000000B		
;Wyprowadzenie na ekran tekstu info1:
  MOV AH,9  								
  MOV DX,OFFSET INFO1 							
  INT 21H       								
;Przygotowanie do prze³¹czenia w tryb protected:
  CLI        
  INICJACJA_DESKR_PRZERWAN	         						
  AKTYWACJA_PM						
  MOV AX,32                            				
  MOV ES,AX                            					
  MOV AX,40                            					
  MOV GS,AX                            					
  MOV FS,AX                            					
  CALL PM_WYMAZ_EKRAN 	;Wymazanie ekranu    			
;Za³adowanie rejestru zadania TR selektorem segmentu stanu zadania TSS nr 0:
  MOV AX,48               						
  LTR AX                  						
;Prze³¹czenie na zadanie nr 1 rozkazem CALL, lub JMP:                    				
  JMP DWORD PTR TASK2_OFFS					
  MIEKI_POWROT_RM                  					
;Zakoñczenie programu g³ównego:
  CLI
  POWROT_DO_RM 0,1             						
MAIN	ENDP

INCLUDE PROC.TXT

PROGRAM_SIZE=$-BEGIN
PROGRAM	ENDS

;Poni¿szy segment zawiera procedury obs³ugi wyj¹tków i kod wirtualnego monitora:
PRZERWANIA SEGMENT  USE32
ASSUME CS:PRZERWANIA
BEGIN2 LABEL DWORD
INCLUDE VM86.TXT
;Wirtualny monitor odpowiedzialny za obs³ugê wyj¹tków wygenerowanych w procesach wykonuj¹cych siê w trybie wirtualnym:
VIRTUALNY_MONITOR PROC
;Okreœlenie Ÿród³a wygenerowanego wyj¹tku (0- dzielenie przez zero, reszta okreœla pozosta³e wyj¹tki)
  CMP AX, 0                						
  JNE DZIELENIE            					
;W przypadku wykrycia wyst¹pienia wyj¹tku ró¿nego od 0 nastêpuje zakoñczenie programu:
  DB 66H
  DB 0EAH
  DW 0
  DW 48			
  DZIELENIE:
;Gdy zostanie wykryty wyj¹tek dzielenia przez zero nastêpuje zwiêkszenie rejestru EIP tak by 
;wskazywa³ na nastêpn¹ instrukcjê (wyj¹tek zero jest z grupy faults wiêc domyœlnie wykonanie 
;instrukcji powrotu z procedury obs³ugi spowodowa³oby ponowne wykonanie instrukcji powoduj¹cej wyj¹tek).
  MOV EBX, ESP            						
  POP EAX                 						
;Dodanie do zachowanego na stosie rejestru EIP wielkoœci rozkazu DIV:
  POP EAX                 						
  ADD AX, DIV_SIZE        					
  PUSH EAX                						
  
  MOV ESP, EBX            						
  MONITOR_KONIEC:
  RET                       						
VIRTUALNY_MONITOR ENDP

EXC_ 	PROC
  POP EAX                	;Zdjêcie ze stosu kodu b³êdu.   		
  CZY_POTRZEBNY_MONITOR  	;Okreœlenie, czy potrzebne bêdzie wywo³anie wirtualnego monitora.
  JE EXC_NIE_V           	;Je¿eli nie, nastêpuje skok na koniec procedury obs³ugi wyj¹tku.
;W przypadku gdy proces powoduj¹cy wyj¹tek  wykonuje siê w trybie wirtualnym, wywo³ywany 
;jest wirtualny monitor z parametrem w rejestrze AX równym zero.
  MOV AX, 0                          			
  CALL VIRTUALNY_MONITOR            
  EXC_NIE_V:
  IRETD                                   
EXC_ ENDP

;Procedura obs³ugi wyj¹tku dzielenia przez zero:
EXC_0	PROC				
;Okreœlenie czy potrzebne bêdzie wywo³anie wirtualnego monitora:
  CZY_POTRZEBNY_MONITOR              
  JE EXC_0_NIE_V                      			
;Gdy proces powoduj¹cy wyj¹tek dzielenia przez zero wykonywa³ siê w trybie wirtualnym
;nastêpuje wywo³anie wirtualnego monitora z parametrem w rejestrze AX o wartoœci 1:
  MOV AX, 1                        	
  CALL VIRTUALNY_MONITOR          
  EXC_0_NIE_V:
  IRETD                                 	
EXC_0	ENDP					

INT_SIZE=$-BEGIN2
PRZERWANIA ENDS

KOD_REAL	SEGMENT 'CODE' USE16
ASSUME CS:KOD_REAL
BEGIN3	LABEL WORD

  JMP REAL_DALEJ              
;Ci¹gi znaków do wypisania na ekranie przechowywane s¹ w segmencie kodu:
  TXT_REAL DB 'TEKST WYPISANY ANALOGICZNIE JAK TO MOZNA ZROBIC W TRYBIE REAL,'
           DB 'POWDODUJEMY WYJATEK DZIELENIA PRZEZ 0                ',0	
  TXT_REAL2 DB 'UZYJEMY TERAZ NIEDOZWOLONEJ INSTRUKCJI DLA TRYBU VM86, A PROCEDURA  OBSLUGI WYWOLANEGO WYJATKU SPOWODUJE ZAKONCZENIE PROGRAMU', 0    
  REAL_DALEJ:
;Przygotowanie do wypisania tablicy znaków TXT_REAL na ekranie - w tym celu para rejestrów ES:DI ustawiana 
;jest na adres pocz¹tku trybu tekstowego (proces dzia³a w trybie wirtualnym, wiêc adresacja wygl¹da
;analogicznie jak dla trybu real) rejestr SI ³adowany jest natomiast przesuniêciem zmiennej txt_real:
  MOV AX, 0B800H              					
  MOV ES, AX                  				
  XOR DI, DI                  				
  MOV SI, OFFSET TXT_REAL     				
;Poni¿sza pêtla wypisuje kolejne znaki zmiennej TXT_REAL a¿ do napotkania bajtu równego 0:
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
;Przygotowanie do wykonania dzielenia przez zero (zostanie wygenerowany wyj¹tek 0):
  MOV DX, 0          
  POCZATEK_INSTRUKCJI LABEL WORD    	
  DIV DX                      	
  DIV_SIZE=$-POCZATEK_INSTRUKCJI ;Obliczenie wielkoœci instrukcji (aby w procedurze
                                  			;obs³ugi wyj¹tku 0 ustawiæ rejestr EIP na kolejn¹ 
                                 			;instrukcjê programu                                 
;Przygotowania do wypisania tekstu zawartego pod zmienn¹ TXT_REAL2:
  MOV DI, 1120          	;Przesuniêcie w segmencie ekranu. 
  MOV SI, OFFSET TXT_REAL2 ;Przesuniêcie zmiennej tablicowej zawieraj¹cej tekst do wypisania.      
  REAL_PETLA2:
    MOV AL, [CS:SI]           					
    CMP AL, 0                 					
    JE REAL_KONIEC_PETLI2     					
    MOV [ES:DI], AL           					
    INC DI                    					
    INC DI                    					
    INC SI                    					
    JMP REAL_PETLA2             		
  REAL_KONIEC_PETLI2:
  MOV CR0,EAX           	;Wywo³anie instrukcji powoduj¹cej wyj¹tek.
  JMP $

V86_SIZE=$-BEGIN3
KOD_REAL ENDS

STK	SEGMENT STACK 'STACK' 	;Dla programu g³ównego
DB 256 DUP (0)
STK	ENDS

STK_V86 SEGMENT             	;Dla v86
DB 256 DUP (0)
STK_V86 ENDS

STK_INT SEGMENT            	;Dla procedur obs³ugi wyj¹tków (32-bitowy)
DB 256 DUP (0)
STK_INT ENDS

END	MAIN

