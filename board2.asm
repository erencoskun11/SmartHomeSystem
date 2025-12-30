;==============================================================================
;  SMART CURTAIN CONTROL SYSTEM
;==============================================================================
;  Project:     Smart Curtain Control System
;  Target:      PIC16F877A
;  Compiler:    XC8 PIC-AS (Relocatable Assembly)
;  Oscillator:  20 MHz HS Crystal
;  Authors:     Yağız Sürücü, Furkan Arslan, Buse Bayramlı
;  Date:        December 2025
;
;  ----------------------------------------------------------------------------
;  PROJECT MODULE ASSIGNMENTS / TASK DISTRIBUTION
;  ----------------------------------------------------------------------------
;  1. YAĞIZ SÜRÜCÜ:
;     - UART Module (ISR_HANDLER, UART_CMD_HANDLER, UART_TRANSMIT)
;     - Potentiometer Module (ADC_READ_POT, SKIP_POT_TARGET)
;
;  2. FURKAN ARSLAN:
;     - Step Motor Module (MOTOR_CONTROL, STEP_TABLE, MOTOR_FORWARD/REVERSE)
;     - LDR Light Sensor Module (ADC_READ_LDR, Night Mode Logic)
;
;  3. BUSE BAYRAMLI:
;     - LCD Module (LCD_INIT, LCD_SEND_CMD, LCD_SEND_DATA, DISPLAY_2DIGIT/3DIGIT)
;     - BMP180 Module (I2C Subroutines - disabled for simulation)
;
;  ----------------------------------------------------------------------------
;
;  FEATURES:
;    - 16x2 LCD Display (4-bit mode, RE0=RS, RE1=EN, RD0-RD3=Data)
;    - Stepper Motor Control (1000 steps = 100%, 5 full rotations)
;    - Dual ADC Channels (AN0=LDR Light Sensor, AN1=Position Potentiometer)
;    - UART Communication (9600 baud, interrupt-driven, 10 commands)
;    - I2C BMP180 Temperature/Pressure Sensor (disabled for simulation)
;    - Automatic Night Mode (closes curtain when light < 40%)
;    - Integer/Fractional data structure for UART protocol
;
;==============================================================================
;  PIN ASSIGNMENT TABLE
;==============================================================================
;
;   PIN     | PORT  | FUNCTION              | DIRECTION | NOTES
;   --------|-------|-----------------------|-----------|------------------
;   2       | RA0   | LDR (Light Sensor)    | Input     | Analog AN0
;   3       | RA1   | POT (Position)        | Input     | Analog AN1
;   33      | RB0   | Motor Phase A         | Output    | To ULN2003
;   34      | RB1   | Motor Phase B         | Output    | To ULN2003
;   35      | RB2   | Motor Phase C         | Output    | To ULN2003
;   36      | RB3   | Motor Phase D         | Output    | To ULN2003
;   18      | RC3   | I2C SCL               | Bidir     | 100kHz clock
;   23      | RC4   | I2C SDA               | Bidir     | Data line
;   25      | RC6   | UART TX               | Output    | 9600 baud (→ IO UART P2-RX)
;   26      | RC7   | UART RX               | Input     | 9600 baud (← IO UART P3-TX)
;   19      | RD0   | LCD D4                | Output    | 4-bit data
;   20      | RD1   | LCD D5                | Output    | 4-bit data
;   21      | RD2   | LCD D6                | Output    | 4-bit data
;   22      | RD3   | LCD D7                | Output    | 4-bit data
;   8       | RE0   | LCD RS                | Output    | Register Select
;   9       | RE1   | LCD EN                | Output    | Enable pulse
;   10      | RE2   | LCD RW                | Output    | Always LOW (0)
;
;==============================================================================

#include <xc.inc>

; Configuration bits for PIC16F877A
CONFIG  FOSC = HS           ; High-Speed Crystal Oscillator (20MHz)
CONFIG  WDTE = OFF          ; Watchdog Timer Disabled
CONFIG  PWRTE = ON          ; Power-up Timer Enabled
CONFIG  BOREN = ON          ; Brown-out Reset Enabled
CONFIG  LVP = OFF           ; Low Voltage Programming Disabled
CONFIG  CPD = OFF           ; Data EEPROM Protection Off
CONFIG  WRT = OFF           ; Flash Memory Write Protection Off
CONFIG  CP = OFF            ; Code Protection Off

;==============================================================================
; UART COMMAND CODES [R2.2.6 Protocol Specification]
;==============================================================================
; GET Commands (00000xxx) - Request data from PIC
CMD_GET_CURTAIN_FRAC    EQU 0x01    ; 00000001: Get Curtain Fractional
CMD_GET_CURTAIN_INT     EQU 0x02    ; 00000010: Get Curtain Integer
CMD_GET_TEMP_FRAC       EQU 0x03    ; 00000011: Get Temperature Fractional
CMD_GET_TEMP_INT        EQU 0x04    ; 00000100: Get Temperature Integer
CMD_GET_PRESS_FRAC      EQU 0x05    ; 00000101: Get Pressure Fractional
CMD_GET_PRESS_INT       EQU 0x06    ; 00000110: Get Pressure Integer
CMD_GET_LIGHT_FRAC      EQU 0x07    ; 00000111: Get Light Fractional
CMD_GET_LIGHT_INT       EQU 0x08    ; 00001000: Get Light Integer

; SET Commands (use bit masking)
; 10xxxxxx (0x80-0xBF): SET Curtain Fractional, lower 6 bits = value
; 11xxxxxx (0xC0-0xFF): SET Curtain Integer, lower 6 bits = value
SET_CURTAIN_FRAC_MASK   EQU 0x80    ; Top 2 bits = 10
SET_CURTAIN_INT_MASK    EQU 0xC0    ; Top 2 bits = 11
COMMAND_MASK            EQU 0xC0    ; Mask to extract top 2 bits
VALUE_MASK              EQU 0x3F    ; Mask to extract lower 6 bits (0-63)

;==============================================================================
; SYSTEM CONSTANTS
;==============================================================================
LIGHT_THRESHOLD     EQU 40      ; Night mode threshold (light < 40% = dark)
TEMP_OFFSET         EQU 0       ; Temperature calibration offset
PRESS_OFFSET        EQU 0       ; Pressure calibration offset
STEPS_PER_PERCENT   EQU 10      ; Motor steps per 1% movement (1000 total)
LCD_UPDATE_RATE     EQU 20      ; LCD refresh rate (loop iterations)

;==============================================================================
; VARIABLE DEFINITIONS - Bank 0
;==============================================================================
PSECT udata_bank0

; Delay Counters
DELAY_CNT_X:        DS 1        ; General purpose delay counter X
DELAY_CNT_Y:        DS 1        ; General purpose delay counter Y
TIMEOUT_COUNTER:    DS 1        ; I2C communication timeout

; ADC Raw Values (0-255)
ADC_RAW_POT:        DS 1        ; Raw potentiometer reading
ADC_RAW_LDR:        DS 1        ; Raw light sensor reading

; Scaled Values (Integer + Fractional parts for UART protocol)
LIGHT_INT:          DS 1        ; Light level integer (0-100%)
LIGHT_FRAC:         DS 1        ; Light level fractional (0-9)
CURTAIN_TARGET_INT: DS 1        ; Target position integer (0-100%)
CURTAIN_TARGET_FRAC:DS 1        ; Target position fractional
CURTAIN_POS_INT:    DS 1        ; Current position integer (0-100%)
CURTAIN_POS_FRAC:   DS 1        ; Current position fractional

; Motor Control Variables
CURTAIN_CURRENT:    DS 1        ; Current curtain position (0-100%)
CURTAIN_TARGET:     DS 1        ; Target curtain position (0-100%)
MOTOR_PHASE:        DS 1        ; Current motor phase (0-3)
STEP_COUNTER:       DS 1        ; Steps within current percent (0-9)

; Temperature/Pressure (Integer + Fractional)
TEMP_INT:           DS 1        ; Temperature integer (degrees Celsius)
TEMP_FRAC:          DS 1        ; Temperature fractional (0-9)
PRESS_INT:          DS 1        ; Pressure integer (last 2 digits of hPa)
PRESS_FRAC:         DS 1        ; Pressure fractional

; I2C Communication
I2C_BUFFER:           DS 1        ; I2C receive/transmit buffer

; LCD Driver Variables
LCD_TEMP:           DS 1        ; Temporary storage for LCD operations
DIGIT_100:          DS 1        ; Hundreds digit for display
DIGIT_10:           DS 1        ; Tens digit for display
DIGIT_1:            DS 1        ; Units digit for display
NUM_TEMP:           DS 1        ; Temporary for number conversion
LCD_TIMER:          DS 1        ; LCD update timing counter

; UART Communication
UART_RX_DATA:       DS 1        ; Received command byte
UART_CMD_READY:     DS 1        ; Command ready flag (bit 0)

; System State
SYSTEM_MODE:        DS 1        ; Operating mode (0=Auto, 1=Manual)

; Math Operations
MATH_TEMP:          DS 1        ; Temporary for calculations

;==============================================================================
; SHARED MEMORY (Accessible from any bank - used by ISR)
;==============================================================================
PSECT udata_shr

W_SAVE:             DS 1        ; W register context save
STATUS_SAVE:        DS 1        ; STATUS register context save

;==============================================================================
; RESET VECTOR - Program Entry Point (Address 0x0000)
;==============================================================================
PSECT resetVec, class=CODE, abs, ovrld, delta=2
ORG 0x0000
    GOTO    INIT                ; Jump to initialization routine

;==============================================================================
; INTERRUPT VECTOR - ISR Entry Point (Address 0x0004)
;==============================================================================
PSECT intVec, class=CODE, abs, ovrld, delta=2
ORG 0x0004
    GOTO    ISR_HANDLER         ; Jump to interrupt service routine

;==============================================================================
; STEPPER MOTOR PHASE TABLE
; Full-step sequence for unipolar stepper motor
; Output pattern: RB3|RB2|RB1|RB0 = Phase D|C|B|A
;==============================================================================
PSECT motor_table, class=CODE, abs, ovrld, delta=2
ORG 0x0100                      ; Place table at fixed address for PCLATH

STEP_TABLE:
    ADDWF   PCL, F              ; Computed GOTO: jump by phase index
    RETLW   0b00000001          ; Phase 0: Coil A energized
    RETLW   0b00000010          ; Phase 1: Coil B energized
    RETLW   0b00000100          ; Phase 2: Coil C energized
    RETLW   0b00001000          ; Phase 3: Coil D energized

;==============================================================================
; MAIN PROGRAM CODE SECTION
;==============================================================================
PSECT code

GLOBAL _main
GLOBAL start_initialization

;==============================================================================
; INIT - System Initialization
; Purpose: Configure all peripherals and initialize variables
; Inputs:  None
; Outputs: System ready for main loop execution
;==============================================================================
_main:
start_initialization:
INIT:
    ;--------------------------------------------------------------------------
    ; BANK 1 CONFIGURATION - TRIS and Special Registers
    ;--------------------------------------------------------------------------
    BSF     STATUS, 5           ; Select Bank 1
    
    ; Configure Port Directions
    CLRF    TRISB               ; PORTB = Output (Stepper motor phases)
    CLRF    TRISD               ; PORTD = Output (LCD data bus)
    CLRF    TRISE               ; PORTE = Output (LCD: RS=RE0, EN=RE1, RW=RE2)
    BSF     TRISC, 7            ; RC7 = Input (UART RX)
    BCF     TRISC, 6            ; RC6 = Output (UART TX)
    BSF     TRISC, 3            ; RC3 = Input (I2C SCL - bidirectional)
    BSF     TRISC, 4            ; RC4 = Input (I2C SDA - bidirectional)
    MOVLW   0xFF
    MOVWF   TRISA               ; PORTA = Input (All analog channels)

    ; ADC Configuration: Left justified, AN0-AN4 analog, Vref = VDD/VSS
    MOVLW   0b00000010          ; PCFG = 0010
    MOVWF   ADCON1
    
    ; UART Configuration: 9600 baud @ 20MHz
    ; SPBRG = (Fosc / (16 * Baud)) - 1 = (20MHz / 153600) - 1 = 129
    MOVLW   129
    MOVWF   SPBRG
    MOVLW   0b00100100          ; TXEN=1 (Enable TX), BRGH=1 (High speed)
    MOVWF   TXSTA
    BSF     PIE1, 5             ; RCIE=1 (Enable UART RX interrupt)
    
    ; I2C Configuration: Master mode, 100kHz @ 20MHz
    ; SSPADD = (Fosc / (4 * Fscl)) - 1 = (20MHz / 400kHz) - 1 = 49
    MOVLW   49
    MOVWF   SSPADD
    MOVLW   0b10000000          ; SMP=1 (Slew rate control disabled)
    MOVWF   SSPSTAT

    ;--------------------------------------------------------------------------
    ; BANK 0 CONFIGURATION - Control Registers
    ;--------------------------------------------------------------------------
    BCF     STATUS, 5           ; Select Bank 0
    
    ; ADC Control: Enable ADC, Channel 0 (LDR), Fosc/8
    MOVLW   0b10000001          ; ADON=1, CHS=000, ADCS=00
    MOVWF   ADCON0
    
    ; I2C Control: Enable I2C Master mode
    MOVLW   0b00101000          ; SSPEN=1, SSPM=1000 (I2C Master)
    MOVWF   SSPCON
    
    ; UART Receiver: Enable serial port and continuous receive
    MOVLW   0b10010000          ; SPEN=1, CREN=1
    MOVWF   RCSTA
    
    ; Enable Global and Peripheral Interrupts
    BSF     INTCON, 7           ; GIE = 1 (Global Interrupt Enable)
    BSF     INTCON, 6           ; PEIE = 1 (Peripheral Interrupt Enable)

    ;--------------------------------------------------------------------------
    ; VARIABLE INITIALIZATION
    ;--------------------------------------------------------------------------
    ; Clear all output ports
    CLRF    PORTB               ; Motor phases off
    CLRF    PORTD               ; LCD data clear
    CLRF    PORTE               ; LCD control clear (RS=0, EN=0, RW=0)
    
    ; Initialize motor position tracking
    CLRF    CURTAIN_CURRENT     ; Curtain starts at 0%
    CLRF    CURTAIN_TARGET      ; No movement target
    CLRF    MOTOR_PHASE         ; Starting phase
    CLRF    STEP_COUNTER        ; Step counter reset
    
    ; Clear ADC readings
    CLRF    ADC_RAW_POT
    CLRF    ADC_RAW_LDR
    
    ; Initialize system state
    CLRF    SYSTEM_MODE         ; Start in Auto mode
    CLRF    UART_CMD_READY      ; No pending commands
    CLRF    LCD_TIMER           ; LCD timing reset
    
    ; Set default sensor values (used when BMP180 disabled)
    MOVLW   25                  ; Default temperature: 25.0°C
    MOVWF   TEMP_INT
    CLRF    TEMP_FRAC
    MOVLW   23                  ; Default pressure: 1023 hPa
    MOVWF   PRESS_INT
    CLRF    PRESS_FRAC
    
    ; Initialize display values
    CLRF    CURTAIN_POS_INT
    CLRF    CURTAIN_POS_FRAC
    CLRF    CURTAIN_TARGET_INT
    CLRF    CURTAIN_TARGET_FRAC
    CLRF    LIGHT_INT
    CLRF    LIGHT_FRAC
    
    ;--------------------------------------------------------------------------
    ; LCD INITIALIZATION
    ;--------------------------------------------------------------------------
    CALL    LCD_INIT
    
    ; Write static display template per R2.2.5
    ; Line 1: "xx.xC xx.xh" (Temp + Pressure with units)
    ; Line 2: "xxx.xL xxx.x%" (Light + Curtain with units)
    ; Note: Only static 'C', 'h', 'L', '%' characters are written here
    ; Dynamic values are updated in LCD_UPDATE
    
    ; Line 1: Temperature unit 'C' at position 5
    MOVLW   0x85                ; Position at column 5
    CALL    LCD_SEND_CMD
    MOVLW   'C'
    CALL    LCD_SEND_DATA
    
    ; Line 1: Pressure unit 'h' (for hPa) at position 12
    MOVLW   0x8C                ; Position at column 12
    CALL    LCD_SEND_CMD
    MOVLW   'h'
    CALL    LCD_SEND_DATA
    
    ; Line 2: Light unit 'L' at position 6 (after xxx.x)
    MOVLW   0xC6                ; Position at line 2, column 6
    CALL    LCD_SEND_CMD
    MOVLW   'L'
    CALL    LCD_SEND_DATA
    
    ; Line 2: Curtain unit '%' at position 14 (after xxx.x)
    MOVLW   0xCE                ; Position at line 2, column 14
    CALL    LCD_SEND_CMD
    MOVLW   '%'
    CALL    LCD_SEND_DATA

;==============================================================================
; MAIN_LOOP - Primary Control Loop
; Purpose: Continuous monitoring of sensors, motor control, and communication
; Executes: ADC sampling -> Scaling -> Decision logic -> Motor -> LCD update
;==============================================================================
MAIN_LOOP:
    ;--------------------------------------------------------------------------
    ; STEP 1: READ ADC CHANNELS
    ; Read potentiometer (curtain position) and LDR (ambient light)
    ;--------------------------------------------------------------------------
    CALL    ADC_READ_POT        ; Read potentiometer -> W
    MOVWF   ADC_RAW_POT         ; Store raw value (0-255)
    
    CALL    ADC_READ_LDR        ; Read light sensor -> W
    MOVWF   ADC_RAW_LDR         ; Store raw value (0-255)
    
    ;--------------------------------------------------------------------------
    ; STEP 2: SCALE ADC VALUES (0-255 -> 0-100%)
    ; Convert raw ADC readings to percentage for control logic
    ;--------------------------------------------------------------------------
    MOVF    ADC_RAW_LDR, W      ; Load LDR raw value
    CALL    ADC_TO_PERCENT      ; Convert to percentage -> W
    MOVWF   LIGHT_INT           ; Store light level (0-100%)
    CLRF    LIGHT_FRAC          ; No fractional part in this implementation
    
    ; Only update target from pot if in AUTO mode (UART hasn't set a value)
    BTFSC   SYSTEM_MODE, 0      ; Skip pot target if Manual mode (UART control)
    GOTO    SKIP_POT_TARGET
    MOVF    ADC_RAW_POT, W      ; Load potentiometer raw value
    CALL    ADC_TO_PERCENT      ; Convert to percentage -> W
    MOVWF   CURTAIN_TARGET_INT  ; Store as curtain target (0-100%)
    CLRF    CURTAIN_TARGET_FRAC
SKIP_POT_TARGET:
    
    ;--------------------------------------------------------------------------
    ; STEP 3: BMP180 SENSOR READING (DISABLED FOR SIMULATION)
    ; When enabled, reads temperature and pressure via I2C
    ;--------------------------------------------------------------------------
    ; Note: BMP180 is commented out as PICSimLab doesn't support it
    ; Default values (25.0°C, 1013 hPa) are used instead
    ; To enable: Uncomment CALL BMP180_READ below
    ; CALL    BMP180_READ
    
    ;--------------------------------------------------------------------------
    ; STEP 4: TARGET POSITION DECISION LOGIC
    ; Determines curtain target based on mode and light conditions
    ;--------------------------------------------------------------------------
    ; Check if Manual mode is active (UART control)
    BTFSC   SYSTEM_MODE, 0      ; Bit 0 set = Manual mode
    GOTO    MOTOR_CTRL_START    ; In Manual mode, UART already set target
    
    ; AUTO MODE: Check if it's dark enough for night mode
    MOVLW   LIGHT_THRESHOLD     ; Load threshold (40%)
    SUBWF   LIGHT_INT, W        ; W = Light - Threshold
    BTFSC   STATUS, 0           ; Carry set if Light >= Threshold (daytime)
    GOTO    SET_TARGET          ; Daytime: use potentiometer target
    
    ; NIGHT MODE (R2.2.2): Override target to 100% (fully CLOSED when dark)
    ; Curtain should close when dark, target = 100%
    MOVLW   100
    MOVWF   CURTAIN_TARGET      ; Motor control variable = 100%
    MOVLW   100
    MOVWF   CURTAIN_TARGET_INT
    CLRF    CURTAIN_TARGET_FRAC
    GOTO    MOTOR_CTRL_START    ; Skip SET_TARGET, go directly to motor

SET_TARGET:
    ; Clamp target to maximum 100% (only in Auto mode)
    MOVF    CURTAIN_TARGET_INT, W
    SUBLW   100                 ; W = 100 - target
    BTFSC   STATUS, 0           ; Carry set if target <= 100 (OK)
    GOTO    TARGET_OK
    MOVLW   100
    MOVWF   CURTAIN_TARGET_INT  ; Limit to 100%
TARGET_OK:
    MOVF    CURTAIN_TARGET_INT, W
    MOVWF   CURTAIN_TARGET

MOTOR_CTRL_START:
    ; In Manual mode (UART), skip to motor control
    ; CURTAIN_TARGET was already set by UART command

    ;--------------------------------------------------------------------------
    ; STEP 5: STEPPER MOTOR CONTROL
    ; Moves curtain toward target position, 10 steps per 1% movement
    ;--------------------------------------------------------------------------
MOTOR_CONTROL:
    ; Check if target reached
    MOVF    CURTAIN_TARGET, W
    SUBWF   CURTAIN_CURRENT, W
    BTFSC   STATUS, 2           ; Zero flag set = target reached
    GOTO    UART_PROCESS        ; No movement needed
    
    ; Determine direction
    BTFSS   STATUS, 0           ; Carry clear if Target > Current
    GOTO    MOTOR_FORWARD       ; Need to close curtain
    GOTO    MOTOR_REVERSE       ; Need to open curtain

MOTOR_FORWARD:
    ; Move motor forward (closing curtain)
    ; 10 steps = 1% movement for 1000 total steps (5 rotations)
    INCF    STEP_COUNTER, F     ; Increment step counter
    MOVLW   STEPS_PER_PERCENT   ; Check if 10 steps completed
    SUBWF   STEP_COUNTER, W
    BTFSS   STATUS, 2           ; Zero flag = 10 steps done
    GOTO    EXECUTE_STEP_FWD    ; Not yet, just step
    
    ; 10 steps completed - increment position
    CLRF    STEP_COUNTER
    INCF    CURTAIN_CURRENT, F
    INCF    CURTAIN_POS_INT, F
    GOTO    EXECUTE_STEP_FWD

MOTOR_REVERSE:
    ; Move motor reverse (opening curtain)
    INCF    STEP_COUNTER, F
    MOVLW   STEPS_PER_PERCENT
    SUBWF   STEP_COUNTER, W
    BTFSS   STATUS, 2
    GOTO    EXECUTE_STEP_REV
    
    ; 10 steps completed - decrement position
    CLRF    STEP_COUNTER
    DECF    CURTAIN_CURRENT, F
    DECF    CURTAIN_POS_INT, F
    GOTO    EXECUTE_STEP_REV

EXECUTE_STEP_FWD:
    ; Advance motor phase forward
    INCF    MOTOR_PHASE, F
    MOVLW   0x03                ; Mask to 0-3 range (4 phases)
    ANDWF   MOTOR_PHASE, F
    GOTO    APPLY_STEP

EXECUTE_STEP_REV:
    ; Advance motor phase reverse
    DECF    MOTOR_PHASE, F
    MOVLW   0x03                ; Mask to 0-3 range
    ANDWF   MOTOR_PHASE, F

APPLY_STEP:
    ; Output current phase to motor driver
    MOVLW   HIGH STEP_TABLE     ; Set PCLATH for table access
    MOVWF   PCLATH
    MOVF    MOTOR_PHASE, W      ; Get current phase index
    CALL    STEP_TABLE          ; Lookup phase pattern -> W
    MOVWF   PORTB               ; Drive motor coils
    CLRF    PCLATH              ; Reset PCLATH
    CALL    DELAY_MOTOR         ; Wait for motor to settle

    ;--------------------------------------------------------------------------
    ; STEP 6: UART COMMAND PROCESSING
    ; Handle any pending serial commands from PC
    ;--------------------------------------------------------------------------
UART_PROCESS:
    BTFSS   UART_CMD_READY, 0   ; Check if command received
    GOTO    LCD_UPDATE          ; No command pending
    
    CALL    UART_CMD_HANDLER    ; Process received command
    CLRF    UART_CMD_READY      ; Clear flag

    ;--------------------------------------------------------------------------
    ; STEP 7: LCD DISPLAY UPDATE
    ; Periodically refresh display with current sensor values
    ;--------------------------------------------------------------------------
LCD_UPDATE:
    INCF    LCD_TIMER, F        ; Increment update timer
    MOVLW   LCD_UPDATE_RATE
    SUBWF   LCD_TIMER, W
    BTFSS   STATUS, 0           ; Time to update?
    GOTO    MAIN_LOOP           ; Not yet, continue main loop
    CLRF    LCD_TIMER           ; Reset timer

    ;--------------------------------------------------------------------------
    ; LCD Display Format per R2.2.5:
    ; Line 1: |sign|xt|xt|.|xt|Â°|C| | |xp|xp|xp|xp|h|P|a|
    ;   Col:  | 1  | 2| 3|4| 5|6|7|8|9|10|11|12|13|14|15|16|
    ; Writing ALL characters every update (no static dependency)
    ;--------------------------------------------------------------------------
    
    ; === LINE 1: TEMPERATURE ===
    ; Col 1 (0x80): Sign character
    MOVLW   0x80
    CALL    LCD_SEND_CMD
    MOVLW   '+'                 ; Positive temperature sign
    CALL    LCD_SEND_DATA
    
    ; Col 2-3 (0x81-0x82): Temperature integer (2 digits)
    MOVF    TEMP_INT, W
    CALL    DISPLAY_2DIGIT
    
    ; Col 4 (0x83): '.' decimal point
    MOVLW   '.'
    CALL    LCD_SEND_DATA
    
    ; Col 5 (0x84): Temperature fractional
    MOVF    TEMP_FRAC, W
    ADDLW   '0'
    CALL    LCD_SEND_DATA
    
    ; Col 6 (0x85): Degree symbol (use * if 0xDF doesn't work)
    MOVLW   0xDF                ; Degree symbol
    CALL    LCD_SEND_DATA
    
    ; Col 7 (0x86): 'C'
    MOVLW   'C'
    CALL    LCD_SEND_DATA
    
    ; === LINE 1: PRESSURE ===
    ; Col 8-9 (0x87-0x88): Spaces
    MOVLW   ' '
    CALL    LCD_SEND_DATA
    MOVLW   ' '
    CALL    LCD_SEND_DATA
    
    ; Col 10-13 (0x89-0x8C): Pressure 4 digits (1023)
    MOVLW   '1'
    CALL    LCD_SEND_DATA
    MOVLW   '0'
    CALL    LCD_SEND_DATA
    MOVF    PRESS_INT, W        ; Last 2 digits (23 for 1023)
    CALL    DISPLAY_2DIGIT
    
    ; Col 14 (0x8D): 'h'
    MOVLW   'h'
    CALL    LCD_SEND_DATA
    
    ; Col 15 (0x8E): 'P'
    MOVLW   'P'
    CALL    LCD_SEND_DATA
    
    ; Col 16 (0x8F): 'a'
    MOVLW   'a'
    CALL    LCD_SEND_DATA
    
    ; Display Light at position 0 (Line 2): "xxx.x" (0-100 range)
    MOVLW   0xC0                ; Line 2, column 0
    CALL    LCD_SEND_CMD
    MOVF    LIGHT_INT, W
    CALL    DISPLAY_3DIGIT      ; Display 3-digit integer (000-100)
    MOVLW   '.'
    CALL    LCD_SEND_DATA
    MOVF    LIGHT_FRAC, W
    ADDLW   '0'
    CALL    LCD_SEND_DATA
    ; 'L' is already static at position 6
    
    ; Display Curtain Position at position 8 (Line 2): "xxx.x" (0-100 range)
    MOVLW   0xC8                ; Line 2, column 8
    CALL    LCD_SEND_CMD
    MOVF    CURTAIN_POS_INT, W
    CALL    DISPLAY_3DIGIT      ; Display 3-digit integer (000-100)
    MOVLW   '.'
    CALL    LCD_SEND_DATA
    MOVF    CURTAIN_POS_FRAC, W
    ADDLW   '0'
    CALL    LCD_SEND_DATA
    ; '%' is already static at position 14

    GOTO    MAIN_LOOP           ; Continue main loop

;==============================================================================
; ISR_HANDLER - Interrupt Service Routine
; Purpose: Handle UART receive interrupt
; Saves context, reads received byte, sets command ready flag
;==============================================================================
ISR_HANDLER:
    ; Save W register to shared memory (accessible from any bank)
    MOVWF   W_SAVE
    ; Save STATUS register (use SWAPF to avoid affecting flags)
    SWAPF   STATUS, W
    MOVWF   STATUS_SAVE
    ; Switch to Bank 0 for peripheral register access
    BCF     STATUS, 5
    BCF     STATUS, 6
    
    ; UART ERROR CHECK
    BTFSC   RCSTA, 1             ; Check for OERR (Overrun Error)
    GOTO    UART_RESET_ERR
    
    ; Check if UART receive interrupt flag is set
    BTFSS   PIR1, 5              ; Did data actually arrive? (RCIF)
    GOTO    ISR_EXIT

    ; Read received byte and set command ready flag
    MOVF    RCREG, W             ; Read data (also clears RCIF)
    MOVWF   UART_RX_DATA         ; Store received command byte
    BSF     UART_CMD_READY, 0    ; Set flag for main loop to process
    GOTO    ISR_EXIT

UART_RESET_ERR:
    ; Clear overrun error by toggling CREN (continuous receive enable)
    BCF     RCSTA, 4             ; Disable receiver
    BSF     RCSTA, 4             ; Re-enable receiver (clears error)

ISR_EXIT:
    ; Restore context (reverse order of save)
    SWAPF   STATUS_SAVE, W       ; Restore STATUS (SWAPF doesn't affect Z,C)
    MOVWF   STATUS
    SWAPF   W_SAVE, F            ; Restore W using double SWAPF
    SWAPF   W_SAVE, W            ; (avoids affecting STATUS flags)
    RETFIE                       ; Return from interrupt, re-enable GIE

;==============================================================================
; UART_CMD_HANDLER - Process UART Commands [R2.2.6 Protocol]
; Purpose: Parse received command and execute appropriate response
; Input:   UART_RX_DATA contains command byte
; Output:  Sends response data via UART
;
; Protocol:
;   GET Commands: 00000001 - 00001000 (0x01-0x08)
;   SET Commands: 10xxxxxx (Curtain Frac), 11xxxxxx (Curtain Int)
;==============================================================================
UART_CMD_HANDLER:
    ;--------------------------------------------------------------------------
    ; STEP 1: Check for SET commands first (top 2 bits)
    ; SET Curtain Fractional: 10xxxxxx (0x80-0xBF)
    ; SET Curtain Integer:    11xxxxxx (0xC0-0xFF)
    ;--------------------------------------------------------------------------
    BCF     STATUS, 5           ; Ensure Bank 0
    BCF     STATUS, 6
    
    ; Check if top 2 bits are 11 (SET Integer) - Check first since 0xC0 > 0x80
    MOVF    UART_RX_DATA, W
    ANDLW   COMMAND_MASK        ; Mask top 2 bits (0xC0)
    XORLW   SET_CURTAIN_INT_MASK ; Compare with 11xxxxxx (0xC0)
    BTFSC   STATUS, 2           ; Zero flag = match
    GOTO    SET_CURTAIN_INTEGER
    
    ; Check if top 2 bits are 10 (SET Fractional)
    MOVF    UART_RX_DATA, W
    ANDLW   COMMAND_MASK        ; Mask top 2 bits
    XORLW   SET_CURTAIN_FRAC_MASK ; Compare with 10xxxxxx (0x80)
    BTFSC   STATUS, 2           ; Zero flag = match
    GOTO    SET_CURTAIN_FRACTIONAL
    
    ;--------------------------------------------------------------------------
    ; STEP 2: Check GET commands (0x01 - 0x08)
    ;--------------------------------------------------------------------------
    
    ; CMD_GET_CURTAIN_FRAC (0x01): Send Curtain Fractional
    MOVF    UART_RX_DATA, W
    XORLW   CMD_GET_CURTAIN_FRAC
    BTFSC   STATUS, 2
    GOTO    SEND_CURTAIN_FRAC
    
    ; CMD_GET_CURTAIN_INT (0x02): Send Curtain Integer
    MOVF    UART_RX_DATA, W
    XORLW   CMD_GET_CURTAIN_INT
    BTFSC   STATUS, 2
    GOTO    SEND_CURTAIN_INT
    
    ; CMD_GET_TEMP_FRAC (0x03): Send Temperature Fractional
    MOVF    UART_RX_DATA, W
    XORLW   CMD_GET_TEMP_FRAC
    BTFSC   STATUS, 2
    GOTO    SEND_TEMP_FRAC
    
    ; CMD_GET_TEMP_INT (0x04): Send Temperature Integer
    MOVF    UART_RX_DATA, W
    XORLW   CMD_GET_TEMP_INT
    BTFSC   STATUS, 2
    GOTO    SEND_TEMP_INT
    
    ; CMD_GET_PRESS_FRAC (0x05): Send Pressure Fractional
    MOVF    UART_RX_DATA, W
    XORLW   CMD_GET_PRESS_FRAC
    BTFSC   STATUS, 2
    GOTO    SEND_PRESS_FRAC
    
    ; CMD_GET_PRESS_INT (0x06): Send Pressure Integer
    MOVF    UART_RX_DATA, W
    XORLW   CMD_GET_PRESS_INT
    BTFSC   STATUS, 2
    GOTO    SEND_PRESS_INT
    
    ; CMD_GET_LIGHT_FRAC (0x07): Send Light Fractional
    MOVF    UART_RX_DATA, W
    XORLW   CMD_GET_LIGHT_FRAC
    BTFSC   STATUS, 2
    GOTO    SEND_LIGHT_FRAC
    
    ; CMD_GET_LIGHT_INT (0x08): Send Light Integer
    MOVF    UART_RX_DATA, W
    XORLW   CMD_GET_LIGHT_INT
    BTFSC   STATUS, 2
    GOTO    SEND_LIGHT_INT
    
    ; CMD_SET_AUTO_MODE (0x09): Switch to Auto mode (pot control)
    MOVF    UART_RX_DATA, W
    XORLW   0x09
    BTFSC   STATUS, 2
    GOTO    SET_AUTO_MODE
    
    RETURN                      ; Unknown command, ignore

;------------------------------------------------------------------------------
; SET Command Handlers - Extract 6-bit value and store
;------------------------------------------------------------------------------

; SET Curtain Integer: 11xxxxxx -> Extract lower 6 bits
; Scales 0-63 to 0-100% (multiply by 2, cap at 100)
; Sets SYSTEM_MODE to Manual so pot doesn't override UART target
SET_CURTAIN_INTEGER:
    BCF     STATUS, 5           ; Ensure Bank 0
    BCF     STATUS, 6
    MOVF    UART_RX_DATA, W
    ANDLW   0x3F                ; Mask to get lower 6 bits only (0-63)
    ; Scale 0-63 to 0-100: multiply by 2, then cap at 100
    MOVWF   MATH_TEMP
    BCF     STATUS, 0           ; Clear carry for rotation
    RLF     MATH_TEMP, W        ; W = value * 2 (0-126)
    ; Cap at 100
    MOVWF   CURTAIN_TARGET_INT
    SUBLW   100                 ; W = 100 - target
    BTFSS   STATUS, 0           ; Skip if target <= 100
    GOTO    SET_CURT_CAP        ; Target > 100, cap it
    GOTO    SET_CURT_DONE
SET_CURT_CAP:
    MOVLW   100
    MOVWF   CURTAIN_TARGET_INT
SET_CURT_DONE:
    MOVF    CURTAIN_TARGET_INT, W
    MOVWF   CURTAIN_TARGET
    BSF     SYSTEM_MODE, 0      ; Switch to manual mode
    RETURN
; SET Curtain Fractional: 10xxxxxx -> Extract lower 6 bits
SET_CURTAIN_FRACTIONAL:
    MOVF    UART_RX_DATA, W
    ANDLW   VALUE_MASK          ; Mask to get lower 6 bits (0-63)
    MOVWF   CURTAIN_TARGET_FRAC ; Store as target fractional
    RETURN

; SET Auto Mode (0x09): Return to pot/auto control
SET_AUTO_MODE:
    BCF     SYSTEM_MODE, 0      ; Clear manual mode, return to auto
    RETURN

;------------------------------------------------------------------------------
; GET Command Handlers - Send single byte response
;------------------------------------------------------------------------------

; Send Desired Curtain Fractional [R2.2.6: Get desired curtain status]
SEND_CURTAIN_FRAC:
    MOVF    CURTAIN_POS_FRAC, W     ; CURRENT position (actual)
    CALL    UART_TRANSMIT
    RETURN

; Send Desired Curtain Integer [R2.2.6: Get desired curtain status]
SEND_CURTAIN_INT:
    MOVF    CURTAIN_POS_INT, W      ; CURRENT position (actual)
    CALL    UART_TRANSMIT
    RETURN

; Send Temperature Fractional
SEND_TEMP_FRAC:
    MOVF    TEMP_FRAC, W
    CALL    UART_TRANSMIT
    RETURN

; Send Temperature Integer
SEND_TEMP_INT:
    MOVF    TEMP_INT, W
    CALL    UART_TRANSMIT
    RETURN

; Send Pressure Fractional
SEND_PRESS_FRAC:
    MOVF    PRESS_FRAC, W
    CALL    UART_TRANSMIT
    RETURN

; Send Pressure Integer
SEND_PRESS_INT:
    MOVF    PRESS_INT, W
    CALL    UART_TRANSMIT
    RETURN

; Send Light Fractional
SEND_LIGHT_FRAC:
    MOVF    LIGHT_FRAC, W
    CALL    UART_TRANSMIT
    RETURN

; Send Light Integer
SEND_LIGHT_INT:
    MOVF    LIGHT_INT, W
    CALL    UART_TRANSMIT
    RETURN

;==============================================================================
; UART_TRANSMIT - Send byte via UART
; Purpose: Transmit single byte over serial port
; Input:   W = byte to transmit
; Output:  Byte sent to PC
;==============================================================================
UART_TRANSMIT:
    MOVWF   MATH_TEMP           ; Save byte to send
UART_WAIT_TX:
    BSF     STATUS, 5           ; Bank 1
    BTFSS   TXSTA, 1            ; Check TRMT (Transmit Shift Register Empty)
    GOTO    UART_WAIT_TX        ; Wait if busy
    BCF     STATUS, 5           ; Bank 0
    MOVF    MATH_TEMP, W
    MOVWF   TXREG               ; Send byte
    RETURN

;==============================================================================
; ADC_TO_PERCENT - Convert ADC value to percentage
; Purpose: Scale 8-bit ADC reading (0-255) to percentage (0-100)
; Input:   W = ADC value (0-255)
; Output:  W = Percentage (0-100)
; Method:  Approximation of (ADC * 100) / 255
;==============================================================================
ADC_TO_PERCENT:
    ; Converts ADC value (0-255) to percentage (0-100)
    ; Uses alternating subtraction of 2 and 3 for accurate 2.55 average
    ; Pattern: -3, -2, -3, -2, -3 (every 5 iterations = 13 counts = 5%)
    MOVWF   NUM_TEMP            ; Save ADC value
    CLRF    MATH_TEMP           ; Clear result (percentage)
    CLRF    LCD_TEMP            ; Use as toggle counter (0-4)
    
    ; Check for zero
    MOVF    NUM_TEMP, F
    BTFSC   STATUS, 2           ; Zero?
    RETLW   0
    
    ; Check for maximum (>= 250 -> 100%)
    MOVLW   250
    SUBWF   NUM_TEMP, W
    BTFSC   STATUS, 0           ; Carry set if >= 250
    RETLW   100
    
    ; Main scaling loop: alternating subtract 3,2,3,2,3 pattern
    ; Average per 5 iterations: (3+2+3+2+3)/5 = 2.6 ? 2.55
ADC_SCALE_LOOP:
    ; Determine whether to subtract 2 or 3 based on LCD_TEMP
    ; Pattern: 0->3, 1->2, 2->3, 3->2, 4->3, then reset
    MOVF    LCD_TEMP, W
    ANDLW   0x01                ; Check if odd or even
    BTFSC   STATUS, 2           ; Zero = even (0,2,4) -> subtract 3
    GOTO    ADC_SUB_3
    GOTO    ADC_SUB_2

ADC_SUB_3:
    ; Check if NUM_TEMP >= 3
    MOVLW   3
    SUBWF   NUM_TEMP, W
    BTFSS   STATUS, 0           ; Carry set if >= 3
    GOTO    ADC_SCALE_DONE      ; Less than 3 remaining, done
    MOVWF   NUM_TEMP            ; NUM_TEMP = NUM_TEMP - 3
    GOTO    ADC_INC_PERCENT

ADC_SUB_2:
    ; Check if NUM_TEMP >= 2
    MOVLW   2
    SUBWF   NUM_TEMP, W
    BTFSS   STATUS, 0           ; Carry set if >= 2
    GOTO    ADC_SCALE_DONE      ; Less than 2 remaining, done
    MOVWF   NUM_TEMP            ; NUM_TEMP = NUM_TEMP - 2

ADC_INC_PERCENT:
    INCF    MATH_TEMP, F        ; Add 1%
    
    ; Update toggle counter (0-4 cycle)
    INCF    LCD_TEMP, F
    MOVLW   5
    SUBWF   LCD_TEMP, W
    BTFSC   STATUS, 2           ; Reset at 5?
    CLRF    LCD_TEMP
    
    ; Limit check
    MOVLW   100
    SUBWF   MATH_TEMP, W
    BTFSC   STATUS, 0           ; Reached 100%?
    GOTO    ADC_SCALE_MAX
    GOTO    ADC_SCALE_LOOP

ADC_SCALE_DONE:
    ; Add 1 more if remaining >= 1 (for better precision)
    MOVF    NUM_TEMP, F
    BTFSC   STATUS, 2           ; Zero remaining?
    GOTO    ADC_RETURN_RESULT
    INCF    MATH_TEMP, F        ; Add 1% for remainder
    
ADC_RETURN_RESULT:
    ; Ensure result doesn't exceed 100
    MOVLW   100
    SUBWF   MATH_TEMP, W
    BTFSC   STATUS, 0
    RETLW   100
    MOVF    MATH_TEMP, W
    RETURN

ADC_SCALE_MAX:
    RETLW   100

;==============================================================================
; ADC_READ_POT - Read Potentiometer (AN1)
; ADC_READ_LDR - Read Light Sensor (AN0)
; Purpose: Read analog channel and return direct ADC value (PICSimLab compatible)
; Output:  W = Direct ADC value (0-255)
;==============================================================================
ADC_READ_POT:
    ; Select AN1 channel
    BCF     ADCON0, 5           ; CHS2 = 0
    BCF     ADCON0, 4           ; CHS1 = 0
    BSF     ADCON0, 3           ; CHS0 = 1 (AN1)
    BSF     ADCON0, 0           ; ADON = 1
    CALL    DELAY_20US          ; Acquisition time
    BSF     ADCON0, 2           ; Start conversion
ADC_POT_WAIT:
    BTFSC   ADCON0, 2           ; Wait for conversion
    GOTO    ADC_POT_WAIT
    MOVF    ADRESH, W           ; Direct ADC value (PICSimLab compatible)
    RETURN

ADC_READ_LDR:
    ; Select AN0 channel
    BCF     ADCON0, 5           ; CHS2 = 0
    BCF     ADCON0, 4           ; CHS1 = 0
    BCF     ADCON0, 3           ; CHS0 = 0 (AN0)
    BSF     ADCON0, 0           ; ADON = 1
    CALL    DELAY_20US          ; Acquisition time
    BSF     ADCON0, 2           ; Start conversion
ADC_LDR_WAIT:
    BTFSC   ADCON0, 2           ; Wait for conversion
    GOTO    ADC_LDR_WAIT
    MOVF    ADRESH, W           ; Get raw ADC value
    SUBLW   255                 ; Invert: bright=high%, dark=low%
    RETURN

; Delay for ADC acquisition time (~20?s @ 20MHz)
DELAY_20US:
    MOVLW   10
    MOVWF   DELAY_CNT_X
ADC_DELAY_LOOP:
    DECFSZ  DELAY_CNT_X, F
    GOTO    ADC_DELAY_LOOP
    RETURN

;==============================================================================
; BMP180_READ - Read Temperature and Pressure (DISABLED)
; Purpose: Interface with BMP180 sensor via I2C
; Note:    SimulIDE doesn't support BMP180, so this is commented out
;          Default values (25.0?C, 1013 hPa) are used instead
;==============================================================================
; BMP180_READ:
;     ; Send temperature read command via I2C
;     CALL    I2C_START
;     MOVLW   0xEE            ; BMP180 Write Address
;     CALL    I2C_WRITE
;     MOVLW   0xF4            ; Control Register
;     CALL    I2C_WRITE
;     MOVLW   0x2E            ; Temperature Read Command
;     CALL    I2C_WRITE
;     CALL    I2C_STOP
;     
;     CALL    DELAY_10MS      ; Wait for conversion
;     
;     ; Read temperature result
;     CALL    I2C_START
;     MOVLW   0xEE
;     CALL    I2C_WRITE
;     MOVLW   0xF6            ; Data Register
;     CALL    I2C_WRITE
;     CALL    I2C_RESTART
;     MOVLW   0xEF            ; BMP180 Read Address
;     CALL    I2C_WRITE
;     CALL    I2C_READ
;     MOVWF   TEMP_INT
;     CALL    I2C_NACK
;     CALL    I2C_STOP
;     
;     ; Read pressure (similar procedure)...
;     RETURN


;==============================================================================
; I2C SUBROUTINES (DISABLED - FOR BMP180 SUPPORT)
; These routines implement I2C Master mode communication
; Uncomment to enable I2C functionality with BMP180 sensor
;==============================================================================

; I2C_START - Generate I2C Start Condition
; I2C_START:
;     BCF     STATUS, RP0         ; Bank 0
;     BSF     SSPCON2, SEN        ; Initiate Start condition
; I2C_START_WAIT:
;     BTFSC   SSPCON2, SEN        ; Wait for Start to complete
;     GOTO    I2C_START_WAIT
;     RETURN

; I2C_STOP - Generate I2C Stop Condition
; I2C_STOP:
;     BCF     STATUS, RP0         ; Bank 0
;     BSF     SSPCON2, PEN        ; Initiate Stop condition
; I2C_STOP_WAIT:
;     BTFSC   SSPCON2, PEN        ; Wait for Stop to complete
;     GOTO    I2C_STOP_WAIT
;     RETURN

; I2C_RESTART - Generate I2C Repeated Start Condition
; I2C_RESTART:
;     BCF     STATUS, RP0         ; Bank 0
;     BSF     SSPCON2, RSEN       ; Initiate Repeated Start
; I2C_RESTART_WAIT:
;     BTFSC   SSPCON2, RSEN       ; Wait for Restart to complete
;     GOTO    I2C_RESTART_WAIT
;     RETURN

; I2C_WRITE - Write byte to I2C bus
; Input: W register contains byte to send
; I2C_WRITE:
;     BCF     STATUS, RP0         ; Bank 0
;     MOVWF   SSPBUF              ; Load data to transmit
; I2C_WRITE_WAIT:
;     BSF     STATUS, RP0         ; Bank 1
;     BTFSS   SSPSTAT, 0          ; BF - Buffer Full flag, wait for transmit
;     GOTO    I2C_WRITE_WAIT
;     BCF     STATUS, RP0         ; Bank 0
;     BTFSC   SSPCON2, ACKSTAT    ; Check for ACK from slave
;     GOTO    I2C_ERROR           ; NACK received, handle error
;     RETURN

; I2C_READ - Read byte from I2C bus
; Output: W register contains received byte
; I2C_READ:
;     BCF     STATUS, RP0         ; Bank 0
;     BSF     SSPCON2, RCEN       ; Enable Receive mode
; I2C_READ_WAIT:
;     BTFSC   SSPCON2, RCEN       ; Wait for receive to complete
;     GOTO    I2C_READ_WAIT
;     MOVF    SSPBUF, W           ; Read received byte
;     MOVWF   I2C_BUFFER          ; Store in buffer
;     RETURN

; I2C_ACK - Send Acknowledge to slave
; I2C_ACK:
;     BCF     STATUS, RP0         ; Bank 0
;     BCF     SSPCON2, ACKDT      ; ACK data = 0 (ACK)
;     BSF     SSPCON2, ACKEN      ; Initiate ACK sequence
; I2C_ACK_WAIT:
;     BTFSC   SSPCON2, ACKEN      ; Wait for ACK to complete
;     GOTO    I2C_ACK_WAIT
;     RETURN

; I2C_NACK - Send Not Acknowledge to slave
; I2C_NACK:
;     BCF     STATUS, RP0         ; Bank 0
;     BSF     SSPCON2, ACKDT      ; ACK data = 1 (NACK)
;     BSF     SSPCON2, ACKEN      ; Initiate NACK sequence
; I2C_NACK_WAIT:
;     BTFSC   SSPCON2, ACKEN      ; Wait for NACK to complete
;     GOTO    I2C_NACK_WAIT
;     RETURN

; I2C_ERROR - Handle I2C communication error
; I2C_ERROR:
;     ; Set error flag or retry logic here
;     CALL    I2C_STOP            ; Send stop to release bus
;     RETURN

;==============================================================================
; LCD DRIVER SUBROUTINES
; 4-bit mode interface for HD44780-compatible LCD
; RE0 = RS (Register Select), RE1 = EN (Enable)
; RD0-RD3 = Data bus (4-bit)
;==============================================================================

; LCD_INIT - Initialize LCD in 4-bit mode
LCD_INIT:
    CALL    DELAY_LONG          ; Wait >40ms after power-up
    MOVLW   0x03                ; Function set attempt 1
    CALL    LCD_NIBBLE
    CALL    DELAY_SHORT
    MOVLW   0x03                ; Function set attempt 2
    CALL    LCD_NIBBLE
    CALL    DELAY_SHORT
    MOVLW   0x03                ; Function set attempt 3
    CALL    LCD_NIBBLE
    CALL    DELAY_SHORT
    MOVLW   0x02                ; Switch to 4-bit mode
    CALL    LCD_NIBBLE
    CALL    DELAY_SHORT
    MOVLW   0x28                ; Function set: 4-bit, 2 lines, 5x7 font
    CALL    LCD_SEND_CMD
    MOVLW   0x0C                ; Display control: Display ON, Cursor OFF
    CALL    LCD_SEND_CMD
    MOVLW   0x01                ; Clear display
    CALL    LCD_SEND_CMD
    CALL    DELAY_LONG          ; Wait for clear
    MOVLW   0x06                ; Entry mode: Increment, No shift
    CALL    LCD_SEND_CMD
    RETURN

; LCD_SEND_CMD - Send command to LCD
LCD_SEND_CMD:
    MOVWF   LCD_TEMP
    BCF     PORTE, 0            ; RS = 0 (Command mode)
    SWAPF   LCD_TEMP, W         ; Send high nibble first
    ANDLW   0x0F
    CALL    LCD_NIBBLE
    MOVF    LCD_TEMP, W         ; Send low nibble
    ANDLW   0x0F
    CALL    LCD_NIBBLE
    CALL    DELAY_SHORT
    RETURN

; LCD_SEND_DATA - Send data (character) to LCD
LCD_SEND_DATA:
    MOVWF   LCD_TEMP
    BSF     PORTE, 0            ; RS = 1 (Data mode)
    SWAPF   LCD_TEMP, W         ; Send high nibble
    ANDLW   0x0F
    CALL    LCD_NIBBLE
    MOVF    LCD_TEMP, W         ; Send low nibble
    ANDLW   0x0F
    CALL    LCD_NIBBLE
    CALL    DELAY_SHORT
    RETURN

; LCD_NIBBLE - Send 4-bit nibble to LCD
LCD_NIBBLE:
    MOVWF   MATH_TEMP           ; Use MATH_TEMP instead of NUM_TEMP
    MOVLW   0xF0                ; Preserve upper nibble of PORTD
    ANDWF   PORTD, F
    MOVF    MATH_TEMP, W
    IORWF   PORTD, F            ; Write data to lower nibble
    BSF     PORTE, 1            ; EN = 1 (Enable pulse)
    NOP
    NOP
    BCF     PORTE, 1            ; EN = 0
    RETURN

;==============================================================================
; DISPLAY SUBROUTINES
;==============================================================================

; DISPLAY_2DIGIT - Display 2-digit number (00-99)
; Input: W = number to display (0-99)
; Output: Sends two ASCII digits to LCD
DISPLAY_2DIGIT:
    MOVWF   NUM_TEMP             ; Save input number
    CLRF    DIGIT_10             ; Clear tens counter
D2_LOOP:
    ; Repeatedly subtract 10 to extract tens digit
    MOVLW   10
    SUBWF   NUM_TEMP, W          ; W = NUM_TEMP - 10
    BTFSS   STATUS, 0            ; Carry set if result >= 0
    GOTO    D2_DISPLAY           ; No more tens, display digits
    MOVWF   NUM_TEMP             ; Store remainder
    INCF    DIGIT_10, F          ; Increment tens counter
    GOTO    D2_LOOP
D2_DISPLAY:
    ; Display tens digit
    MOVF    DIGIT_10, W
    ADDLW   '0'                  ; Convert to ASCII
    CALL    LCD_SEND_DATA
    ; Display units digit (remainder)
    MOVF    NUM_TEMP, W
    ADDLW   '0'                  ; Convert to ASCII
    CALL    LCD_SEND_DATA
    RETURN

; DISPLAY_3DIGIT - Display 3-digit number (000-999)
; Input: W = number to display (0-999)
; Output: Sends three ASCII digits to LCD
DISPLAY_3DIGIT:
    MOVWF   NUM_TEMP             ; Save input number
    CLRF    DIGIT_100            ; Clear hundreds counter
    CLRF    DIGIT_10             ; Clear tens counter
D3_100:
    ; Extract hundreds digit by repeated subtraction
    MOVLW   100
    SUBWF   NUM_TEMP, W          ; W = NUM_TEMP - 100
    BTFSS   STATUS, 0            ; Carry set if result >= 0
    GOTO    D3_10                ; No more hundreds, extract tens
    MOVWF   NUM_TEMP             ; Store remainder
    INCF    DIGIT_100, F         ; Increment hundreds counter
    GOTO    D3_100
D3_10:
    ; Extract tens digit by repeated subtraction
    MOVLW   10
    SUBWF   NUM_TEMP, W          ; W = NUM_TEMP - 10
    BTFSS   STATUS, 0            ; Carry set if result >= 0
    GOTO    D3_DISPLAY           ; No more tens, display digits
    MOVWF   NUM_TEMP             ; Store remainder
    INCF    DIGIT_10, F          ; Increment tens counter
    GOTO    D3_10
D3_DISPLAY:
    ; Display hundreds digit
    MOVF    DIGIT_100, W
    ADDLW   '0'                  ; Convert to ASCII
    CALL    LCD_SEND_DATA
    ; Display tens digit
    MOVF    DIGIT_10, W
    ADDLW   '0'                  ; Convert to ASCII
    CALL    LCD_SEND_DATA
    ; Display units digit (remainder)
    MOVF    NUM_TEMP, W
    ADDLW   '0'                  ; Convert to ASCII
    CALL    LCD_SEND_DATA
    RETURN

;==============================================================================
; DELAY SUBROUTINES
;==============================================================================

; DELAY_SHORT - Short delay (~100us @ 20MHz)
; Used for LCD command timing
; Delay = 50 * 4 cycles * 200ns = ~40us
DELAY_SHORT:
    MOVLW   50                   ; Load loop counter
    MOVWF   DELAY_CNT_X
DS_LOOP:
    DECFSZ  DELAY_CNT_X, F       ; Decrement and skip if zero
    GOTO    DS_LOOP              ; Continue loop
    RETURN

; Orphan loop (not used, kept for compatibility)
DL_LOOP:
    DECFSZ  DELAY_CNT_X, F
    GOTO    DL_LOOP
    RETURN

; DELAY_10MS - 10ms delay for I2C operations
; Calls DELAY_LONG 20 times: 20 * ~500us = ~10ms
DELAY_10MS:
    MOVLW   20                   ; Outer loop counter
    MOVWF   DELAY_CNT_Y
D10_LOOP:
    CALL    DELAY_LONG           ; ~500us delay
    DECFSZ  DELAY_CNT_Y, F       ; Decrement outer counter
    GOTO    D10_LOOP
    RETURN

;==============================================================================
; DELAY ROUTINES - ACTIVE VERSIONS
;==============================================================================

; DS_L_FIX - Alternate short delay loop (legacy)
DS_L_FIX:
    DECFSZ  DELAY_CNT_X, F
    GOTO    DS_L_FIX
    RETURN

; DELAY_LONG - Long delay (~500us @ 20MHz)
; Used for LCD initialization and motor timing
; Delay = 250 * 4 cycles * 200ns = ~200us (plus call overhead)
DELAY_LONG:
    MOVLW   250                  ; Load loop counter
    MOVWF   DELAY_CNT_X
DL_L_FIX:
    DECFSZ  DELAY_CNT_X, F       ; Decrement and skip if zero
    GOTO    DL_L_FIX             ; Continue loop
    RETURN

; D10_L_FIX - Alternate 10ms delay loop (legacy)
D10_L_FIX:
    CALL    DELAY_LONG
    DECFSZ  DELAY_CNT_Y, F
    GOTO    D10_L_FIX
    RETURN

; DELAY_MOTOR - Motor step delay (~4ms @ 20MHz)
; Provides settling time between stepper motor phases
; Delay = 8 * DELAY_LONG = 8 * ~500us = ~4ms
; This controls motor speed: slower delay = slower motor
DELAY_MOTOR:
    MOVLW   8                    ; Outer loop counter (8 iterations)
    MOVWF   DELAY_CNT_Y
DM_L_FIX:
    CALL    DELAY_LONG           ; ~500us delay
    DECFSZ  DELAY_CNT_Y, F       ; Decrement outer counter
    GOTO    DM_L_FIX             ; Continue loop
    RETURN

    END