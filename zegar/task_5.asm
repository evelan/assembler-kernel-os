.386P
INCLUDE STRUKT.TXT
DANE    SEGMENT USE16
;Tablica deskryptorów globalnych GDT
INCLUDE GDT.TXT
	GDT_HIMEM	DESKR <4095,0,20H,92H,80H,0>		;40
	GDT_TSS_0	DESKR <103,0,0,89H,0,0>			;48
	GDT_TSS_1	DESKR <103,0,0,89H,0,0>			;56
	GDT_SIZE = $ - GDT_NULL
;Tablica deskryptorów przerwañ IDT
	IDT	LABEL WORD
	INCLUDE PM_IDT.TXT
	IDT_0	TASK <0,56,0,85H,0>	;Przerwanie zegarowe (trap zadania)
;	IDT_1	TASK <0,56,0,85H,0>	;Przerwanie od klawiatury (nie u¿ywane)
	IDT_SIZE = $ - IDT
	PDESKR	DQ 	0
	ORG_IDT	DQ	0
	TSS_0	DB 104	DUP(0)
	TSS_1	DB 104	DUP(0)
	TEKST	DB 'TRYB CHRONIONY'
   INCLUDE PM_DATA.TXT
	INFO	DB 'POWROT Z TRYBU CHRONIONEGO $'
	TIME	DB 0
	KOLOR	DB 71H
	POZYCJA	DW 800
	POZYCJA1 DW 1600	
	DANE_SIZE = $ - GDT_NULL
DANE	ENDS

PROGRAM	SEGMENT 'CODE' USE16
        ASSUME CS:PROGRAM, DS:DANE
POCZ	LABEL WORD
INCLUDE PM_EXC.TXT
INCLUDE MAKRA.TXT
START:	
	INICJOWANIE_DESKRYPTOROW
	PM_TSS0_I_TSS1 TSS_0,TSS_1,GDT_TSS_0,GDT_TSS_1
	MOV WORD PTR TSS_1+4CH,16			;Wype³nienie pól segmentu
	MOV WORD PTR TSS_1+20H,OFFSET ZADANIE		;stanu zadania, wykonywanego
	MOV WORD PTR TSS_1+50H,24			;podczas obs³ugi przerwania
	MOV WORD PTR TSS_1+38H,128			;zegarowego
	MOV WORD PTR TSS_1+54H,8
	MOV WORD PTR TSS_1+48H,32
	MOV WORD PTR TSS_1+58H,40
	MOV WORD PTR TSS_1+5CH,40
	CLI						;Blokada przerwañ
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
   WYPISZ_N_ZNAKOW_Z_ATRYBUTEM TEKST,14,680,ATRYB
	STI				;Uaktywnienie przerwañ w trybie chronionym
	MOV AX,0ffffh			;W programie g³ównym wykonywana jest
   PTL2:	MOV CX,320		;pêtla powtarzana 65535 razy,
	MOV BX,3200			;która wyprowadza do 4-ch linii ekranu
   PTL1:	MOV DL,64		;(320 znaków) znak "@"
	MOV ES:[BX],DL			;Program ten jest wykonywany w czasie
	MOV DL,75h			;kilkudziesiêciu sekund
	MOV ES:[BX]+1,DL		;Podczas wykonywania programu g³ównego
	ADD BX,2			;obs³ugiwane s¹ przerwania zegarowe
	LOOP PTL1	
	SUB AX,1
	CMP AX,0
	JNZ PTL2
	CLI
	ETYKIETA_POWROTU_DO_RM:
	KONTROLER_PRZERWAN_RM
	MIEKI_POWROT_RM
	POWROT_DO_RM 0,1

ZADANIE PROC
	MOV BX,POZYCJA1	
	MOV AH,KOLOR	
	MOV AL,21H
	MOV ES:[BX],AX
	ADD BX,2
	MOV POZYCJA1,BX
	MOV AL,20H		;Sygna³ koñca obs³ugi przerwania
	OUT 20H,AL	
	IRETD
	JMP ZADANIE		;Skok do pocz¹tku procedury wykonywanej w zadaniu
ZADANIE	ENDP			;nr 1 (niezbêdne przy kolejnych przerwaniach)
PROGRAM_SIZE = $ - POCZ
PROGRAM	ENDS

STK	SEGMENT STACK 'STACK'
	DB 256 DUP(?)
STK	ENDS
END START

