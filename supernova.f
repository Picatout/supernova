\ *****************************************
\ supernova application Forth source file
\ 2020-10-10
\ Copyright Jacques Deschenes, 2020
\ License GNU V3
\ *****************************************

\ *****************************************
\ Peripherals usage
\ TIMER1 CH1 PWM OUTPUT RING 1 LED CONTROL
\ TIMER1 CH2 PWM OUTPUT RING 2 LED CONTROL
\ TIMER1 CH3 PWM OUTPUT RING 3 LED CONTROL
\ TIMER1 CH4 PWM OUTPUT RING 4 LED CONTROL
\ TIMER2 CH1 PWM OUTPUT RING 5 LED CONTROL
\ TIMER2 CH2 PWM OUTPUT RING 6 LED CONTROL
\ TIMER3 CH1 PWM OUTPUT RING 7 LED CONTROL
\ TIMER3 CH2 PWM OUTPUT RING 8 LED CONTROL
\ ADC AN0 RV1 INPUT SPEED CONTROL
\ *****************************************

\ FORGET OLD VERSION
FORGET R16!

\ set 16 bits register value
: R16! ( n a -- )
    OVER 8 RSHIFT OVER C! 1+ C! ;

\ compute ARR value from frequency
: PWM-PER ( fr -- u )
\ for timer clock = 2Mhz, i.e. prescale divisor 8.
    31250 32 ( fr -- fr 31250 64 ) 
    ROT ( -- 31250 64 fr )
    DUP ( --  31250 64 fr fr ) 
    2/ ( --  31250 64 fr fr/2 )
    >R ( --  31250 64 fr ) ( R: -- fr/2 ) 
    */MOD ( -- r q ) \ 31250*8/fr -> remainder and quotient
    SWAP ( -- q r ) \ remainder on top 
    R>   ( -- q r fr/2 ) \ round to nearest integer 
    /    ( -- q 0|1 ) \ 
    + ( -- u ) \ nearest integer
; 

8 WTABLE INTENSITY 
 

VARIABLE PHASE \ supernova wave phase 


: INIT-ADC ( -- ) \ initialize ADC1 

; 

: READ-ADC ( ch -- n ) \ analog read channel ch

;

: RING-LEVEL ( r level -- ) \ set light level of ring r 
    
;

: RING-PHASE ( r -- ) \ select ring ligth level
  DUP 
  PHASE + 
  8 MOD 
  2* 
  INTENSITY + 
  @ 
  RING-LEVEL 
; 


: INIT-TIMERS ( -- ) \ initialize TIMER1, TIMER2 and TIMER3 in PMW mode.
\ TIMER3 CH1 & CH2  RINGS 7,8
    4 T3-PSCR C! \ prescale DIV 16, flcok=16Mhz/8=1Mhz
    50 PWM-PER T3-ARRH R16!
    0 T3-CCR1H R16! \ ring 7 off
    0 T3-CCR2H R16! \ ring 8 off 
    $D 3 LSHIFT T3-CCMR1 C! \ CH1 MODE PWM 
    $D 3 LSHIFT T3-CCMR2 C! \ CH2 MODE PWM
    $11 T3-CCER1 C! \ CH1 & CH2 ENABLE
    7 T3-EGR C! \ update CCR1,2 registers 
    1 T3-CR1 C! \ enable T3 counter 
\ TIMER2 CH1 & CH2 RINGS 5,6 
    4 T2-PSCR C! \ prescale DIV 16, Fclock=16Mhz/8=1Mhz 
    50 PWM-PER T2-ARRH R16! \ period 
    0 T2-CCR1H R16! \ RING 5 OFF
    0 T2-CCR2H R16! \ RING 6 OFF 
    $D 3 LSHIFT T2-CCMR1 C! \ CH1 MODE PWM 
    $D 3 LSHIFT T2-CCMR2 C! \ CH2 MODE PWM
    $11 T2-CCER1 C! \ CH1 & CH2 ENABLE
    7 T2-EGR C! \ update CCR1,2 registers 
    1 T2-CR1 C! \ enable T2 counter 
\ TIMER1 CH1,CH2,CH3,CH4 RINGS 1,2,3,4
    16 T1-PSCRH R16! \  PRESCALE DIVISOR
    50 PWM-PER T1-ARRH R16! 
\ rings 1,2,3,4 off 
    0 T1-CCR1H R16! 
    0 T1-CCR2H R16!
    0 T1-CCR3H R16!
    0 T1-CCR4H R16! 
    $D 3 LSHIFT T1-CCMR1 C!
    $D 3 LSHIFT T1-CCMR2 C!
    $D 3 LSHIFT T1-CCMR3 C!
    $d 3 LSHIFT T1-CCMR4 C!
    $11 T1-CCER1 C! \ ENABLE CH1,CH2
    $11 T1-CCER2 C! \ ENABLE CH3,CH4    
    $80 T1-BKR C! \ MAIN OUTPUT ENABLE
    15 T1-EGR C! \ update CCR1,2,3,4
    1 T1-CR1 C! \ ENABLE T1 COUNTER
;

: APP-INIT ( -- ) \ initialize application peripherals.
    INIT-ADC
    INIT-TIMERS
;


: PHASE-STEP 
    PHASE C@ 1+ 
    8 MOD 
    PHASE C!
;

: NOVA 
    APP-INIT 
    BEGIN
    READ-ADC 
    16 / 
    7 FOR I RING-PHASE DUP PAUSE PHASE-STEP NEXT
    AGAIN
;

