.386P
INCLUDE STRUKT.TXT

DANE SEGMENT USE16
	GDT_NULL 	  DESKR <0,0,0,0,0,0>                 ;segment 0
	GDT_DANE 	  DESKR <DANE_SIZE-1,0,0,92H,0,0>     ;segment 8
	GDT_PROGRAM DESKR <PROGRAM_SIZE-1,0,0,98H,0,0>  ;segment 16
	GDT_STOS 	  DESKR <513,0,0,92H,0,0>             ;segment 24
	GDT_EKRAN 	DESKR <4095,8000H,0BH,92H,0,0>      ;segment 32
	GDT_TSS_0	  DESKR <103,0,0,89H,0,0>             ;segment 40
	GDT_TSS_1	  DESKR <103,0,0,89H,0,0>             ;segment 48
	GDT_TSS_2	  DESKR <103,0,0,89H,0,0>             ;segment 56
	GDT_SIZE = $ - GDT_NULL 
	
;Tablica deskryptorow przerwan IDT
	IDT	LABEL WORD
	INCLUDE   PM_IDT.TXT
	IDT_0	    INTR <PROC_0>
	IDT_1	    INTR <PROC_1>
	IDT_SIZE = $ - IDT
	PDESKR	  DQ 	0
	ORG_IDT	  DQ	0
	
	WELCOME   DB 'Architektura komputerow - Jakub Pomykala 209897'  
	INFO_RM   DB 'Powrot do trybu rzeczywistego' ;(29)
  INFO	    DB 'POWROT Z TRYBU CHRONIONEGO $'
	
  INCLUDE   PM_DATA.TXT
	
	T0_ADDR	  DW 0,40  ;adresy zadan wg segmentow powyzej
	T1_ADDR	  DW 0,48
	T2_ADDR	  DW 0,56
	
	TSS_0	    DB 104 DUP (0)
	TSS_1	    DB 104 DUP (0)
	TSS_2	    DB 104 DUP (0)
	
	ZADANIE_1 DB '1'
	ZADANIE_2 DB '2'
	PUSTE     DB ' '
	AKTYWNE_ZADANIE DW 0
	CZAS      DW 0
	
	POZYCJA_1       DW 320
	POZYCJA_2       DW 2560
	POZYCJA         DW 0	
  
DANE_SIZE= $ - GDT_NULL
DANE ENDS

PROGRAM	SEGMENT 'CODE' USE16
        ASSUME CS:PROGRAM, DS:DANE, SS:STK ;informacja dla tasma jakie segmenty s¹ gdzie
POCZ LABEL WORD

INCLUDE PM_EXC.TXT
INCLUDE MAKRA.TXT
PROC_0	PROC

	PUSH  AX
	PUSH  DX

	MOV   AL,20H	;Sygnal konca obslugi przerwania
	OUT   20H,AL

	
	CMP   AKTYWNE_ZADANIE,1	    ;wcisniecie klawisza '1' na klawiaturze -> zadanie nr i wypisywanie jedynek
	JE    TSK0
	
	CMP   AKTYWNE_ZADANIE,0	    ;wcisniecie klawisza '2' -> zadanie nr 2 i wypisywanie dwojek
	JE    TSK2
	JMP   OUT_P1
		
  TSK0:
  MOV AKTYWNE_ZADANIE, 0	
  JMP DWORD PTR T0_ADDR	;jedynki
	JMP OUT_P1
  
  TSK2:
  MOV AKTYWNE_ZADANIE, 1
  JMP DWORD PTR T2_ADDR	;Przelaczenie zadania na zadanie nr 2
  
  OUT_P1:
  POP   DX
	POP   AX
	IRETD

PROC_0	ENDP

;Procedura obslugi przerwania od klawiatury (przerwanie nr 1)
PROC_1	PROC
	
	IRETD
PROC_1	ENDP

START:	
	INICJOWANIE_DESKRYPTOROW
	
	;wywolowanie z MAKRA.TXT PM_TASKS
  PM_TASKS TSS_0,TSS_1,GDT_TSS_0,GDT_TSS_1
	XOR   EAX, EAX         ;czyszczenie smieci 
	MOV   AX, OFFSET TSS_2
	ADD   EAX, EBP
	MOV   BX, OFFSET GDT_TSS_2
	MOV   [BX].BASE_1, AX
	ROL   EAX, 16
	MOV   [BX].BASE_M, AL
	
	;zadanie 1 ze stosem 512
	MOV WORD PTR TSS_1+4CH, 16              ;segment programu zadania CS  (SEGMENT PROGRAMU)
	MOV WORD PTR TSS_1+20H, OFFSET ZADANIE1 ;adres powrotu IP             (SEGMENT 
	MOV WORD PTR TSS_1+50H, 24              ; SS                          (SEGMENT STOSU)
	MOV WORD PTR TSS_1+38H, 256             ; StackPointer                (SEGMENT wielkosc stosu)
	MOV WORD PTR TSS_1+54H, 8               ; ogólny segment danych DS    (SEGMENT DANYCH)
	MOV WORD PTR TSS_1+48H, 32              ; pamiec ekranu ES            (SEGMENT EKRANU)
	
	;bez wykorzystywania lokalnej tablicy deskryptorow
	;jesli lokalna to musze ja wpisac pod 60h
	
	STI		                  ;ustawienie znacznika zestawienia na przerwanie
	PUSHFD		              ;przeslanie znacznikow na szczyt stosu, przepisanie rejestru eflags do eax
	POP EAX
	
	MOV DWORD PTR TSS_1+24H, EAX ;eeflags 
	;28h - 47h - adresy wszystkich rejestrow roboczych 
	
	;zadanie 2 ze stostem 512
	MOV WORD PTR TSS_2+4CH, 16		
	MOV WORD PTR TSS_2+20H, OFFSET ZADANIE2
	MOV WORD PTR TSS_2+50H, 24		
	MOV WORD PTR TSS_2+38H, 256
	MOV WORD PTR TSS_2+54H, 8
	MOV WORD PTR TSS_2+48H, 32
	
	MOV DWORD PTR TSS_2+24H, EAX

	CLI
	INICJACJA_IDTR
	KONTROLER_PRZERWAN_PM 0FCH
	AKTYWACJA_PM
	
	MOV AX, 32
	MOV ES, AX
	MOV GS, AX
	MOV FS, AX
	MOV AX, 40		;Zaladowanie rejestru zadania (TR)
	LTR AX				;deskryptorem segmentu stanu 

  ;czyszczenie ekranu
  CZYSC_EKRAN
  OPOZNIENIE 100
  
  WYPISZ WELCOME,47,30,ATRYB
  
  STI ; zezwalamy na przerwania
    
			                                    

ZADANIE1 PROC
;wypisywanie jedynek i wyjatek dzielenia przez zero
ZADANIE_1_PETLA:
  MOV AL, ZADANIE_1
	MOV BX, POZYCJA_1
	MOV AH, 02h	
	MOV ES:[BX],AX
	
	OPOZNIENIE 50
 	
 	ADD POZYCJA_1, 2

	JMP ZADANIE_1_PETLA	
ZADANIE1 ENDP

ZADANIE2 PROC
ZADANIE_2_PETLA:
  MOV AL, ZADANIE_2
	MOV BX, POZYCJA_2
	MOV AH, 02h
	MOV ES:[BX],AX
	OPOZNIENIE 50
 	ADD POZYCJA_2, 2	
	JMP ZADANIE_2_PETLA
ZADANIE2 ENDP

PROGRAM_SIZE= $ - POCZ
PROGRAM ENDS
STK	SEGMENT STACK 'STACK'
	DB 256*3 DUP(0)
STK	ENDS
END START