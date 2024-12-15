;***********************************************************
;* Lab 7 ECE 375
;***********************************************************
;*
;* Author: Sairishabh Anand and Trent Matsumura
;* Date: 3/13/2024
;*
;***********************************************************

.include "m32U4def.inc"         ; Include definition file

;***********************************************************
;* Internal Register Definitions and Constants
;***********************************************************
.def    mpr = r16               ; Multi-Purpose Register
.def    ilcnt = r18             ; Internal loop counter
.def    olcnt = r19             ; Outer loop counter
.def    zero = r2               ; Zero register
.def    userChoice = r17        ; Register to store user choice
.def    tmrcnt = r15            ; Timer counter register
.def    button = r13            ; Button state register
.def    oldbut = r14            ; Previous button state register

.equ    SendReady = 0b11111111  ; Define value for sending readiness
.equ    lcd1L = 0x00            ; Lower byte for LCD line 1 address
.equ    lcd1H = 0x01            ; Higher byte for LCD line 1 address
.equ    lcd2L = 0x10            ; Lower byte for LCD line 2 address
.equ    lcd2H = 0x01            ; Higher byte for LCD line 2 address

;***********************************************************
;* Start of Code Segment
;***********************************************************
.cseg                           ; Beginning of code segment

;***********************************************************
;* Interrupt Vectors
;***********************************************************
.org    $0000                   ; Beginning of IVs
        rjmp    INIT            ; Reset interrupt

.org    $0056                   ; End of Interrupt Vectors

;***********************************************************
;* Program Initialization
;***********************************************************
INIT:
    clr     zero
    clr     userChoice
    clr     tmrcnt

    ; Initialize the Stack Pointer
    ldi     mpr, low(RAMEND)
    out     SPL, mpr
    ldi     mpr, high(RAMEND)
    out     SPH, mpr

    ; Initialize Port B for output
    ldi     mpr, $F0
    out     DDRB, mpr
    ldi     mpr, $00
    out     PORTB, mpr

    ; Initialize Port D for input
    ldi     mpr, $00
    out     DDRD, mpr
    ldi     mpr, $FF
    out     PORTD, mpr

    ; Initialize the LCD
    rcall LCDInit
    rcall LCDBacklightOn
    rcall LCDClr

    ; Initialize USART1
    ldi mpr, 0b00000001
    sts UBRR1H, mpr
    ldi mpr, 0b10100001
    sts UBRR1L, mpr
    ldi mpr, 0b0_00_1_1_0_00
    sts UCSR1B, mpr
    ldi mpr, 0b00_00_1_11_0
    sts UCSR1C, mpr

    ; Initialize Timer/Counter1
    ldi mpr, 0b00_00_00_00
    sts TCCR1A, mpr
    ldi mpr, 0b000_00_100
    sts TCCR1B, mpr

    ; Load text data from program memory to data memory
    ldi ZH, high(STRING1)
    ldi ZL, low(STRING1)
    lsl ZH
    lsl ZL
    adc ZH, zero
    ldi YH, high(welcome)

    ; Define the length of the welcome string
    ldi ilcnt, 176

    ; Loop to load welcome string from program memory to data memory
LOADLOOP:
    lpm mpr, Z+     ; Load program memory byte to mpr and post-increment Z pointer
    st Y+, mpr      ; Store mpr to Y and post-increment Y pointer
    dec ilcnt       ; Decrement inner loop counter
    cp ilcnt, zero ; Compare inner loop counter with zero
    brne LOADLOOP   ; Branch to LOADLOOP if inner loop counter is not zero
    
    rjmp    MAIN    ; Jump to MAIN

;***********************************************************
;* Main Program
;***********************************************************
MAIN:
    ldi ilcnt, 0
    ldi olcnt, 1
    rcall WRITESCREEN

MAIN2:
    sbic PIND, 7    ; Skip if PD7 is not pressed
    rjmp MAIN2      ; If PD7 is not pressed, keep waiting
    clr mpr
    clr olcnt       ; Clear outer loop counter

    ldi mpr, $FF    ; Load mpr with a value for transmission
    rcall USART_TX  ; Transmit mpr value
    ldi ilcnt, 2    ; Load inner loop counter
    ldi olcnt, 3    ; Load outer loop counter
    rcall WRITESCREEN  ; Update LCD screen
    rcall USART_RX  ; Receive data from USART
    cpi mpr, $FF    ; Compare received data with a specific value
    brne MAIN       ; If received data is not equal to a specific value, restart the game
    rcall GAMESTART    ; Start the game
    rjmp    MAIN    ; Restart the game

;***********************************************************
;* Functions and Subroutines
;***********************************************************

USART_TX: 
    push mpr        ; Push mpr onto the stack
    lds mpr, UCSR1A    ; Load status register of USART
    sbrs mpr,UDRE1  ; Skip if data register of USART is not empty
    rjmp USART_TX   ; If data register is not empty, keep waiting
    pop mpr         ; Pop mpr from the stack
    sts UDR1, mpr   ; Store mpr value into data register of USART
    ret             ; Return from subroutine

USART_RX:
    lds mpr, UCSR1A    ; Load status register of USART
    sbrs mpr, RXC1     ; Skip if receive complete flag is not set
    rjmp USART_RX      ; If receive complete flag is not set, keep waiting
    lds mpr, UDR1      ; Load data from data register of USART
    ret                 ; Return from subroutine

GAMESTART:
    ldi olcnt, $FF  ; Load outer loop counter
    ldi ilcnt, 4    ; Load inner loop counter
    rcall WRITESCREEN  ; Update LCD screen

    rcall STARTTIMER    ; Start timer
    clr userChoice      ; Clear user choice
    inc userChoice     ; Increment user choice by 1
    inc userChoice     ; Increment user choice by 1
    ldi mpr, 0b11110000    ; Load mpr with a value for PORTB
    mov tmrcnt, mpr        ; Move mpr to tmrcnt
    out PORTB, mpr         ; Output mpr to PORTB
    clr oldbut             ; Clear old button state

GAMELOOP:
    sbis TIFR1, TOV1       ; Skip if timer overflow flag is not set
    rjmp NOTIMER            ; If timer overflow flag is not set, skip
        lsl tmrcnt              ; Left shift tmrcnt
        mov mpr, tmrcnt         ; Move tmrcnt to mpr
        out PORTB, mpr          ; Output mpr to PORTB
        cpi mpr, 0              ; Compare mpr with 0
        breq GAMESTART2         ; If mpr is 0, go to GAMESTART2
        rcall STARTTIMER        ; Start timer again
    NOTIMER:

    mov mpr, oldbut        ; Move old button state to mpr
    cpi mpr, 0             ; Compare mpr with 0
    brne ALREADYPRESSED    ; If mpr is not 0, go to ALREADYPRESSED
    sbic PIND, 4           ; Skip if PD4 is not pressed
    rjmp ALREADYPRESSED    ; If PD4 is not pressed, go to ALREADYPRESSED
        ldi mpr, 1          ; Load mpr with 1
        mov oldbut, mpr     ; Move mpr to oldbut
        inc userChoice      ; Increment user choice
        cpi userChoice, 3  ; Compare user choice with 3
        brne BUTSKIP        ; If user choice is not 3, skip
            clr userChoice  ; Clear user choice
        BUTSKIP:

        ldi ilcnt, 4        ; Load inner loop counter
        ldi olcnt, 5        ; Load outer loop counter
        add olcnt, userChoice   ; Add user choice to outer loop counter
        rcall WRITESCREEN   ; Update LCD screen
    ALREADYPRESSED:
    rcall SMALLWAIT        ; Call SMALLWAIT subroutine
    sbic PIND, 4           ; Skip if PD4 is not pressed
    clr oldbut             ; If PD4 is not pressed, clear old button state
    rjmp GAMELOOP          ; Go to GAMELOOP

GAMESTART2:
    mov mpr, userChoice    ; Move user choice to mpr
    rcall USART_TX         ; Transmit user choice via USART
    rcall USART_RX         ; Receive opponent's choice via USART
    push mpr               ; Push mpr onto the stack
    ldi olcnt, 5           ; Load outer loop counter
    add olcnt, userChoice  ; Add user choice to outer loop counter
    ldi ilcnt, 5           ; Load inner loop counter
    add ilcnt, mpr         ; Add mpr to inner loop counter
    rcall WRITESCREEN      ; Update LCD screen
    rcall STARTTIMER       ; Start timer
    ldi mpr, 0b11110000    ; Load mpr with a value for PORTB
    mov tmrcnt, mpr        ; Move mpr to tmrcnt
    out PORTB, mpr         ; Output mpr to PORTB
    rjmp GAMELOOP2         ; Go to GAMELOOP2

GAMELOOP2:
    sbis TIFR1, TOV1       ; Skip if timer overflow flag is not set
    rjmp NOTIMER2           ; If timer overflow flag is not set, skip
        lsl tmrcnt              ; Left shift tmrcnt
        mov mpr, tmrcnt         ; Move tmrcnt to mpr
        out PORTB, mpr          ; Output mpr to PORTB
        cpi mpr, 0              ; Compare mpr with 0
        breq GAMEEND            ; If mpr is 0, go to GAMEEND
        rcall STARTTIMER        ; Start timer again
    NOTIMER2:
    rjmp  GAMELOOP2            ; Go to GAMELOOP2

GAMEEND:
    pop mpr                 ; Pop mpr from the stack
    cp userChoice, mpr      ; Compare user choice with mpr
    breq uDraw              ; If user choice is equal to mpr, go to uDraw

    lsl mpr                 ; Left shift mpr
    add userChoice, mpr     ; Add mpr to user choice
    cpi userChoice, 1       ; Compare user choice with 1
    breq uWin               ; If user choice is equal to 1, go to uWin
    cpi userChoice, 2       ; Compare user choice with 2
    breq theyWin            ; If user choice is equal to 2, go to theyWin
    cpi userChoice, 4       ; Compare user choice with 4
    breq uWin               ; If user choice is equal to 4, go to uWin
    cpi userChoice, 5       ; Compare user choice with 5
    breq theyWin            ; If user choice is equal to 5, go to theyWin

    rjmp GAMEEND            ; Go to GAMEEND

uWin:
    ldi ilcnt, 8            ; Load inner loop counter
    rcall WRITESCREEN       ; Update LCD screen
    rjmp ENDEND             ; Go to ENDEND

theyWin:
    ldi ilcnt, 9            ; Load inner loop counter
    rcall WRITESCREEN       ; Update LCD screen
    rjmp ENDEND             ; Go to ENDEND

uDraw:
    ldi ilcnt, 10           ; Load inner loop counter
    rcall WRITESCREEN       ; Update LCD screen
    rjmp ENDEND             ; Go to ENDEND

ENDEND:
    rcall STARTTIMER        ; Start timer
    ldi mpr, 0b11110000     ; Load mpr with a value for PORTB
    mov tmrcnt, mpr         ; Move mpr to tmrcnt
    out PORTB, mpr          ; Output mpr to PORTB
ENDLOOP:
    sbis TIFR1, TOV1        ; Skip if timer overflow flag is not set
    rjmp NOTIMER3           ; If timer overflow flag is not set, skip
        lsl tmrcnt              ; Left shift tmrcnt
        mov mpr, tmrcnt         ; Move tmrcnt to mpr
        out PORTB, mpr          ; Output mpr to PORTB
        cpi mpr, 0              ; Compare mpr with 0
        breq ENDENDEND          ; If mpr is 0, go to ENDENDEND
        rcall STARTTIMER        ; Start timer again
    NOTIMER3:
    rjmp ENDLOOP             ; Go to ENDLOOP

ENDENDEND:
    ret                     ; Return from subroutine

;***********************************************************
;* Write Screen
;***********************************************************
WRITESCREEN:
    push XH                 ; Push XH onto the stack
    push XL                 ; Push XL onto the stack
    push YH                 ; Push YH onto the stack
    push YL                 ; Push YL onto the stack
    push ZH                 ; Push ZH onto the stack
    push ZL                 ; Push ZL onto the stack
    push mpr                ; Push mpr onto the stack
    push r0                 ; Push r0 onto the stack
    push r1                 ; Push r1 onto the stack

    push ilcnt              ; Push ilcnt onto the stack
    push olcnt              ; Push olcnt onto the stack

    ldi XH, $03             ; Load XH with a specific value
    ldi XL, $00             ; Load XL with a specific value

    rcall LCDClr            ; Clear LCD screen

    pop  mpr                ; Pop mpr from the stack
    cpi mpr, $FF            ; Compare mpr with $FF
    breq SKIPWRITE1         ; If mpr is $FF, skip to SKIPWRITE1
        ldi YH, lcd2H           ; Load YH with lcd2H
        ldi YL, lcd2L           ; Load YL with lcd2L
        ldi ilcnt, 16           ; Load ilcnt with 16
        mul mpr, ilcnt          ; Multiply mpr by ilcnt
        mov ZH, r1              ; Move r1 to ZH
        mov ZL, r0              ; Move r0 to ZL
        add ZH, XH              ; Add XH to ZH
WRITELOOP1:                 ; Write loop 1
        ld mpr, Z+              ; Load mpr from Z and post-increment Z
        st Y+, mpr              ; Store mpr to Y and post-increment Y
        dec ilcnt               ; Decrement ilcnt
        cp ilcnt, zero          ; Compare ilcnt with zero
        brne WRITELOOP1         ; If ilcnt is not zero, go to WRITELOOP1
        rcall LCDWrLn2          ; Write line 2 of LCD
SKIPWRITE1:                 ; Skip write 1

    pop mpr                 ; Pop mpr from the stack
    cpi mpr, $FF            ; Compare mpr with $FF
    breq SKIPWRITE2         ; If mpr is $FF, skip to SKIPWRITE2
        ldi YH, lcd1H           ; Load YH with lcd1H
        ldi YL, lcd1L           ; Load YL with lcd1L
        ldi ilcnt, 16           ; Load ilcnt with 16
        mul mpr, ilcnt          ; Multiply mpr by ilcnt
        mov ZH, r1              ; Move r1 to ZH
        mov ZL, r0              ; Move r0 to ZL
        add ZH, XH              ; Add XH to ZH
WRITELOOP2:                 ; Write loop 2
        ld mpr, Z+              ; Load mpr from Z and post-increment Z
        st Y+, mpr              ; Store mpr to Y and post-increment Y
        dec ilcnt               ; Decrement ilcnt
        cp ilcnt, zero          ; Compare ilcnt with zero
        brne WRITELOOP2         ; If ilcnt is not zero, go to WRITELOOP2
        rcall LCDWrLn1          ; Write line 1 of LCD
SKIPWRITE2:                 ; Skip write 2

    pop r1                  ; Pop r1 from the stack
    pop r0                  ; Pop r0 from the stack
    pop mpr                 ; Pop mpr from the stack
    pop ZL                  ; Pop ZL from the stack
    pop ZH                  ; Pop ZH from the stack
    pop YL                  ; Pop YL from the stack
    pop YH                  ; Pop YH from the stack
    pop XL                  ; Pop XL from the stack
    pop XH                  ; Pop XH from the stack
    ret                     ; Return from subroutine

;***********************************************************
;* Start Timer
;***********************************************************
STARTTIMER:
    push mpr                ; Push mpr onto the stack

    ldi mpr, 0b01001000     ; Load mpr with a specific value
    sts TCNT1H, mpr         ; Store mpr to TCNT1H
    ldi mpr, 0b11100100     ; Load mpr with a specific value
    sts TCNT1L, mpr         ; Store mpr to TCNT1L
    ldi mpr, $01            ; Load mpr with a specific value
    out TIFR1, mpr          ; Output mpr to TIFR1

    pop mpr                 ; Pop mpr from the stack
    ret                     ; Return from subroutine

;***********************************************************
;* Small Wait
;***********************************************************
SMALLWAIT:
    push ilcnt              ; Push ilcnt onto the stack
    ldi ilcnt, $FF          ; Load ilcnt with a specific value
SMALLWAITLOOP:              ; Small wait loop
    dec ilcnt               ; Decrement ilcnt
    nop                     ; No operation
    nop                     ; No operation
    nop                     ; No operation
    cpi ilcnt, 0            ; Compare ilcnt with 0
    brne SMALLWAITLOOP      ; If ilcnt is not 0, go to SMALLWAITLOOP
    pop ilcnt               ; Pop ilcnt from the stack
    ret                     ; Return from subroutine

;***********************************************************
;* Stored Program Data
;***********************************************************

; An example of storing a string.
STRING1:
.DB     "Welcome!        "   ; Welcome string
STRING2:
.DB     "Please press PD7"   ; Instruction string
STRING3:
.DB     "Ready. Waiting  "   ; Ready string
STRING4:
.DB     "for the opponent"   ; Opponent waiting string
STRING5:
.DB     "Game start      "   ; Game start string
STRING6:
.DB     "Rock            "   ; Rock string
STRING7:
.DB     "Paper           "   ; Paper string
STRING8:
.DB     "Scissor         "   ; Scissor string
STRING9:
.DB     "You won!        "   ; You won string
STRING10:
.DB     "You lost        "   ; You lost string
STRING11:
.DB     "Draw            "   ; Draw string

;***********************************************************
;* Data Memory Allocation
;***********************************************************
.dseg
.org    $0300               ; Start of data segment
welcome:    .byte 16        ; Welcome string variable
press:      .byte 16        ; Press instruction string variable
ready:      .byte 16        ; Ready string variable
for:        .byte 16        ; For string variable
start:      .byte 16        ; Start string variable
rock:       .byte 16        ; Rock string variable
paper:      .byte 16        ; Paper string variable
scissor:    .byte 16        ; Scissor string variable
win:        .byte 16        ; Win string variable
lose:       .byte 16        ; Lose string variable
draw:       .byte 16        ; Draw string variable

;***********************************************************
;* Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"    ; Include LCD driver assembly file
