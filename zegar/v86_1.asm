.386P
INCLUDE STRUKT.TXT

DANE	SEGMENT USE16
INCLUDE GDT.TXT
GDT_INT       	DESKR <INT_SIZE-1,,,10011010B,01000000B>  ;40
GDT_TSS_0	DESKR <103,0,0,89H>			;Selektor 48, deskryptor TSS_0
GDT_TSS_2     	DESKR <103,0,0,0E9H>   			;Selektor 56, dekskryptor TSS_2
GDT_INT_STACK 	DESKR <255,0,0,92H,01000000B,0>		;Selektor 64
GDT_SIZE=$-GDT_NULL					;Rozmiar GDT
;Tablica deskryptorów przerwañ:
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
TASK0_OFFS	DW 0		;4-bajtowy adres dla prze³¹czenia
TASK0_SEL	DW 48		;na zadanie 0 przez TSS
TASK2_OFFS	DW 0		;4-bajtowy adres dla prze³¹czenia
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
;Za³adowanie rejestru zadania TR selektorem segmentu stanu zadania TSS nr 0:
  MOV AX,48               							
  LTR AX                  							
;Prze³¹czenie na zadanie nr 1 rozkazem JMP:      
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
;Poni¿szy segment zawiera procedury obs³ugi wyj¹tków i kod wirtualnego monitora:
PRZERWANIA SEGMENT  USE32
ASSUME CS:PRZERWANIA
BEGIN2 LABEL DWORD

INCLUDE VM86.TXT

;Wirtualny monitor odpowiedzialny jest za obs³ugê przerwañ wygenerowanych w procesach
;wykonuj¹cych siê w trybie wirtualnym.
VIRTUALNY_MONITOR PROC
;W pierwszej kolejnoœci sprawdzany jest zerowy bit rejestru CR4 je¿eli jest on ustawiony- oznacza to, 
;¿e bit VME jest ustawiony i nastêpuje skok w dalsz¹ czêœæ kodu wirtualnego monitora.
;W przypadku, gdy bit ten jest wyzerowany, nastêpuje jego ustawienie, ustawienie bitu PVI,
;i wypisanie tekstu informacyjnego na ekran:
  MOV ECX, EAX                      						
  MOV_EAX_CR4                       						
  MOV EBX, 1                        						
  AND EBX, EAX                      						
  CMP EBX, 1                        						
  JE VME_DOSTEPNY                   						
;Ta czêœæ kodu wykona siê gdy bit VME by³ wyzerowany:
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
;Sprawdzany jest warunek czy procedura obs³ugi przerwania klawiatury nie wywo³a³a wirtualnego monitora:
  CMP CX, 33                        						
  JNE NIE_KLAWIATURA                						
;Ta czêœæ kodu wykona siê, gdy wirtualny monitor zosta³ wywo³any przez procedurê obs³ugi przerwania klawiatury.
;Odczytanie ze stosu rejestru EFLAGS procesu wykonuj¹cego siê w trybie wirtualnym:
  MOV EBX, ESP                   						
  POP EAX     ;Offset proc							
  POP EAX     ;EIP programu               					
  POP EAX     ;CS programu                					
  POP EAX     ;EFLAGS                     					
  XCHG ESP, EBX                            					
;Okreœlenie stanu bitu VIF w obrazie rejestru EFLAGS, gdy jest on ustawiony (wirtualne przerwania dozwolone) 
;nastêpuje skok do etykiety    VIRTUALNE_PRZERWANIA_WYLACZANE. Przeciwnie, gdy bit ten jest wyzerowany 
;nastêpuje ustawienie bitu VIP oraz ustawienie flagi CF co bêdzie znakiem dla procesu wykonuj¹cego siê 
;w trybie wirtualnym, ¿e nast¹pi³o przerwanie klawiatury:
  MOV EDX, 10000000000000000000B           				
  AND EDX, EAX                             					
  CMP EDX, 0          		;Okreœlany stan bitu VIF.	
  JNE VIRTUALNE_PRZERWANIA_WLACZANE        				
;Ta czêœæ kodu wykona siê gdy bit vif jest wyzerowany:
  OR EAX,  100000000000000000001B ;Ustawienie VIP i CF.	
  XCHG ESP, EBX                         					
  PUSH EAX              	;Zapisanie nowego obrazu EFLAGS.	
  MOV ESP, EBX           	;Przywrócenie w³aœciwego szczytu stosu.	    
  VIRTUALNE_PRZERWANIA_WLACZANE:           			
;...
  JMP KONIEC_VM                            					   
  JMP KONIEC_VM                               				
  NIE_KLAWIATURA:                             				
;Wyj¹tek 13 bêdzie  generowany w kodzie programu wykonuj¹cego siê w trybie wirtualnym w miejscu, 
;gdy nastêpuje wywo³anie instrukcji STI (w³¹czenie przerwañ) przy ustawionym bicie VIP i wyzerowanym VIF. 
;Wirtualny monitor podejmuje czynnoœci zwi¹zane z ustawieniem pola VIF i wykasowaniem VIP:
  CMP CX, 13                                 	 			
  JNE KONIEC_VM                               				
;Ta czêœæ wykona siê, gdy wyj¹tek 13 wywo³a³ wirtualny monitor; zapisanie w rejestrze EAX 
;obrazu EFLAGS procesu wykonuj¹cego siê w trybie wirtualnym:
  MOV EBX, ESP                                   				
  POP EAX     			;Offset wirtualnego monitora       			
  POP EAX     			;EIP programu                    					
  POP EAX     			;CS programu                     			
  POP EAX     			;EFLAGS                           		
  XCHG ESP, EBX                                  				
;Okreœlenie stanu bitu VIP w EFLAGS:
  MOV EDX, 100000000000000000000B                				
  AND EDX, EAX                                   				
  CMP EDX, 100000000000000000000B                				
  JNE KONIEC_VM                                  				
;Ta czêœæ wykona siê, gdy bit VIP jest ustawiony
;Kasowanie bitu VIP:
  MOV EDX, 100000000000000000000B             				
  NOT EDX                                     				
  AND EAX, EDX                                				
;Ustawienie bitu VIF:
  OR EAX, 10000000000000000000B               				
  XCHG ESP, EBX                               				
  PUSH EAX              	;Zapis nowego obrazu EFLAGS
  MOV ESP, EBX           	;Przywrócenie szczytu stosu
;Wyprowadzenie informacji na ekranie o przeprowadzonych czynnoœciach:
  MOV AX, 8                                      				
  MOV DS, AX                                     				
  MOV BX, OFFSET TEKST_VME2                      				
  MOV DI, 1600                                   				
  PM_WYPISZ_TEKST                                				
  KONIEC_VM:                                           			
  RET                                                  			
VIRTUALNY_MONITOR ENDP
;Poni¿ej znajduje siê wspólna procedura obs³ugi wiêkszoœci wyj¹tków, powoduje ona przejœcie procesora w tryb real:
EXC_ 	PROC
  DB 66H
  DB 0EAH
  DW 0
  DW 48				
  IRETD    			
EXC_ ENDP

;Procedura obs³ugi wyj¹tku 13
EXC_13	PROC
  POP EAX   			;Odczyt ze stosu kodu b³êdu. 
  CZY_POTRZEBNY_MONITOR   	;Okreœlenie czy niezbêdne bêdzie wywo³anie wirtualnego monitora.	
  JE EXC_0_NIE_V           							
  MOV AX, 13              	;Przekazanie parametru dla wirtualnego monitora.
  CALL VIRTUALNY_MONITOR  	;Wywo³anie procedury wirtualnego monitora. 
  EXC_0_NIE_V:
  IRETD                                             			
EXC_13	ENDP

ZEGAR PROC
ZEGAR ENDP

;Procedura obs³ugi przerwania klawiatury:
KLAWIATURA PROC
  CZY_POTRZEBNY_MONITOR  	;Okreœlenie czy przerwanie nast¹pi³o w procesie
                                ;wykonuj¹cym siê w trybie wirtualnym.
  JE KLAWIATURA_NIE_V    				
  MOV AX, 33          		;Parametr dla wirtualnego monitora.	
  CALL VIRTUALNY_MONITOR  	;Wywo³anie wirtualnego monitora. 
  KLAWIATURA_NIE_V:
  IN AL,60h			;Pobranie numeru przyciœniêtego klawisza
  MOV DL,AL
  IN AL,61h			;Potwierdzenie pobrania numeru klawisza
  OR AL,80h
  OUT 61h,AL
  AND AL,7Fh
  OUT 61h,AL
  MOV AL,20h			;Sygna³ koñca obs³ugi przerwania
  OUT 20h,AL
  IRETD           
KLAWIATURA ENDP

INT_SIZE=$-BEGIN2
PRZERWANIA ENDS

KOD_REAL	SEGMENT 'CODE' USE16
ASSUME CS:KOD_REAL
BEGIN3	LABEL WORD
  JMP REAL_DALEJ           							
;Zmienne tablicowe przechowuj¹ce napisy informacyjne wypisywane na ekran w trybie wirtualnym:
  TXT_REAL DB 'TRYB V86, WYWOLANIE INSTRUKCJI CLI (PRZY IOPL < 3 !)     ', 0
  TXT_REAL2 DB 'WYWOLANIE INSTRUKCJI CLI PO UAKTYWNIENIU VIRTUALNYCH PRZERWAN', 0
  TXT_REAL3 DB 'WCISNIECIE DOWOLNEGO KLAWISZA SPOWODUJE USTAWIENIE PRZEZ MONITOR FLAGI VIP        ', 0
  TXT_REAL4 DB 'USTAWIENIE FLAGI VIF Z USTAWIONA VIP SPOWODUJE WYWOLANIE WYJATKU 13- #GP         ',0
  REAL_DALEJ:
;Wypisanie na ekran komunikatu spod zmiennej TXT_REAL:
  XOR DI, DI               							
  MOV SI, OFFSET TXT_REAL  							
  REAL_WYPISZ_TEKST       						
;W tej chwili system wirtualnych przerwañ nie jest dostêpny, wiêc wywo³anie poni¿szej instrukcji CLI spowoduje wyj¹tek:
  CLI                    	;Procedura obs³ugi wyj¹tku wywo³a wirtualny monitor, który 
                               	;ustawi bity VME i PVI w CR4		
;Wypisanie tekstu spod zmiennej TXT_REAL2:
  MOV DI, 640               							
  MOV SI, OFFSET TXT_REAL2  							
  REAL_WYPISZ_TEKST         						      
;W tej chwili system wirtualnych przerwañ jest uaktywniony, wywo³anie instrukcji CLI jest wiêc mo¿liwe
  CLI                        							
;Wypisanie tekstu spod zmiennej TXT_REAL3
  MOV DI, 960               							
  MOV SI, OFFSET TXT_REAL3  							
  REAL_WYPISZ_TEKST         						
;Poni¿sza pêtla bêdzie wykonywaæ siê do chwili, gdy zostanie przyciœniêty przycisk klawiatury (procedura 
;obs³ugi przerwania klawiatury ustawia flagê CF). nale¿y przypomnieæ o fakcie, ¿e pole VIF jest wyzerowane- 
;procedura obs³ugi przerwania klawiatury wywo³a wirtualny monitor, który ustawi flagê VIP aby zachowaæ 
;informacjê o tym, ¿e nast¹pi³o przerwanie.
  CLC                      							
  NIE_WCISNIETO_KLAWISZA:  						
  JNC NIE_WCISNIETO_KLAWISZA     						
;Wypisanie tekstu spod zmiennej TXT_REAL4:
  MOV DI, 1280                       						
  MOV SI, OFFSET TXT_REAL4           						
  REAL_WYPISZ_TEKST                  					
;Wywo³anie instukcji STI w sytuacji gdy jest wyzerowane pole VIF i ustawione VIP zaskutkuje 
;wygenerowaniem wyj¹tku 13, który wywo³a wirtualny monitor w celu obs³ugi zaistnia³ej sytuacji.
  STI                                						
;Procedura obs³ugi wyj¹tku dzielenia przez 0 prze³¹czy procesor w tryb real
  XOR DX, DX                           					
  DIV DX                               					
  V86_SIZE=$-BEGIN3
KOD_REAL ENDS

STK	SEGMENT STACK 'STACK'	;Dla programu g³ównego.
  DB 256 DUP (0)
STK	ENDS

STK_V86 SEGMENT         	;Dla v86
  DB 256 DUP (0)
STK_V86 ENDS

STK_INT SEGMENT         	;Dla procedur obs³ugi wyj¹tków (32-bitowy)
  DB 256 DUP (0)
STK_INT ENDS

END	MAIN

