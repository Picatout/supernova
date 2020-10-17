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

TO-FLASH 

\ FORGET OLD VERSION
 FORGET BSET


\ set register bit
: BSET ( b a -- )
    DUP 
    C@ 
    ROT 1 
    SWAP 
    LSHIFT 
    OR 
    SWAP 
    C!
;

\ read register bit
: BREAD ( b a -- 0|1 )
    OVER 
    >R 
    C@ 
    1 
    ROT 
    LSHIFT 
    AND 
    R> 
    RSHIFT 
;

\ set 16 bits register value
: R16! ( n a -- )
    OVER 
    8 RSHIFT 
    OVER C! 
    1+ C! 
;

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

: ARRAY ( size -- ; string ) \ create an array, not initialized 
    HERE 
    DUP 
    ROT 
    2* 
    + 
    VP 
    ! 
    CREATE 
    ,
    FMOVE
    ?DUP 
    IF 
    UPDAT-VP
    UPDAT-PTR
    ELSE
    LAST 
    RAMLAST
    !
    THEN 
; 

: EL-ADR ( idx a1 -- a2 ) \ compute array element address
    SWAP 2* + 
;
 
: ARRAY! ( n idx a -- ) \ store value n in a[idx]
    EL-ADR !
;

: ARRAY@ ( idx a -- n ) \ fetch value in a[idx]
    EL-ADR @
;


VARIABLE PHASE \ cycle phase
9 ARRAY INTENSITY \ ring light level

: ADC-INIT ( -- ) \ initialize ADC1 
    $41 ADC-CR1 C! \ Fclk_adc=Fclk_master/8
; 

: ADC-READ ( ch -- n ) \ analog read channel ch
  0 ADC-CR1 BSET
  BEGIN 0 ADC-CR1 BREAD NOT UNTIL
  ADC-DRH C@  4 * ADC-DRL C@ + 
;

: CCR! ( u1 u2 u3 -- ) \ u1=duty cycle, u2=Tx-CCR1H, u3 Tx-channel
\ Store u1 value in Tx-CCR register
    2* + R16!
;

: RING-LEVEL ( r dc -- ) \ set light level of ring r 
    SWAP DUP
    4 - 0< IF 
    T1-CCR1H SWAP CCR!
    $1F T1-EGR C! \ update channels 0,1,2,3
    ELSE
    DUP 6 - 0< IF
    4 - 
    T2-CCR1H SWAP CCR! 
    7 T2-EGR C! \ update channels 4,5
    ELSE
    6 -
    T3-CCR1H SWAP CCR!
    7 T3-EGR C! \ update channels 6,7
    THEN
    THEN
;

: LED-INTENSITY ( r -- ) \ r is ring number {0..8}
  DUP
  INTENSITY ARRAY@ \ duty cycle value 
  RING-LEVEL 
;

: TIMERS-INIT ( -- ) \ initialize TIMER1, TIMER2 and TIMER3 in PMW mode.
\ TIMER3 CH1 & CH2  RINGS 7,8
    $FFFF PWM-PER T3-ARRH R16!
    0 T3-CCR1H R16! \ ring 7 off
    0 T3-CCR2H R16! \ ring 8 off 
    $D 3 LSHIFT T3-CCMR1 C! \ CH1 MODE PWM 
    $D 3 LSHIFT T3-CCMR2 C! \ CH2 MODE PWM
    $11 T3-CCER1 C! \ CH1 & CH2 ENABLE
    7 T3-EGR C! \ update CCR1,2 registers 
    1 T3-CR1 C! \ enable T3 counter 
\ TIMER2 CH1 & CH2 RINGS 5,6 
    $FFFF PWM-PER T2-ARRH R16! \ period 
    0 T2-CCR1H R16! \ RING 5 OFF
    0 T2-CCR2H R16! \ RING 6 OFF 
    $D 3 LSHIFT T2-CCMR1 C! \ CH1 MODE PWM 
    $D 3 LSHIFT T2-CCMR2 C! \ CH2 MODE PWM
    $11 T2-CCER1 C! \ CH1 & CH2 ENABLE
    7 T2-EGR C! \ update CCR1,2 registers 
    1 T2-CR1 C! \ enable T2 counter 
\ TIMER1 CH1,CH2,CH3,CH4 RINGS 1,2,3,4
    $FFFF PWM-PER T1-ARRH R16! 
\ rings 1,2,3,4 off 
    0 T1-CCR1H R16! 
    0 T1-CCR2H R16!
    0 T1-CCR3H R16!
    0 T1-CCR4H R16! 
    $D 3 LSHIFT T1-CCMR1 C!
    $D 3 LSHIFT T1-CCMR2 C!
    $D 3 LSHIFT T1-CCMR3 C!
    $D 3 LSHIFT T1-CCMR4 C!
    $11 T1-CCER1 C! \ ENABLE CH1,CH2
    $11 T1-CCER2 C! \ ENABLE CH3,CH4    
    $80 T1-BKR C! \ MAIN OUTPUT ENABLE
    $1F T1-EGR C! \ update CCR1,2,3,4
    1 T1-CR1 C! \ ENABLE T1 COUNTER
;

: INTENSITY-INIT ( -- ) \ initialize intensity table 
\ stack those constants for intensity-init 
    $FFFF 
    $8000 
    $4000 
    $2000 
    $1000 
    $800 
    $400 
    $100 
    0
    8 FOR I INTENSITY ARRAY! NEXT 
;


: APP-INIT ( -- ) \ initialize application peripherals.
    INTENSITY-INIT
    ADC-INIT
    TIMERS-INIT
;


: PHASE-STEP 
    PHASE DUP @ 1+ 
    8 MOD 
    SWAP !
;

: ALL-OFF ( -- ) \ turn off all rings
    7 FOR
        I 0 RING-LEVEL
    NEXT
;

: DELAY ( -- u ) \ get delay from potentiomer read. 
    ADC-READ 0 SWAP 
    BEGIN
        ?DUP 
    WHILE 
        SWAP 1+ SWAP \ increment log counter
        2/ 
    REPEAT
    8 * 
    1 OR \ avoid 0 value. 
;

: NOVA 
    APP-INIT 
    BEGIN
    DELAY \ step delay value
    7 FOR 
        7 I - DUP LED-INTENSITY \ turn on ring
        OVER PAUSE \ step delay 
        0 RING-LEVEL \ turn off ring
      NEXT
    DROP  
    500 PAUSE \ cycle pause
    ?KEY UNTIL DROP
;

: TWINKLE \ blue star twinkling
    APP-INIT
    0 PHASE !
    BEGIN
        7 FOR
            I PHASE @ + 8 MOD
            LED-INTENSITY
        NEXT
        DELAY PAUSE
        PHASE-STEP
        ?KEY 
    UNTIL
    DROP
    ALL-OFF
;

: ERASE-TRAIL
    BEGIN
        DUP 8 <
    WHILE
        DUP 0 RING-LEVEL
        1+
        OVER PAUSE
    REPEAT
    2DROP
;

: NOVA2 \ like NOVA but with a trail
APP-INIT
BEGIN
    DELAY
    0
    7 FOR
        7 I - DUP LED-INTENSITY
        3 - 0< NOT IF
            DUP 0 RING-LEVEL
            1+
        THEN
        OVER PAUSE
    NEXT
    ERASE-TRAIL
    ?KEY 
UNTIL 
DROP 
;

