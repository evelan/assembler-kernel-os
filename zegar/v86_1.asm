.386P
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
INCLUDE GDT.TXT
GDT_INT       	DESKR <INT_SIZE-1,,,10011010B,01000000B>  ;40
GDT_TSS_0	DESKR <103,0,0,89H>			;Selektor 48, deskryptor TSS_0
GDT_TSS_2     	DESKR <103,0,0,0E9H>   			;Selektor 56, dekskryptor TSS_2
GDT_INT_STACK 	DESKR <255,0,0,92H,01000000B,0>		;Selektor 64
GDT_SIZE=$-GDT_NULL					;Rozmiar GDT
;Tablica deskryptor�w przerwa�:
IDT		LABEL WORD				
  TRAP 	13 	DUP(<EXC_,40>)
  TRAP        	<EXC_13,40>  	;#GP
  TRAP  18    	DUP(<EXC_,40>)
  INTR  		<ZEGAR,40>
  INTR  		<KLAWIATURA,40>
; ... 
IDT_SIZE=$-IDT			;Rozmiar tablicy IDT
PDESKR		DQ 0		;Pseudodeskryptor
ORG_IDT       	DQ 0
TEKST_VME 	DB 'CLI SPOWODOWAL WYJATEK. ZOSTAJE URUCHOMIONY MECHANIZM ROZSZERZONEGO TRYBU VM',0
TEKST_VME2	DB 'PO WYSTAPIENIU WYJATKU MONITOR KASUJE VIP      ', 0
INFO		DB 'POWROT Z TRYBU CHRONIONEGO $'
INFO1		DB 'PRZELACZENIE W TRYB PROTECTED $'
TSS_0		DB 104	DUP(0) ;Segment stanu zadania 0 (proc. main)
TSS_2         	DB 104  DUP(0) ;Segment stanu zadania 2
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
  XOR EAX, EAX
  INICJOWANIE_DESKRYPTOROW
  MOV AX,SEG DANE           					
  SHL EAX,4					
  MOV EBP,EAX	
  INICJACJA_TSS0
 ;   V         IOPL IF
  INICJACJA_TSS2 00000000000000100000001000000000B
;Wyprowadzenie na ekran tekstu INFO1
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
;Instrukcja MOV EAX, CR4 zapisana w kodzie maszynowym:
  DB 0FH                                                      	
  DB 20H                                                      	
  DB 0E0H                                                     	
  AND EAX, 0FFFFFFFCH 	;Kasowane 2 ostatnie bity
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
  DB 0FH                                                      	
  DB 20H                                                      	
  DB 0E0H                                                     	
  AND EAX, 0FFFCH 	;Kasowane 2 ostatnie bity
;Instrukcja MOV CR4, EAX zapisana w kodzie maszynowym: 
  DB 0FH                                                       	
  DB 22H                                                       	
  DB 0E0H    						
;Procesor pracuje w trybie Real
  KONTROLER_PRZERWAN_RM
  MIEKI_POWROT_RM
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

;Wirtualny monitor odpowiedzialny jest za obs�ug� przerwa� wygenerowanych w procesach
;wykonuj�cych si� w trybie wirtualnym.
VIRTUALNY_MONITOR PROC
;W pierwszej kolejno�ci sprawdzany jest zerowy bit rejestru CR4 je�eli jest on ustawiony- oznacza to, 
;�e bit VME jest ustawiony i nast�puje skok w dalsz� cz�� kodu wirtualnego monitora.
;W przypadku, gdy bit ten jest wyzerowany, nast�puje jego ustawienie, ustawienie bitu PVI,
;i wypisanie tekstu informacyjnego na ekran:
  MOV ECX, EAX                      						
  MOV_EAX_CR4                       						
  MOV EBX, 1                        						
  AND EBX, EAX                      						
  CMP EBX, 1                        						
  JE VME_DOSTEPNY                   						
;Ta cz�� kodu wykona si� gdy bit VME by� wyzerowany:
  OR EAX, 1B             	;Ustawienie pierwszego bitu				 
  MOV_CR4_EAX                    						
;Wypisanie tekstu informacyjnego na ekranie:
  MOV AX, 8                      						
  MOV DS, AX                     						
  MOV BX, OFFSET TEKST_VME       						
  MOV DI, 320                    						
  PM_WYPISZ_TEKST                						
  JMP KONIEC_VM                  						 
  VME_DOSTEPNY:                     						
;Sprawdzany jest warunek czy procedura obs�ugi przerwania klawiatury nie wywo�a�a wirtualnego monitora:
  CMP CX, 33                        						
  JNE NIE_KLAWIATURA                						
;Ta cz�� kodu wykona si�, gdy wirtualny monitor zosta� wywo�any przez procedur� obs�ugi przerwania klawiatury.
;Odczytanie ze stosu rejestru EFLAGS procesu wykonuj�cego si� w trybie wirtualnym:
  MOV EBX, ESP                   						
  POP EAX     ;Offset proc							
  POP EAX     ;EIP programu               					
  POP EAX     ;CS programu                					
  POP EAX     ;EFLAGS                     					
  XCHG ESP, EBX                            					
;Okre�lenie stanu bitu VIF w obrazie rejestru EFLAGS, gdy jest on ustawiony (wirtualne przerwania dozwolone) 
;nast�puje skok do etykiety    VIRTUALNE_PRZERWANIA_WYLACZANE. Przeciwnie, gdy bit ten jest wyzerowany 
;nast�puje ustawienie bitu VIP oraz ustawienie flagi CF co b�dzie znakiem dla procesu wykonuj�cego si� 
;w trybie wirtualnym, �e nast�pi�o przerwanie klawiatury:
  MOV EDX, 10000000000000000000B           				
  AND EDX, EAX                             					
  CMP EDX, 0          		;Okre�lany stan bitu VIF.	
  JNE VIRTUALNE_PRZERWANIA_WLACZANE        				
;Ta cz�� kodu wykona si� gdy bit vif jest wyzerowany:
  OR EAX,  100000000000000000001B ;Ustawienie VIP i CF.	
  XCHG ESP, EBX                         					
  PUSH EAX              	;Zapisanie nowego obrazu EFLAGS.	
  MOV ESP, EBX           	;Przywr�cenie w�a�ciwego szczytu stosu.	    
  VIRTUALNE_PRZERWANIA_WLACZANE:           			
;...
  JMP KONIEC_VM                            					   
  JMP KONIEC_VM                               				
  NIE_KLAWIATURA:                             				
;Wyj�tek 13 b�dzie  generowany w kodzie programu wykonuj�cego si� w trybie wirtualnym w miejscu, 
;gdy nast�puje wywo�anie instrukcji STI (w��czenie przerwa�) przy ustawionym bicie VIP i wyzerowanym VIF. 
;Wirtualny monitor podejmuje czynno�ci zwi�zane z ustawieniem pola VIF i wykasowaniem VIP:
  CMP CX, 13                                 	 			
  JNE KONIEC_VM                               				
;Ta cz�� wykona si�, gdy wyj�tek 13 wywo�a� wirtualny monitor; zapisanie w rejestrze EAX 
;obrazu EFLAGS procesu wykonuj�cego si� w trybie wirtualnym:
  MOV EBX, ESP                                   				
  POP EAX     			;Offset wirtualnego monitora       			
  POP EAX     			;EIP programu                    					
  POP EAX     			;CS programu                     			
  POP EAX     			;EFLAGS                           		
  XCHG ESP, EBX                                  				
;Okre�lenie stanu bitu VIP w EFLAGS:
  MOV EDX, 100000000000000000000B                				
  AND EDX, EAX                                   				
  CMP EDX, 100000000000000000000B                				
  JNE KONIEC_VM                                  				
;Ta cz�� wykona si�, gdy bit VIP jest ustawiony
;Kasowanie bitu VIP:
  MOV EDX, 100000000000000000000B             				
  NOT EDX                                     				
  AND EAX, EDX                                				
;Ustawienie bitu VIF:
  OR EAX, 10000000000000000000B               				
  XCHG ESP, EBX                               				
  PUSH EAX              	;Zapis nowego obrazu EFLAGS
  MOV ESP, EBX           	;Przywr�cenie szczytu stosu
;Wyprowadzenie informacji na ekranie o przeprowadzonych czynno�ciach:
  MOV AX, 8                                      				
  MOV DS, AX                                     				
  MOV BX, OFFSET TEKST_VME2                      				
  MOV DI, 1600                                   				
  PM_WYPISZ_TEKST                                				
  KONIEC_VM:                                           			
  RET                                                  			
VIRTUALNY_MONITOR ENDP
;Poni�ej znajduje si� wsp�lna procedura obs�ugi wi�kszo�ci wyj�tk�w, powoduje ona przej�cie procesora w tryb real:
EXC_ 	PROC
  DB 66H
  DB 0EAH
  DW 0
  DW 48				
  IRETD    			
EXC_ ENDP

;Procedura obs�ugi wyj�tku 13
EXC_13	PROC
  POP EAX   			;Odczyt ze stosu kodu b��du. 
  CZY_POTRZEBNY_MONITOR   	;Okre�lenie czy niezb�dne b�dzie wywo�anie wirtualnego monitora.	
  JE EXC_0_NIE_V           							
  MOV AX, 13              	;Przekazanie parametru dla wirtualnego monitora.
  CALL VIRTUALNY_MONITOR  	;Wywo�anie procedury wirtualnego monitora. 
  EXC_0_NIE_V:
  IRETD                                             			
EXC_13	ENDP

ZEGAR PROC
ZEGAR ENDP

;Procedura obs�ugi przerwania klawiatury:
KLAWIATURA PROC
  CZY_POTRZEBNY_MONITOR  	;Okre�lenie czy przerwanie nast�pi�o w procesie
                                ;wykonuj�cym si� w trybie wirtualnym.
  JE KLAWIATURA_NIE_V    				
  MOV AX, 33          		;Parametr dla wirtualnego monitora.	
  CALL VIRTUALNY_MONITOR  	;Wywo�anie wirtualnego monitora. 
  KLAWIATURA_NIE_V:
  IN AL,60h			;Pobranie numeru przyci�ni�tego klawisza
  MOV DL,AL
  IN AL,61h			;Potwierdzenie pobrania numeru klawisza
  OR AL,80h
  OUT 61h,AL
  AND AL,7Fh
  OUT 61h,AL
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
;Zmienne tablicowe przechowuj�ce napisy informacyjne wypisywane na ekran w trybie wirtualnym:
  TXT_REAL DB 'TRYB V86, WYWOLANIE INSTRUKCJI CLI (PRZY IOPL < 3 !)     ', 0
  TXT_REAL2 DB 'WYWOLANIE INSTRUKCJI CLI PO UAKTYWNIENIU VIRTUALNYCH PRZERWAN', 0
  TXT_REAL3 DB 'WCISNIECIE DOWOLNEGO KLAWISZA SPOWODUJE USTAWIENIE PRZEZ MONITOR FLAGI VIP        ', 0
  TXT_REAL4 DB 'USTAWIENIE FLAGI VIF Z USTAWIONA VIP SPOWODUJE WYWOLANIE WYJATKU 13- #GP         ',0
  REAL_DALEJ:
;Wypisanie na ekran komunikatu spod zmiennej TXT_REAL:
  XOR DI, DI               							
  MOV SI, OFFSET TXT_REAL  							
  REAL_WYPISZ_TEKST       						
;W tej chwili system wirtualnych przerwa� nie jest dost�pny, wi�c wywo�anie poni�szej instrukcji CLI spowoduje wyj�tek:
  CLI                    	;Procedura obs�ugi wyj�tku wywo�a wirtualny monitor, kt�ry 
                               	;ustawi bity VME i PVI w CR4		
;Wypisanie tekstu spod zmiennej TXT_REAL2:
  MOV DI, 640               							
  MOV SI, OFFSET TXT_REAL2  							
  REAL_WYPISZ_TEKST         						      
;W tej chwili system wirtualnych przerwa� jest uaktywniony, wywo�anie instrukcji CLI jest wi�c mo�liwe
  CLI                        							
;Wypisanie tekstu spod zmiennej TXT_REAL3
  MOV DI, 960               							
  MOV SI, OFFSET TXT_REAL3  							
  REAL_WYPISZ_TEKST         						
;Poni�sza p�tla b�dzie wykonywa� si� do chwili, gdy zostanie przyci�ni�ty przycisk klawiatury (procedura 
;obs�ugi przerwania klawiatury ustawia flag� CF). nale�y przypomnie� o fakcie, �e pole VIF jest wyzerowane- 
;procedura obs�ugi przerwania klawiatury wywo�a wirtualny monitor, kt�ry ustawi flag� VIP aby zachowa� 
;informacj� o tym, �e nast�pi�o przerwanie.
  CLC                      							
  NIE_WCISNIETO_KLAWISZA:  						
  JNC NIE_WCISNIETO_KLAWISZA     						
;Wypisanie tekstu spod zmiennej TXT_REAL4:
  MOV DI, 1280                       						
  MOV SI, OFFSET TXT_REAL4           						
  REAL_WYPISZ_TEKST                  					
;Wywo�anie instukcji STI w sytuacji gdy jest wyzerowane pole VIF i ustawione VIP zaskutkuje 
;wygenerowaniem wyj�tku 13, kt�ry wywo�a wirtualny monitor w celu obs�ugi zaistnia�ej sytuacji.
  STI                                						
;Procedura obs�ugi wyj�tku dzielenia przez 0 prze��czy procesor w tryb real
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

