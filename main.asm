.386P

INCLUDE DEFSTR.TXT

DANE SEGMENT USE16
	GDT_NULL 	  DESKR <0,0,0,0,0,0>                 ;segment 0
	GDT_DANE 	  DESKR <DANE_SIZE-1,0,0,92H,0,0>     ;segment 8
	GDT_PROGRAM DESKR <PROGRAM_SIZE-1,0,0,98H,0,0>  ;segment 16
	GDT_STOS 	  DESKR <513,0,0,92H,0,0>             ;segment 24
	GDT_EKRAN 	DESKR <4095,8000H,0BH,92H,0,0>      ;segment 32
	GDT_TSS_0	  DESKR <103,0,0,89H,0,0>             ;segment 40
	GDT_TSS_1	  DESKR <103,0,0,89H,0,0>             ;segment 48
	GDT_TSS_2	  DESKR <103,0,0,89H,0,0>             ;segment 56
	GDT_MEM     DESKR <0FFFFh,0,40h,92h,00h,0>      ;segment 64
	GDT_SIZE = $ - GDT_NULL 
	
;Tablica deskryptorow przerwan IDT
	IDT	LABEL WORD
	INCLUDE           RODZPUL.TXT
	IDT_0	            INTR <PROC_0>
	IDT_SIZE = $ - IDT
	PDESKR	          DQ 	0
	ORG_IDT	          DQ	0
	
	WELCOME           DB 'Architektura komputerow - Jakub Pomykala 209897'  
  INFO	            DB 'POWROT Z TRYBU CHRONIONEGO $'
	
	INCLUDE           TXTPUL.TXT
	
	T0_ADDR	          DW 0,40  ;adresy zadan wg segmentow powyzej
	T1_ADDR	          DW 0,48
	T2_ADDR	          DW 0,56
	
	TSS_0	            DB 104 DUP (0)
	TSS_1	            DB 104 DUP (0)
	TSS_2	            DB 104 DUP (0)
	
	ZADANIE_1         DB '1'
	ZADANIE_2         DB '2'
	PUSTE             DB ' '
	AKTYWNE_ZADANIE   DW 0
	CZAS              DW 0
   
  A20               DB 0
	FAST_A20          DB 0
	
	POZYCJA_1         DW 320
	POZYCJA_2         DW 2560
	POZYCJA           DW 0	
  
DANE_SIZE= $ - GDT_NULL
DANE ENDS

PROGRAM	SEGMENT 'CODE' USE16
        ASSUME CS:PROGRAM, DS:DANE, SS:STK ;informacja dla TASMa jakie segmenty sa w ktorych rejestrach segmentowych
POCZ LABEL WORD

INCLUDE OBSLPUL.TXT
INCLUDE PODST.TXT
PROC_0	PROC

	PUSH  AX
	PUSH  DX

	CMP   AKTYWNE_ZADANIE,1	    ;czy AKTYWNE_ZADANIE == 1? 
	JE    ETYKIETA_ZADANIE_1    ;jesli tak to skaczemy do ETYKIETA_ZADANIE_1
	
	CMP   AKTYWNE_ZADANIE,0	    ;czy AKTYWNE_ZADANIE == 0?
	JE    ETYKIETA_ZADANIE_2    ;jesli tak to skaczemy do ETYKIETA_ZADANIE_2
	JMP   DALEJ
		
  ETYKIETA_ZADANIE_1:
  MOV AKTYWNE_ZADANIE, 0	
  JMP DWORD PTR T0_ADDR	       ;przelaczenie zadania na zadanie nr 1
	JMP DALEJ
  
  ETYKIETA_ZADANIE_2:
  MOV AKTYWNE_ZADANIE, 1
  JMP DWORD PTR T2_ADDR	       ;przelaczenie zadania na zadanie nr 2
  
  DALEJ:
  POP   DX
	POP   AX
	IRETD

PROC_0	ENDP

START:	
  CZY_DOSTEPNY_FAST_A20
	CLI
	
	WPISZ_DESKRYPTORY
	A20_ON
	
  PM_TASKS TSS_0,TSS_1,GDT_TSS_0,GDT_TSS_1
	XOR   EAX, EAX                
	MOV   AX, OFFSET TSS_2
	ADD   EAX, EBP
	MOV   BX, OFFSET GDT_TSS_2
	MOV   [BX].BASE_1, AX
	ROL   EAX, 16
	MOV   [BX].BASE_M, AL
	
	;zadanie 1 ze stosem 256
	MOV WORD PTR TSS_1+4CH, 16              ;CS (SEGMENT PROGRAMU)
	MOV WORD PTR TSS_1+20H, OFFSET ZADANIE1 ;IP (SEGMENT adresu powrotu)
	MOV WORD PTR TSS_1+50H, 24              ;SS (SEGMENT STOSU)
	MOV WORD PTR TSS_1+38H, 256             ;SP (SEGMENT wielkosc stosu)
	MOV WORD PTR TSS_1+54H, 8               ;DS (SEGMENT DANYCH)
	MOV WORD PTR TSS_1+48H, 32              ;ES (SEGMENT EKRANU)
	
	STI		                  ;ustawienie znacznika zestawienia na przerwanie
	PUSHFD		              ;przeslanie znacznikow na szczyt stosu, przepisanie rejestru eflags do eax
	POP EAX
	
	MOV DWORD PTR TSS_1+24H, EAX            ;zapisujemy eeflags 
	
	;zadanie 2 ze stostem 256
	MOV WORD PTR TSS_2+4CH, 16		          ;CS (SEGMENT PROGRAMU)
	MOV WORD PTR TSS_2+20H, OFFSET ZADANIE2 ;IP (SEGMENT adresu powrotu)
	MOV WORD PTR TSS_2+50H, 24		          ;SS (SEGMENT STOSU)
	MOV WORD PTR TSS_2+38H, 256             ;SP (SEGMENT wielkosc stosu)
	MOV WORD PTR TSS_2+54H, 8               ;DS (SEGMENT DANYCH)
	MOV WORD PTR TSS_2+48H, 32              ;ES (SEGMENT EKRANU)
	
	MOV DWORD PTR TSS_2+24H, EAX

	CLI                                     ;blokujemy przerwania
	WPISZ_IDTR                              ;zapisujemy tablice deskryptorow przerwan 
	KONTROLER_PRZERWAN 0FEH                 ;konfigurujemy kontroler przerwan do obslugi czasomierza
	TRYB_CHRONIONY                          ;przechodzimy w tryb chroniony
	
	MOV AX, 32
	MOV ES, AX
	MOV GS, AX
	MOV FS, AX
	MOV AX, 40		;Zaladowanie rejestru zadania (TR)
	LTR AX				;deskryptorem segmentu stanu 

  CZYSC_EKRAN
  OPOZNIENIE 100
  WYPISZ WELCOME,47,30,ATRYB
  
  STI         ;zezwalamy na przerwania
  
;zadanie ktore wypisuje jedynki na ekranie                              
ZADANIE1 PROC
ZADANIE_1_PETLA:
  MOV AL, ZADANIE_1
	MOV BX, POZYCJA_1
	MOV AH, 02h	
	MOV ES:[BX], AX
	
	INT 2                       ;wywolanie przerwania z informacja o aktualnym zadaniu 
	OPOZNIENIE 200

 	ADD POZYCJA_1, 2
  
	MOV   AL, 20H	              ;sygnal konca obslugi przerwania
	OUT   20H, AL

	JMP ZADANIE_1_PETLA	
ZADANIE1 ENDP

;zadanie ktore wypisuje dwojki na ekranie
ZADANIE2 PROC
ZADANIE_2_PETLA:
  MOV AL, ZADANIE_2         
	MOV BX, POZYCJA_2
	MOV AH, 02h
	MOV ES:[BX], AX
	
	INT 3                       ;wywolanie przerwania z informacja o aktualnym zadaniu 
	OPOZNIENIE 300
	
 	ADD POZYCJA_2, 2	
 	  
	MOV   AL, 20H	              ;sygnal konca obslugi przerwania
	OUT   20H, AL
 	
	JMP ZADANIE_2_PETLA
ZADANIE2 ENDP

PROGRAM_SIZE= $ - POCZ
PROGRAM ENDS
STK	SEGMENT STACK 'STACK'
	DB 256*3 DUP(0)
STK	ENDS
END START