.386P
INCLUDE STRUKT.TXT

DANE SEGMENT USE16
	GDT_NULL 	  DESKR <0,0,0,0,0,0>                 ;segment 0
	GDT_DANE 	  DESKR <DANE_SIZE-1,0,0,92H,0,0>     ;segment 8
	GDT_PROGRAM DESKR <PROGRAM_SIZE-1,0,0,98H,0,0>  ;segment 16
	GDT_STOS 	  DESKR <255,0,0,92H,0,0>             ;segment 24
	GDT_EKRAN 	DESKR <4095,8000H,0BH,92H,0,0>      ;segment 32
	GDT_HIMEM	  DESKR <4095,0,20H,92H,80H,0>        ;segment 40
	GDT_TSS_0	  DESKR <103,0,0,89H,0,0>             ;segment 48
	GDT_TSS_1	  DESKR <103,0,0,89H,0,0>             ;segment 56
	GDT_SIZE = $ - GDT_NULL 
	
;Tablica deskryptorow przerwan IDT
	IDT	LABEL WORD
	INCLUDE   PM_IDT.TXT
  IDT_0	    TASK <0,56,0,85H,0>	          ;Przerwanie zegarowe (trap zadania)
  IDT_1	    TASK <0,56,0,85H,0>	 
	IDT_SIZE = $ - IDT
	PDESKR	  DQ 	0
	ORG_IDT	  DQ	0
	
	WELCOME   DB 'Architektura komputerow - Jakub Pomykala 209897'  
  TRYB_RM   DB 'POWROT Z TRYBU CHRONIONEGO $'
	
  INCLUDE   PM_DATA.TXT
  	
	TSS_0	    DB 104 DUP (0)
	TSS_1     DB 104 DUP(0)
	
	INFO_Z_1 DB '1'
	INFO_Z_2 DB '2'
	PUSTE     DB ' '
	
	POZYCJA_1       DW 320
	POZYCJA_2       DW 2560
	POZYCJA         DW 0	
	
	;TIME	    DB    0
	KOLOR	    DB    71H
  
DANE_SIZE= $ - GDT_NULL
DANE ENDS

PROGRAM	SEGMENT 'CODE' USE16
        ASSUME CS:PROGRAM, DS:DANE, SS:STK ;informacja dla tasma jakie segmenty s¹ gdzie
POCZ LABEL WORD

INCLUDE PM_EXC.TXT
INCLUDE MAKRA.TXT

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
	MOV WORD PTR TSS_1+58H, 40              ; pamiec rozszerzona
	MOV WORD PTR TSS_1+5CH, 40              ; pamiec rozszerzona 
	
	CLI
	INICJACJA_IDTR
	KONTROLER_PRZERWAN_PM 0FEH
	AKTYWACJA_PM
	
	MOV AX,32
	MOV ES,AX
	MOV AX,40
	MOV GS,AX
	MOV FS,AX
	MOV AX,48				;Za³adowanie rejestru zadania (TR)
	LTR AX					;deskryptorem segmentu stanu 
                  ;zadania nr 0 (program g³ówny)
  
  CZYSC_EKRAN              
  WYPISZ WELCOME,47,30,ATRYB
  
	STI				        ;Uaktywnienie przerwañ w trybie chronionym
	MOV AX,0ffffh			;W programie g³ównym wykonywana jest
  
  PTL2:	
  MOV CX,320	      ;pêtla powtarzana 65535 razy,
	MOV BX,3200			  ;która wyprowadza do 4-ch linii ekranu
  
  PTL1:
  MOV DL,INFO_Z_1	      	;(320 znaków) znak "@"
	MOV ES:[BX],DL		;Program ten jest wykonywany w czasie
	MOV DL,75h		    ;kilkudziesiêciu sekund
	MOV ES:[BX]+1,DL	;Podczas wykonywania programu g³ównego
	ADD BX,2			    ;obs³ugiwane s¹ przerwania zegarowe
	
	LOOP PTL1	
	SUB AX,1
	CMP AX,0
	JNZ PTL2
	
	CLI
	
	OPOZNIENIE 1000
	
	ETYKIETA_POWROTU_DO_RM:
	KONTROLER_PRZERWAN_RM
	MIEKI_POWROT_RM
	POWROT_DO_RM 0,1
	
ZADANIE_1 PROC

  OPOZNIENIE 100

	MOV BX,POZYCJA_1	
	MOV AH,KOLOR	
	MOV AL,INFO_Z_2	
	MOV ES:[BX],AX
	ADD BX,2
	MOV POZYCJA_1,BX
	MOV AL,20H	    	;Sygna³ koñca obs³ugi przerwania
	OUT 20H,AL	
	IRETD
	JMP ZADANIE_1		    ;Skok do pocz¹tku procedury wykonywanej w zadaniu
ZADANIE_1	ENDP		  	;nr 1 (niezbêdne przy kolejnych przerwaniach)


ZADANIE_2 PROC
  INT 3
	MOV BX,POZYCJA_2	
	MOV AH,KOLOR	
	MOV AL,INFO_Z_2
	MOV ES:[BX],AX
	ADD BX,2
	MOV POZYCJA_1,BX
	MOV AL,20H	    	;Sygna³ koñca obs³ugi przerwania
	OUT 20H,AL	
	IRETD
	JMP ZADANIE_2		    ;Skok do pocz¹tku procedury wykonywanej w zadaniu
ZADANIE_2	ENDP		  	


PROGRAM_SIZE= $ - POCZ
PROGRAM ENDS
STK	SEGMENT STACK 'STACK'
	DB 256*3 DUP(0)
STK	ENDS
END START