.386P
INCLUDE STRUKT.TXT
DANE	SEGMENT USE16
	INCLUDE GDT.TXT
	GDT_SIZE = $ - GDT_NULL
	PDESKR	DQ 0
	TEKST	DB 'PRACA W TRYBIE CHRONIONYM !!!'
	ATRYBUT	DB 1EH
	INFO		DB 'POWROT Z TRYBU CHRONIONEGO $'
	DANE_SIZE = $ - GDT_NULL
DANE	ENDS

Program	SEGMENT USE16
	ASSUME CS:PROGRAM,DS:DANE
INCLUDE MAKRA.TXT
Start:
     INICJOWANIE_DESKRYPTOROW
     CLI
     AKTYWACJA_PM
     MOV AX,20h				;za�adowanie selektora	
     MOV ES,AX					;segmentu pami�ci obrazu 
  WYPISZ_N_ZNAKOW_Z_ATRYBUTEM TEKST, 29, 840, ATRYBUT		
  MIEKI_POWROT_RM
  POWROT_DO_RM 0,0			
PROGRAM_SIZE = $ - START			
PROGRAM ENDS		
			
STK     SEGMENT STACK 'STACK'
        DB 256 DUP (?)			
STK     ENDS
END START