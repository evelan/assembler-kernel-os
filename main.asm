.386P
INCLUDE STRUKT.TXT

DANE SEGMENT USE16
	GDT_NULL 	  DESKR <0,0,0,0,0,0>                 ;segment 0
	GDT_DANE 	  DESKR <DANE_SIZE-1,0,0,92H,0,0>     ;segment 8
	GDT_PROGRAM DESKR <PROGRAM_SIZE-1,0,0,98H,0,0>  ;segment 16
	GDT_STOS 	  DESKR <255,0,0,92H,0,0>             ;segment 24
	GDT_EKRAN 	DESKR <4095,8000H,0BH,92H,0,0>      ;segment 32
	GDT_TSS_0	  DESKR <103,0,0,89H,0,0>             ;segment 40
	GDT_TSS_1	  DESKR <103,0,0,89H,0,0>             ;segment 48
	GDT_SIZE = $ - GDT_NULL 
	
;Tablica deskryptorow przerwan IDT
	IDT	LABEL WORD
	INCLUDE   PM_IDT.TXT
  IDT_0	    INTR <PROC_0>	          ;Przerwanie zegarowe (trap zadania)
  IDT_1	    INTR <PROC_1>	      
	IDT_SIZE = $ - IDT
	PDESKR	  DQ 	0
	ORG_IDT	  DQ	0
	
	WELCOME   DB 'Architektura komputerow - Jakub Pomykala 209897'  
  TRYB_RM   DB 'POWROT Z TRYBU CHRONIONEGO $'
	
  INCLUDE   PM_DATA.TXT
  	
	TSS_0	    DB 104 DUP (0)
	TSS_1     DB 104 DUP (0)
	
	TASK0_OFFS DW 0
	TASK0_SEL  DW 40
	
	TASK1_OFFS DW 0
	TASK1_SEL  DW 48
	
	INFO_INR DB 'przerwanie'
	INFO_Z_1 DB '1'
	INFO_Z_2 DB '2'
	PUSTE    DB ' '
	
	POZYCJA_1       DW 320
	POZYCJA_2       DW 800;2560
	POZYCJA         DW 0	
	
	AKTYWNE_ZADANIE DW 1
	
	TIME	    DB    0
	KOLOR	    DB    71H
  
DANE_SIZE= $ - GDT_NULL
DANE ENDS

PROGRAM	SEGMENT 'CODE' USE16
        ASSUME CS:PROGRAM, DS:DANE, SS:STK ;informacja dla tasma jakie segmenty s¹ gdzie
POCZ LABEL WORD

INCLUDE PM_EXC.TXT
INCLUDE MAKRA.TXT

PROC_0	PROC


	PUSH AX
	PUSH BX

  CMP AKTYWNE_ZADANIE,0
  JE  TSK0

  CMP AKTYWNE_ZADANIE,1
  JE  TSK1
  
	MOV AL,20H
	OUT 20H,AL
	
	
	TSK0:	
  CALL DWORD PTR TASK0_OFFS	;PRZE£¥CZENIE ZADANIA
  ;MOV AKTYWNE_ZADANIE, 
	
	TSK1:
  CALL DWORD PTR TASK1_OFFS
  ;MOV AKTYWNE_ZADANIE, 0
	
	POP BX
	POP AX
	IRETD
PROC_0	ENDP

PROC_1	PROC
	
PROC_1	ENDP

START:	
	INICJOWANIE_DESKRYPTOROW
	
	;wywolowanie z MAKRA.TXT PM_TASKS
  PM_TASKS TSS_0,TSS_1,GDT_TSS_0,GDT_TSS_1
	
	;zadanie 1 ze stosem 128
	MOV WORD PTR TSS_1+4CH, 16              ;segment programu zadania CS  (SEGMENT PROGRAMU)
	MOV WORD PTR TSS_1+20H, OFFSET ZADANIE_1;adres powrotu IP             (SEGMENT 
	MOV WORD PTR TSS_1+50H, 24              ; SS                          (SEGMENT STOSU)
	MOV WORD PTR TSS_1+38H, 128             ; StackPointer                (SEGMENT wielkosc stosu)
	MOV WORD PTR TSS_1+54H, 8               ; ogólny segment danych DS    (SEGMENT DANYCH)
	MOV WORD PTR TSS_1+48H, 32              ; pamiec ekranu ES            (SEGMENT EKRANU)
	MOV WORD PTR TSS_1+58H, 32              ; pamiec rozszerzona
	MOV WORD PTR TSS_1+5CH, 32              ; pamiec rozszerzona 
	
	CLI
	INICJACJA_IDTR
	KONTROLER_PRZERWAN_PM 0FEH  ;1111 1110
	TRYB_CHRONIONY
	
	MOV AX,32
	MOV ES,AX
	MOV GS,AX
	MOV FS,AX
	MOV AX,40				;Za³adowanie rejestru zadania (TR)
	LTR AX					;deskryptorem segmentu stanu 
                  ;zadania nr 0 (program g³ówny)
  
  CZYSC_EKRAN              
  WYPISZ WELCOME,47,30,ATRYB
  
	STI				        ;Uaktywnienie przerwañ w trybie chronionym
	
	OPOZNIENIE 10000
OPOZNIENIE 10000
	OPOZNIENIE 10000
	CLI
	
	ETYKIETA_POWROTU_DO_RM:
	KONTROLER_PRZERWAN_RM
	MIEKI_POWROT_RM
	POWROT_DO_RM 0,1
	
ZADANIE_1	PROC
	MOV BX,POZYCJA_1	
	MOV AH,KOLOR	
	MOV AL,21H
	MOV ES:[BX],AX
	ADD BX,2
	MOV POZYCJA_1,BX
	MOV AL,20H		;Sygna³ koñca obs³ugi przerwania
	OUT 20H,AL	
	IRETD
	JMP ZADANIE_1		;Skok do pocz¹tku procedury wykonywanej w zadaniu
ZADANIE_1	ENDP 	

ZADANIE_2	PROC
	MOV BX,POZYCJA_2	
	MOV AH,KOLOR	
	MOV AL,21H
	MOV ES:[BX],AX
	ADD BX,2
	MOV POZYCJA_1,BX
	MOV AL,20H		;Sygna³ koñca obs³ugi przerwania
	OUT 20H,AL	
	IRETD
	JMP ZADANIE_1		;Skok do pocz¹tku procedury wykonywanej w zadaniu
ZADANIE_2	ENDP 


PROGRAM_SIZE= $ - POCZ
PROGRAM ENDS
STK	SEGMENT STACK 'STACK'
	DB 256*3 DUP(0)
STK	ENDS
END START