.386P
INCLUDE STRUKT.TXT
DANE    SEGMENT USE16
;Tablica deskryptorów globalnych GDT
	INCLUDE GDT.TXT
	GDT_TSS_0	DESKR <103,0,0,89H,0,0>			;40
	GDT_TSS_1	DESKR <103,0,0,89H,0,0>			;48
	GDT_SIZE = $ - GDT_NULL
;Tablica deskryptorów przerwañ IDT
	IDT	LABEL WORD
	INCLUDE PM_IDT.TXT
	IDT_0	INTR <PROC_0>
	IDT_1	INTR <PROC_1>
;	IDT_2	INTR <EXC_>
	IDT_SIZE = $ - IDT
	PDESKR	DQ 	0
	ORG_IDT	DQ	0
	TEKST	DB 'TRYB CHRONIONY'
   TEKST1	DB 'PRZERWANIE'
   INCLUDE PM_DATA.TXT
	INFO	DB 'POWROT Z TRYBU CHRONIONEGO $'
	TIME	DB 0
	KOLOR	DB 71H
	POZYCJA	DW 800
	POZYCJA1 DW 1600
	TSS_0	DB 104 DUP(0)
	TSS_1	DB 104 DUP(0)
	TASK1_OFFS DW 0
	TASK1_SEL  DW 48
	DANE_SIZE = $ - GDT_NULL
DANE	ENDS

PROGRAM	SEGMENT 'CODE' USE16
        ASSUME CS:PROGRAM, DS:DANE, SS:STK
POCZ	LABEL WORD
INCLUDE PM_EXC.TXT
INCLUDE MAKRA.TXT
;Procedura obs³ugi przerwania zegarowego (przerwanie nr 0)
PROC_0	PROC
	PUSH AX
	PUSH BX
;	MOV AL,'#'
;	MOV ES:[2000],AL
	CALL DWORD PTR TASK1_OFFS	;PRZE£¥CZENIE ZADANIA
;	MOV AL,'#'
;	MOV ES:[2002],AL
	MOV AL,20H
	OUT 20H,AL
	POP BX
	POP AX
	IRETD
PROC_0	ENDP
;Procedura obs³ugi przerwania od klawiatury (przerwanie nr 1)
PROC_1	PROC
	PUSH AX
	PUSH BX
	IN AL,60H	;Pobranie numeru przyciœniêtego oraz zwolnionego
	ADD AL,47	;klawisza, a tak¿e wyprowadzenie na znaku ekran 
	MOV BX,POZYCJA1	;Do numeru klawisza dodana zostaje liczba 47
	MOV AH,KOLOR	;co dla klawiszy cyfr (numery od 1..9)
	MOV ES:[BX],AX	;daje kod ASCII cyfr
	CMP AL,80H
	JB MAKE
	ADD POZYCJA1,2
   MAKE:	ADD POZYCJA1,2
	IN AL,61H
	OR AL,80H
	OUT 61H,AL
	AND AL,7FH
	OUT 61H,AL
	MOV AL,20H
	OUT 20H,AL
	POP BX
	POP AX
	IRETD
PROC_1	ENDP

START:	
	INICJOWANIE_DESKRYPTOROW
	PM_TSS0_I_TSS1 TSS_0,TSS_1,GDT_TSS_0,GDT_TSS_1
	MOV WORD PTR TSS_1+4CH,16	;Wype³nienie pól segmentu
	MOV WORD PTR TSS_1+20H,OFFSET ZADANIE;stanu zadania, wykonywanego
	MOV WORD PTR TSS_1+50H,24	;podczas obs³ugi przerwania
	MOV WORD PTR TSS_1+38H,128	;zegarowego
	MOV WORD PTR TSS_1+54H,8
	MOV WORD PTR TSS_1+48H,32
	MOV WORD PTR TSS_1+58H,32
	MOV WORD PTR TSS_1+5CH,32
	CLI
	INICJACJA_IDTR
	KONTROLER_PRZERWAN_PM	0FCH
	AKTYWACJA_PM
	MOV AX,32
	MOV ES,AX
	MOV GS,AX
	MOV FS,AX
	MOV AX,40			;Za³adowanie rejestru zadania (TR)
	LTR AX				;deskryptorem segmentu stanu 
   WYPISZ_N_ZNAKOW_Z_ATRYBUTEM TEKST,14,680,ATRYB
	STI				;Uaktywnienie przerwañ w trybie chronionym
	MOV AX,0FFFFH			;W programie g³ównym wykonywana jest
   PTL2:	MOV CX,320		;pêtla powtarzana 65535 razy,
	MOV BX,3200			;która wyprowadza do 4-ch linii ekranu
   PTL1:	MOV DL,64		;(320 znaków) znak "@"
	MOV ES:[BX],DL			;Program ten jest wykonywany w czasie
	MOV DL,75H			;kilkudziesiêciu sekund
	MOV ES:[BX]+1,DL		;Podczas wykonywania programu g³ównego
	ADD BX,2			;obs³ugiwane s¹ przerwania zegarowe,
	LOOP PTL1			;oraz przerwania od klawiatury
	SUB AX,1
	CMP AX,0
	JNZ PTL2
	CLI
	ETYKIETA_POWROTU_DO_RM:
	KONTROLER_PRZERWAN_RM
	MIEKI_POWROT_RM
	POWROT_DO_RM 0,1

ZADANIE	PROC
	MOV AL,21H	
	MOV AH,KOLOR		
	MOV BX,POZYCJA		
	MOV ES:[BX],AX
	ADD POZYCJA,2
	IRETD
	JMP ZADANIE
ZADANIE	ENDP
PROGRAM_SIZE = $ - POCZ
PROGRAM	ENDS

STK	SEGMENT STACK 'STACK'
	DB 256 DUP(?)
STK	ENDS
END START

