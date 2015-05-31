.386P
INCLUDE STRUKT.TXT

DANE   	EQU 8
PROGRAM 	EQU 16
STOS_   	EQU 24
LINIOWY 	EQU 32
POWROT_ 	EQU 40

REAL16 SEGMENT USE16
ASSUME CS:REAL16,DS:REAL16
  GDT_NULL 		DESKR <0,0,0,0,0,0>					;0
  GDT_DANE 		DESKR <DANE_SIZE-1,0,0,10010010B,01000000B,0>		;8
  GDT_PROGRAM 		DESKR <PROGRAM_SIZE-1,0,0,10011010B,01000000B,0>	;16
  GDT_STOS 		DESKR <255,0,0,10010010B,01000000B,0>			;24
  GDT_ADRES_LINIOWY 	DESKR <0FFFFH,0,0,10010010B,11001111B,0>		;32
  GDT_DANE16		DESKR <0FFFFH,,,92H>					;40
  GDT_PROGRAM16		DESKR <0FFFFH,,,98H>					;48
  GDT_STOS16		DESKR <0FFFFH,0,0,92H,0,0>				;56
GDT_SIZE = $ - GDT_NULL

PDESKR	DQ 0
INFO 	DB 'Z POWROTEM TRYB REAL $'
A20	DB 0
FAST_A20	DB 0

INCLUDE A20.TXT

AKTYWACJA_PM MACRO	            				  	
  SMSW AX			;Prze³¹czenie procesora w tryb       		
  OR AX,1			;pracy chronionej.		            	
  LMSW AX
  DB 066H							           	          		
  DB 0EAH			;Skok odleg³y do etykiety 	           		
  DD OFFSET START2		;START2 oraz segmentu		
  DW 10H			;okreœlonego selektorem 10h.         		
  CONTINUE:
ENDM

POWROT_DO_RM MACRO	
 	MOV AX,REAL16		;Procesor pracuje w trybie Real.     	
     	MOV DS,AX		;Inicjalizacja rejestrów segmentowych.	           	
     	MOV AX,STK							           	
     	MOV SS,AX
   	A20_OFF
     	STI			;Odblokowanie przerwañ.	          	
	MOV AH,9		;Wydruk tekstu zapisane w zmiennej INFO. 	          	
	MOV DX,OFFSET INFO						           	
	INT 21H									
	MOV AX,4C00H		;Koniec pracy programu.	            
	INT 21H									            
ENDM

INICJOWANIE_DESKRYPTOROW16 MACRO
	MOV AX,REAL16									
	MOV DS,AX										
	MOV DL,0		;20-bitowy adres bazowy segmentu danych.	
	SHLD DX,AX,4					
	SHL AX,4					
	MOV BX,OFFSET GDT_DANE16 ;Wpisanie adresu bazowego segmentu danych do odpowiednich
	MOV [BX].BASE_1,AX	;pól deskryptora GDT_DANE.				
	MOV [BX].BASE_M,DL					
	MOV AX,REAL16									
	MOV DL,0								    	
	SHLD DX,AX,4					
	SHL AX,4					
	MOV BX,OFFSET GDT_PROGRAM16			
	MOV [BX].BASE_1,AX				
	MOV [BX].BASE_M,DL			
	MOV AX,STK					
	MOV DL,0								    	
	SHLD DX,AX,4					
	SHL AX,4					
	MOV BX,OFFSET GDT_STOS16			
	MOV [BX].BASE_1,AX				
	MOV [BX].BASE_M,DL				
	MOV BX,OFFSET GDT_DANE	
ENDM     

INICJOWANIE_DESKRYPTOROW32 MACRO
	MOV AX,PMODE32									
	MOV DL,0		;20-bitowy adres bazowy segmentu danych.	
	SHLD DX,AX,4					
	SHL AX,4					
	MOV BX,OFFSET GDT_DANE	;Wpisanie adresu bazowego segmentu danych do odpowiednich	
	MOV [BX].BASE_1,AX	;pól deskryptora GDT_DANE.				
	MOV [BX].BASE_M,DL					
	MOV AX,PMODE32									
	MOV DL,0								    	
	SHLD DX,AX,4					
	SHL AX,4					
	MOV BX,OFFSET GDT_PROGRAM			
	MOV [BX].BASE_1,AX				
	MOV [BX].BASE_M,DL			
	MOV AX,STK					
	MOV DL,0								    	
	SHLD DX,AX,4					
	SHL AX,4					
	MOV BX,OFFSET GDT_STOS			
	MOV [BX].BASE_1,AX				
	MOV [BX].BASE_M,DL				
	MOV BX,OFFSET GDT_DANE	
ENDM     

INICJOWANIE_GDTR MACRO
  	MOV BX,OFFSET GDT_DANE16;Przepisanie adresu bazowego 
	MOV AX,[BX].BASE_1				
	MOV WORD PTR PDESKR+2,AX			        	
	MOV DL,[BX].BASE_M				
	MOV BYTE PTR PDESKR+4,DL			
	MOV WORD PTR PDESKR,GDT_SIZE-1
 	LGDT PDESKR			;Za³adowanie rejestru GDTR.  
ENDM     

START:
  CZY_DOSTEPNY_FAST_A20
  A20_ON
;Inicjacja adresów bazowych poszczególnych deskryptorów:
  CLI
  MOV AX, REAL16	
  MOV DS,AX
  INICJOWANIE_DESKRYPTOROW16
  INICJOWANIE_DESKRYPTOROW32
  INICJOWANIE_GDTR
  AKTYWACJA_PM  
  RETURN:
  MOV AX, 40
  MOV DS, AX
  MOV ES, AX
  MOV FS, AX
  MOV GS, AX
  MOV AX, 56
  MOV SS, AX
  DB 0EAH
  DW OFFSET LADOWANIE_ODP_LIMITU
  DW 48
  LADOWANIE_ODP_LIMITU:
  MOV EAX, CR0
  AND EAX, 0FFFFFFFEH
  MOV CR0, EAX
  DB 0EAH
  DW OFFSET KONIEC
  DW REAL16
  KONIEC:
  POWROT_DO_RM
REAL16 ENDS

PMODE32 SEGMENT  USE32
ASSUME CS:PMODE32,DS:PMODE32
START2:
  MOV AX,08			;Za³adowanie selektora 	           		
     MOV DS,AX			;segmentu danych.                             		 
  MOV AX,18H			;Za³adowanie selektora	      	     	
     MOV SS,AX			;segmentu stosu.		           		
  MOV AX, LINIOWY
  MOV ES,AX
  MOV EDI, 0B8000H
  ADD EDI, 80*2*11
  MOV EAX, OFFSET TST
  MOV DL, [EAX]			;Adresowanie bazowe – baza w EAX.		
  MOV [ES:EDI], DL
  INC EAX
  MOV ECX, EAX
  MOV DL, [ECX]			;Adresowanie bazowe – baza w ECX.
  MOV [ES:EDI+2], DL
  MOV DL, [ECX+1]		;Adresowanie bazowe z przemieszczeniem.
  MOV [ES:EDI+4], DL
  MOV DL, [EAX+2]		;Adresowanie bazowe z przemieszczeniem.
  MOV [ES:EDI+6], DL
  MOV EBX, 1
  MOV DL, [EAX+EBX*2+1]		;Adresowanie skalowane bazowe z przemieszczeniem.
  MOV [ES:EDI+8], DL
  MOV EBX, 4
  MOV DL, [EAX+EBX]		;Adresowanie bazowo – indeksowe.
  MOV [ES:EDI+10], DL
  MOV DL, [EAX+EBX+1]		;Adresowanie bazowo – indeksowe z przemieszczeniem.
  MOV [ES:EDI+12], DL
  MOV EBX, 3
  MOV DL, [EAX+EBX*2]		;Adresowanie skalowane bazowe.
  MOV [ES:EDI+14], DL
  DB 066H
  DB 0EAH
  DW OFFSET RETURN
  DW 48
  HLT	

TST			 DB '12345678'
TEKST_PM           	 DB 'TRYB CHRONIONY', 0

DANE_SIZE = $ - START2
PROGRAM_SIZE = $ - START2
PMODE32 ENDS

STK     SEGMENT STACK 'STACK'
  DB 256 DUP (?)
STK     ENDS

END START

