.386P
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
;Globalna tablica deskryptor�w  (w komentarzach znajduj� si� selektory segment�w)
INCLUDE GDT.TXT
GDT_INT       	DESKR <INT_SIZE-1,,,10011010B,01000000B>  ;40
GDT_TSS_0	DESKR <103,0,0,89H>			;Selektor 48, deskryptor TSS_0
GDT_TSS_2     	DESKR <103+100,0,0,0E9H>   		;Selektor 56, dekskryptor TSS_2
GDT_INT_STACK 	DESKR <255,0,0,92H,01000000B,0>		;Selektor 64
GDT_SIZE=$-GDT_NULL					;Rozmiar GDT.
;Tablica deskryptor�w przerwa�
IDT		LABEL WORD	;Pocz�tek IDT.
  TRAP 	13 	DUP(<EXC_,40>)
  TRAP        	<EXC_13,40> ;#GP
  TRAP   18    DUP(<EXC_,40>)
  INTR  	<ZEGAR,40>
  INTR  	<KLAWIATURA,40>
; ...
IDT_SIZE=$-IDT			;Rozmiar tablicy IDT.
PDESKR		DQ 0		;Pseudodeskryptor
ORG_IDT       	DQ 0
INFO		DB 'POWROT Z TRYBU CHRONIONEGO $'
INFO1		DB 'PRZELACZENIE W TRYB PROTECTED $'
IO_BLAD DB 'JAK WIDAC PROBA DOSTEPU DO PORTU OPISANEGO W MAPIE I/0 JEDYNKA POWODUJE WYJATEK',0

TSS_0		DB 104	DUP(0) ;Segment stanu zadania 0 (proc. main)
TSS_2         	DB 104  DUP(0) ;Segment stanu zadania 2
TSS_2_CD      	DB 100  DUP(0FFH)
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
;  VIF VM     IOPL IF  
  INICJACJA_TSS2 00000000000010100011001000000000B
;Zgodnie z budow� TSS pod offsetem 100 wzgl�dem jego pocz�tku znajduje si� podw�jne s�owo,
;kt�rego starsze 2 bajty wskazuj� na pocz�tek mapy zezwole� I/O. Poni�ej nast�puje
;za�adowanie tego pola (starszych 16 bit�w) warto�ci� 104, co spowoduje,
;�e binarna mapa zezwole� I/O b�dzie znajdowa�a si� na pozycji 104 wzgl�dem pocz�tku TSS:
  MOV EAX, 104                               
  SHL EAX, 16                        
  MOV DWORD PTR TSS_2+100, EAX                  
;W binarnej mapie zezwole� I/O zezwalamy tylko 16 pierwszych port�w:
  MOV EAX, 11111111111111110000000000000000B        
  MOV DWORD PTR TSS_2+104, EAX                     

;Nast�pnie zezwalamy na korzystanie z portu 66 i 67 (dwa pierwsze bity w 9 bajcie mapy):
  MOV EBX, 1100B                                    
  MOV EAX, DWORD PTR TSS_2+112                     
  XOR EAX, EBX                                 
  MOV DWORD PTR TSS_2+112, EAX           
;Oraz z portu 97 (pierwszy bit trzynastego bajtu mapy):
  MOV EAX, DWORD PTR TSS_2+116                  
  MOV EBX, 10B                                 
  XOR EAX, EBX                                  
  MOV DWORD PTR TSS_2+116, EAX                    
;Wyprowadzenie na ekran tekstu info1
  MOV AH,9  								
  MOV DX,OFFSET INFO1 							
  INT 21H       								
  CLI      
  INICJACJA_DESKR_PRZERWAN           						
  KONTROLER_PRZERWAN_PM 0FDH		
  AKTYWACJA_PM	
  MOV AX,32                           					
  MOV ES,AX                            					
  MOV AX,40                            					
  MOV GS,AX                            					
  MOV FS,AX                            					
  CALL PM_WYMAZ_EKRAN 	;Wymazanie ekranu    	    
;Za�adowanie rejestru zadania TR selektorem segmentu stanu zadania TSS nr 0:
  MOV AX,48               							
  LTR AX                  							
;Prze��czenie na zadanie nr 1 rozkazem JMP:      
  JMP DWORD PTR TASK2_OFFS   
  MIEKI_POWROT_RM						
;Procesor pracuje w trybie real
  KONTROLER_PRZERWAN_RM	
  POWROT_DO_RM 0,1                 						
MAIN	ENDP

INCLUDE PROC.TXT

PROGRAM_SIZE=$-BEGIN
PROGRAM	ENDS
;Poni�szy segment zawiera procedury obs�ugi wyj�tk�w i kod wirtualnego monitora:
PRZERWANIA SEGMENT  USE32
ASSUME CS:PRZERWANIA
BEGIN2 LABEL DWORD
;Makro ustala, czy wyj�tek zosta� wygenerowany w trakcie wykonywania
;si� programu w trybie wirtualnym:
INCLUDE VM86.TXT
;Procedura wirtualnego monitora wywo�ywana przez procedury obs�ugi przerwa�/wyj�tk�w:
VIRTUALNY_MONITOR PROC
;Sprawdzenie, czy procedur� wywo�uj�c� wirtualny monitor by�a procedura obs�ugi wyj�tku 13:
  CMP AX, 13                       
  JNE NIE_GP                       
;Wyj�tek 13 generowany jest w procesie wykonuj�cym si� w trybie wirtualnym w momencie pr�by 
;dost�pu do zabronionego portu. poni�ej wypisywany jest odpowiedni komunikat:
  MOV AX, 8               
  MOV DS, AX           
  MOV BX, OFFSET IO_BLAD 
  MOV DI, 320     
  PM_WYPISZ_TEKST        
;Zwi�kszany jest obraz rejestru EIP znajduj�cy si� na stosie tak by wskazywa�
;nast�pn� instrukcj� (po instrukcji OUT generuj�cej wyj�tek):
  MOV EBX, ESP                 
  POP EAX                       
  POP EAX                       
  ADD AX, OUT_SIZE              
  PUSH EAX                      
  MOV ESP, EBX                       
  JMP KONIEC_VM                     
  NIE_GP:                               
;Gdy rejestr AX zawiera warto�� 33 oznacza to, �e nast�pi�o wywo�anie wirtualnego monitora
;z procedury obs�ugi przerwania klawiatury:
  CMP AX, 33                              
  JNE NIE_KLAWIATURA                      
;W tym wypadku ustawiana jest flaga CF w obrazie EFLAGS zachowanym na stosie:
  MOV EBX, ESP                  
  POP EAX     			;Offset powrotu z wirtualnego monitora. 
  POP EAX     			;EIP programu.   
  POP EAX     			;CS programu.   
  POP EAX     			;EFLAGS.         
  OR EAX, 1B  			;Ustawienie flagi CF. 
  PUSH EAX    			;Od�o�enie zmienionego EFLAGS. 
  MOV ESP, EBX           
  JMP KONIEC_VM          
  JMP KONIEC_VM             
  NIE_KLAWIATURA:
  KONIEC_VM:                 
  RET                           
VIRTUALNY_MONITOR ENDP
;Procedura obs�ugi wi�kszo�ci wyj�tk�w (ko�czy program)
EXC_ 	PROC
  DB 066H
  DB 0EAH
  DW 0
  DW 48             
  IRETD          
EXC_ ENDP
;Procedura obs�ugi wyj�tku 13
EXC_13	PROC
  POP EAX 			;Pobranie kodu b��du
  CZY_POTRZEBNY_MONITOR       
  JE EXC_13_NIE_V           
  MOV AX, 13             
  CALL VIRTUALNY_MONITOR 
  EXC_13_NIE_V:             
  IRETD                       
EXC_13	ENDP

ZEGAR PROC
ZEGAR ENDP

;Procedura obs�ugi przerwania klawiatury
KLAWIATURA PROC
  IN AL,60h			;Pobranie numeru przyci�ni�tego klawisza
  MOV DL,AL
  IN AL,61h			;Potwierdzenie pobrania numeru klawisza
  OR AL,80h
  OUT 61h,AL
  AND AL,7Fh
  OUT 61h,AL
  AND DL, 10000000B
  JNZ KLAWIATURA_NIE_V
  CZY_POTRZEBNY_MONITOR 
  JE KLAWIATURA_NIE_V  
  MOV AX, 33        
  CALL VIRTUALNY_MONITOR  
  KLAWIATURA_NIE_V:  
  MOV AL,20h			;Sygna� ko�ca obs�ugi przerwania
  OUT 20h,AL        
  IRETD                      
KLAWIATURA ENDP

INT_SIZE=$-BEGIN2
PRZERWANIA ENDS

KOD_REAL	SEGMENT 'CODE' USE16
ASSUME CS:KOD_REAL
BEGIN3	LABEL WORD
  JMP REAL_DALEJ                    
;Tablice przechowuj�ce wypisywane ci�gi znak�w:
  TXT_REAL DB 'DOSTEP DO PORTU 25', 0
  TXT_REAL2 DB 'W CELU POKAZANIA MECHANIZMU DOSTEPU DO PORTOW UDOSTEPNIONYCH WYKORZYSTAMY       GLOSNICZEK SYSTEMOWY        ',0
  TXT_REAL3 DB 'ABY ZAKONCZYC JEGO PRACE NACISNIJ DOWOLNY PRZYCISK NA KLAWIATURZE',0
  REAL_DALEJ:
;Wypisanie tekstu spod zmiennej TXT_REAL
  MOV SI, OFFSET TXT_REAL                
  XOR DI, DI                             
  REAL_WYPISZ_TEKST                        
;Pr�ba dost�pu do zabronionego portu- generowany wyj�tek:
  POCZATEK_OUT LABEL WORD         
  OUT 25, AL                      
  OUT_SIZE=$-POCZATEK_OUT         
;Wypisanie tekstu spod TXT_REAL2:
  MOV SI, OFFSET TXT_REAL2     
  MOV DI, 640                   
  REAL_WYPISZ_TEKST              
;Wypisanie tekstu spod TXT_REAL3:
  MOV SI, OFFSET TXT_REAL3    
  MOV DI, 1120                 
  REAL_WYPISZ_TEKST              
;Dost�p do dozwolonych port�w dla procesu- 66, 67, 97- w��czenie g�o�niczka systemowego:
  MOV AL, 0B6H            
  OUT 67, AL  			;Do portu wpisujemy warto�� sta�ej steruj�cej, okre�laj�cej zmian�
                  		;dzielnika cz�stotliwo�ci zegara systemowego 
  MOV AL, 10                                   
  OUT 66, AL  			;M�odszy bajt dzielnika cz�stotliwo�ci. 
  MOV AL, 10                
  OUT 66, AL  			;Starszy bajt dzielnika cz�stotliwo�ci. 
;Uaktywnienie g�o�niczka systemowego:
  IN AL, 97                
  OR AL, 11B               
  OUT 97, AL               
;P�tla b�dzie si� wykonywa�a a� do naci�ni�cia klawisza (procedura obs�ugi
;przerwania klawiatury ustawia flag� CF w EFLAGS zadania):
  CLC
  POWTAZAJ:              
  JNC POWTAZAJ           
;Wy��czenie g�o�niczka systemowego:
  AND AL, 11111100B      
  OUT 97, AL             
;Wywo�anie procedury obs�ugi wyj�tku dzielenia przez zero, kt�ra zako�czy program:
  XOR DX, DX           
  DIV DX               
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

