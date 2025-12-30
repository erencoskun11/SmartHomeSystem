; PROJECT: Smart Home System (Board 1 - Climate)
; AUTHOR: Meryem Dinç

; DESCRIPTION:
;   Heating/Cooling control system with:
;   - 4x4 Keypad for temperature input (10-50Â°C)
;   - 4-digit 7-segment display
;   - UART communication with PC
;   - Hysteresis control to prevent rapid switching
;
; PIN ASSIGNMENTS:
;   RA0: Temperature sensor (ADC input)
;   RB0-RB3: Keypad rows (output)
;   RB4-RB7: Keypad columns (input)
;   RC0-RC3: 7-segment digit select
;   RC4: Cooler output
;   RC5: Heater output
;   RC7: UART TX
;   RC6: UART RX
;   RD0-RD7: 7-segment data


PROCESSOR 16F877A
#include <xc.inc>

; Config: XT oscillator, WDT off, power-up timer on, brown-out on, LVP off
CONFIG FOSC=XT, WDTE=OFF, PWRTE=ON, BOREN=ON, LVP=OFF
CONFIG CPD=OFF, WRT=OFF, CP=OFF, DEBUG=OFF


; RAM VARIABLES 
delay_counter       EQU 0x20    ; Delay loop counter
display_scan_loop   EQU 0x21    ; Display refresh counter
mode_timer          EQU 0x22    ; Auto mode switch timer
menu_step           EQU 0x23    ; Menu state (0-5)
menu_flag           EQU 0x24    ; Menu activation flag
update_flag         EQU 0x25    ; UART sync flag
temp_ambient        EQU 0x26    ; Current room temp
temp_target_total   EQU 0x27    ; Target temp (rounded)
temp_target_int     EQU 0x28    ; Target integer (10-50)
temp_target_frac    EQU 0x29    ; Target decimal (0-9)
fan_status          EQU 0x2A    ; Fan state (0/5)
disp_tens           EQU 0x2B    ; Display tens digit
disp_ones           EQU 0x2C    ; Display ones digit
disp_decimal1       EQU 0x2D    ; Display decimal 1
disp_decimal2       EQU 0x2E    ; Display decimal 2
display_mode        EQU 0x2F    ; 0=target, 1=ambient, 2=fan
segment_code        EQU 0x30    ; Temp for segment lookup
key_last_pressed    EQU 0x31    ; Last key (0xFF=none)
input_tens          EQU 0x32    ; User input tens
input_ones          EQU 0x33    ; User input ones
input_decimal       EQU 0x34    ; User input decimal
uart_rx_data        EQU 0x35    ; UART received byte
uart_temp_int       EQU 0x36    ; UART temp integer
uart_temp_frac      EQU 0x37    ; UART temp fraction
hvac_state          EQU 0x38    ; 0=idle, 1=heat, 2=cool
hyst_temp           EQU 0x39    ; Hysteresis temp
KEY_A       EQU 0xA0            ; A key value
KEY_STAR    EQU 0xB0            ; * key value
KEY_HASH    EQU 0xC0            ; # key value
KEY_NONE    EQU 0xFF            ; No key pressed

PSECT resetVec, class=CODE, delta=2
    ORG 0x00
    GOTO SYSTEM_START

PSECT code



; Main entry point. Initializes hardware and variables,
;then enters the main loop.
SYSTEM_START:
    CALL SYSTEM_INIT
    CALL UART_INIT
    
    MOVLW 24                    ; Default target: 24C
    MOVWF temp_target_total
    MOVWF temp_target_int
    CLRF temp_target_frac
    CLRF menu_step
    MOVLW  KEY_NONE
    MOVWF key_last_pressed
    CLRF display_mode
    CLRF mode_timer
    CLRF menu_flag
    CLRF update_flag
    CLRF hvac_state


;     Continuously runs system tasks:
;              1. Check UART for commands
;              2. Scan keypad for input
;              3. Read temperature from ADC
;              4. Control heater/cooler based on temperature
;              5. Update 7-segment display
SYSTEM_MAIN_LOOP:
    MOVF menu_flag, F
    BTFSS STATUS, 2
    CALL KEYPAD_RESET_MENU
    
    CALL UART_CHECK_DATA
    CALL KEYPAD_CHECK_MAIN
    CALL ADC_READ_AMBIENT
    CALL FAN_STATUS_CHECK


    MOVF hvac_state, W
    SUBLW 1
    BTFSC STATUS, 2
    GOTO HYSTERESIS_HEATING_CHECK
    
    MOVF hvac_state, W
    SUBLW 2
    BTFSC STATUS, 2
    GOTO HYSTERESIS_COOLING_CHECK
    
    GOTO HYSTERESIS_IDLE_CHECK


;When HVAC is idle, checks if heating or cooling
;is needed by comparing ambient vs target temp.

HYSTERESIS_IDLE_CHECK:
    MOVF temp_target_total, W
    SUBWF temp_ambient, W
    BTFSS STATUS, 0
    GOTO TEMP_HEATER_ON
    
    MOVF temp_ambient, W
    SUBWF temp_target_total, W
    BTFSS STATUS, 0
    GOTO TEMP_COOLER_ON
    
    GOTO TEMP_ALL_OFF



;While heating, continues until ambient reaches
;(target - 1) to prevent rapid on/off switching.

HYSTERESIS_HEATING_CHECK:
    MOVF temp_target_total, W
    MOVWF hyst_temp
    DECF hyst_temp, F
    MOVF hyst_temp, W
    SUBWF temp_ambient, W
    BTFSC STATUS, 0
    GOTO TEMP_STOP_HEATING
    GOTO TEMP_HEATER_CONTINUE


; Description: While cooling, continues until ambient falls
;              to target temperature.

HYSTERESIS_COOLING_CHECK:
    MOVF temp_ambient, W
    SUBWF temp_target_total, W
    BTFSC STATUS, 0
    GOTO TEMP_STOP_COOLING
    GOTO TEMP_COOLER_CONTINUE

; Turn on heater (RC5)
TEMP_HEATER_ON:
    MOVLW 1
    MOVWF hvac_state
TEMP_HEATER_CONTINUE:
    BSF PORTC, 5
    BCF PORTC, 4
    GOTO DISPLAY_MODE_SELECT

; Turn on cooler (RC4)
TEMP_COOLER_ON:
    MOVLW 2
    MOVWF hvac_state
TEMP_COOLER_CONTINUE:
    BCF PORTC, 5
    BSF PORTC, 4
    DECF temp_ambient, F
    GOTO DISPLAY_MODE_SELECT

; Turn off both
TEMP_STOP_HEATING:
TEMP_STOP_COOLING:
TEMP_ALL_OFF:
    CLRF hvac_state
    BCF PORTC, 5
    BCF PORTC, 4


; Selects what to show on display based on mode:
;   Mode 0: Target temperature
;   Mode 1: Ambient temperature
;   Mode 2: Fan status
; If in menu, shows user input instead.

DISPLAY_MODE_SELECT:
    MOVF menu_step, F
    BTFSS STATUS, 2
    GOTO DISPLAY_SHOW_MENU
    
    MOVF display_mode, W
    XORLW 0
    BTFSC STATUS, 2
    GOTO DISPLAY_PREP_TARGET
    MOVF display_mode, W
    XORLW 1
    BTFSC STATUS, 2
    GOTO DISPLAY_PREP_AMBIENT
    GOTO DISPLAY_PREP_FAN

DISPLAY_PREP_TARGET:
    MOVF temp_target_int, W
    CALL DISPLAY_CONVERT_BCD
    MOVF temp_target_frac, W
    MOVWF disp_decimal1
    CLRF disp_decimal2
    GOTO DISPLAY_PROCESS_DATA

DISPLAY_PREP_AMBIENT:
    MOVF temp_ambient, W
    CALL DISPLAY_CONVERT_BCD
    CLRF disp_decimal1
    CLRF disp_decimal2
    GOTO DISPLAY_PROCESS_DATA

DISPLAY_PREP_FAN:
    MOVF fan_status, W
    CALL DISPLAY_CONVERT_BCD
    CLRF disp_decimal1
    CLRF disp_decimal2
    GOTO DISPLAY_PROCESS_DATA

DISPLAY_SHOW_MENU:
    MOVF menu_step, W
    XORLW 1
    BTFSC STATUS, 2
    GOTO DISPLAY_SHOW_DASHES
    
    MOVF input_tens, W
    MOVWF disp_tens
    MOVF input_ones, W
    MOVWF disp_ones
    MOVF input_decimal, W
    MOVWF disp_decimal1
    CLRF disp_decimal2
    GOTO DISPLAY_PROCESS_DATA

DISPLAY_SHOW_DASHES:
    MOVLW 10
    MOVWF disp_tens
    MOVWF disp_ones
    MOVWF disp_decimal1
    MOVWF disp_decimal2


;  Multiplexes 4-digit 7-segment display.
;   Each digit is lit briefly in sequence to create
;  the illusion of all digits being on simultaneously.
;   Also handles automatic display mode cycling.

DISPLAY_PROCESS_DATA:
    MOVLW 5
    MOVWF display_scan_loop
DISPLAY_REFRESH_LOOP:
    ; Digit 4 (rightmost)
    MOVF disp_decimal2, W
    CALL DISPLAY_GET_SEGMENT
    MOVWF PORTD
    BSF PORTC, 3
    CALL DISPLAY_MUX_DELAY
    BCF PORTC, 3
    
    ; Digit 3
    MOVF disp_decimal1, W
    CALL DISPLAY_GET_SEGMENT
    MOVWF PORTD
    BSF PORTC, 2
    CALL DISPLAY_MUX_DELAY
    BCF PORTC, 2
    
    ; Digit 2 with decimal point
    MOVF disp_ones, W
    CALL DISPLAY_GET_SEGMENT
    IORLW 10000000B
    MOVWF PORTD
    BSF PORTC, 1
    CALL DISPLAY_MUX_DELAY
    BCF PORTC, 1
    
    ; Digit 1 (leftmost)
    MOVF disp_tens, W
    CALL DISPLAY_GET_SEGMENT
    MOVWF PORTD
    BSF PORTC, 0
    CALL DISPLAY_MUX_DELAY
    BCF PORTC, 0
    
    DECFSZ display_scan_loop, F
    GOTO DISPLAY_REFRESH_LOOP

    ; Auto-cycle display mode every 100 loops
    MOVF menu_step, F
    BTFSS STATUS, 2
    GOTO SYSTEM_SKIP_CYCLE
    INCF mode_timer, F
    MOVLW 100
    SUBWF mode_timer, W
    BTFSS STATUS, 2
    GOTO SYSTEM_SKIP_CYCLE
    CLRF mode_timer
    INCF display_mode, F
    MOVLW 3
    SUBWF display_mode, W
    BTFSC STATUS, 2
    CLRF display_mode
SYSTEM_SKIP_CYCLE:
    GOTO SYSTEM_MAIN_LOOP


;Converts binary value (0-99) to BCD format.
; Input:  W register = binary value
; Output: disp_tens = tens digit, disp_ones = ones digit
; Method: Successive subtraction (divides by 10)

DISPLAY_CONVERT_BCD:
    MOVWF disp_ones
    CLRF disp_tens
    
    MOVLW 90
    SUBWF disp_ones, W
    BTFSS STATUS, 0
    GOTO BCD_CHECK_80
    MOVLW 9
    MOVWF disp_tens
    MOVLW 90
    SUBWF disp_ones, F
    RETURN

BCD_CHECK_80:
    MOVLW 80
    SUBWF disp_ones, W
    BTFSS STATUS, 0
    GOTO BCD_CHECK_70
    MOVLW 8
    MOVWF disp_tens
    MOVLW 80
    SUBWF disp_ones, F
    RETURN

BCD_CHECK_70:
    MOVLW 70
    SUBWF disp_ones, W
    BTFSS STATUS, 0
    GOTO BCD_CHECK_60
    MOVLW 7
    MOVWF disp_tens
    MOVLW 70
    SUBWF disp_ones, F
    RETURN

BCD_CHECK_60:
    MOVLW 60
    SUBWF disp_ones, W
    BTFSS STATUS, 0
    GOTO BCD_CHECK_50
    MOVLW 6
    MOVWF disp_tens
    MOVLW 60
    SUBWF disp_ones, F
    RETURN

BCD_CHECK_50:
    MOVLW 50
    SUBWF disp_ones, W
    BTFSS STATUS, 0
    GOTO BCD_CHECK_40
    MOVLW 5
    MOVWF disp_tens
    MOVLW 50
    SUBWF disp_ones, F
    RETURN

BCD_CHECK_40:
    MOVLW 40
    SUBWF disp_ones, W
    BTFSS STATUS, 0
    GOTO BCD_CHECK_30
    MOVLW 4
    MOVWF disp_tens
    MOVLW 40
    SUBWF disp_ones, F
    RETURN

BCD_CHECK_30:
    MOVLW 30
    SUBWF disp_ones, W
    BTFSS STATUS, 0
    GOTO BCD_CHECK_20
    MOVLW 3
    MOVWF disp_tens
    MOVLW 30
    SUBWF disp_ones, F
    RETURN

BCD_CHECK_20:
    MOVLW 20
    SUBWF disp_ones, W
    BTFSS STATUS, 0
    GOTO BCD_CHECK_10
    MOVLW 2
    MOVWF disp_tens
    MOVLW 20
    SUBWF disp_ones, F
    RETURN

BCD_CHECK_10:
    MOVLW 10
    SUBWF disp_ones, W
    BTFSS STATUS, 0
    RETURN
    MOVLW 1
    MOVWF disp_tens
    MOVLW 10
    SUBWF disp_ones, F
    RETURN


; Resets menu to initial state (step 1).
; Clears all input values and shows dashes on display.

KEYPAD_RESET_MENU:
    MOVLW 1
    MOVWF menu_step
    CLRF input_tens
    CLRF input_ones
    CLRF input_decimal
    CLRF menu_flag
    RETURN


; Main keypad handler. Scans for key press,
;  processes the key if detected, then resets.

KEYPAD_CHECK_MAIN:
    CALL KEYPAD_SCAN
    MOVF key_last_pressed, W
    XORLW  KEY_NONE
    BTFSC STATUS, 2
    RETURN
    CALL KEYPAD_PROCESS_KEY
    MOVLW  KEY_NONE
    MOVWF key_last_pressed
    RETURN

; Scans 4x4 matrix keypad using row scanning method.
;  Drives each row LOW one at a time and checks columns.
KEYPAD_SCAN:
    MOVLW 0xFF
    MOVWF key_last_pressed
    
    ; Row 4 (RB3 = LOW)
    MOVLW 11110111B
    MOVWF PORTB
    CALL KEYPAD_DEBOUNCE
    BTFSS PORTB, 4
    GOTO KEYPAD_ASSIGN_S
    BTFSS PORTB, 5
    GOTO KEYPAD_ASSIGN_0
    BTFSS PORTB, 6
    GOTO KEYPAD_ASSIGN_H
    BTFSS PORTB, 7
    GOTO KEYPAD_ASSIGN_D
    
    ; Row 3 (RB2 = LOW)
    MOVLW 11111011B
    MOVWF PORTB
    CALL KEYPAD_DEBOUNCE
    BTFSS PORTB, 4
    GOTO KEYPAD_ASSIGN_7
    BTFSS PORTB, 5
    GOTO KEYPAD_ASSIGN_8
    BTFSS PORTB, 6
    GOTO KEYPAD_ASSIGN_9
    BTFSS PORTB, 7
    GOTO KEYPAD_ASSIGN_C
    
    ; Row 2 (RB1 = LOW)
    MOVLW 11111101B
    MOVWF PORTB
    CALL KEYPAD_DEBOUNCE
    BTFSS PORTB, 4
    GOTO KEYPAD_ASSIGN_4
    BTFSS PORTB, 5
    GOTO KEYPAD_ASSIGN_5
    BTFSS PORTB, 6
    GOTO KEYPAD_ASSIGN_6
    BTFSS PORTB, 7
    GOTO KEYPAD_ASSIGN_B
    
    ; Row 1 (RB0 = LOW)
    MOVLW 11111110B
    MOVWF PORTB
    CALL KEYPAD_DEBOUNCE
    BTFSS PORTB, 4
    GOTO KEYPAD_ASSIGN_1
    BTFSS PORTB, 5
    GOTO KEYPAD_ASSIGN_2
    BTFSS PORTB, 6
    GOTO KEYPAD_ASSIGN_3
    BTFSS PORTB, 7
    GOTO KEYPAD_ASSIGN_A
    
    RETURN

; Key value assignments
KEYPAD_ASSIGN_1: MOVLW 1
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_2: MOVLW 2
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_3: MOVLW 3
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_A: 
    MOVLW KEY_A            
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_4: MOVLW 4
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_5: MOVLW 5
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_6: MOVLW 6
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_B: MOVLW 11       
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_7: MOVLW 7
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_8: MOVLW 8
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_9: MOVLW 9
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_C: MOVLW 12       ; C key
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_S: 
    MOVLW KEY_STAR         
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_0: MOVLW 0
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_H: 
    MOVLW KEY_HASH         
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN
KEYPAD_ASSIGN_D: MOVLW 13       ; D key
    MOVWF key_last_pressed
    CALL KEYPAD_WAIT_RELEASE
    RETURN

;Waits until all keys are released.
; Continues refreshing display during wait to
; prevent flickering.

KEYPAD_WAIT_RELEASE:
    MOVLW 48
    MOVWF display_scan_loop
KEYPAD_REL_DELAY:
    MOVF disp_tens, W
    CALL DISPLAY_GET_SEGMENT
    MOVWF PORTD
    BSF PORTC, 0
    CALL DISPLAY_MUX_DELAY
    BCF PORTC, 0
    MOVF disp_ones, W
    CALL DISPLAY_GET_SEGMENT
    IORLW 10000000B
    MOVWF PORTD
    BSF PORTC, 1
    CALL DISPLAY_MUX_DELAY
    BCF PORTC, 1
    MOVF disp_decimal1, W
    CALL DISPLAY_GET_SEGMENT
    MOVWF PORTD
    BSF PORTC, 2
    CALL DISPLAY_MUX_DELAY
    BCF PORTC, 2
    MOVF disp_decimal2, W
    CALL DISPLAY_GET_SEGMENT
    MOVWF PORTD
    BSF PORTC, 3
    CALL DISPLAY_MUX_DELAY
    BCF PORTC, 3
    DECFSZ display_scan_loop, F
    GOTO KEYPAD_REL_DELAY
KEYPAD_REL_CHECK:
    MOVLW 11111111B
    MOVWF PORTB
    CALL KEYPAD_DEBOUNCE
    BTFSS PORTB, 4
    GOTO KEYPAD_REL_CHECK
    BTFSS PORTB, 5
    GOTO KEYPAD_REL_CHECK
    BTFSS PORTB, 6
    GOTO KEYPAD_REL_CHECK
    BTFSS PORTB, 7
    GOTO KEYPAD_REL_CHECK
    RETURN

; Short delay to filter electrical noise from
;  mechanical key switches (debouncing).

KEYPAD_DEBOUNCE:
    MOVLW 8
    MOVWF segment_code
KEYPAD_DEBOUNCE_LOOP:
    NOP
    NOP
    DECFSZ segment_code, F
    GOTO KEYPAD_DEBOUNCE_LOOP
    RETURN

;Processes detected key based on menu state.
KEYPAD_PROCESS_KEY:
    MOVF key_last_pressed, W
    XORLW KEY_A 
    BTFSC STATUS, 2
    GOTO KEYPAD_PROC_A
    MOVF key_last_pressed, W
    XORLW KEY_HASH
    BTFSC STATUS, 2
    GOTO KEYPAD_PROC_CONFIRM
    MOVF key_last_pressed, W
    XORLW KEY_STAR
    BTFSC STATUS, 2
    GOTO KEYPAD_PROC_STAR
    MOVF key_last_pressed, W
    SUBLW 9
    BTFSS STATUS, 0
    RETURN
    MOVF menu_step, F
    BTFSC STATUS, 2
    RETURN
    MOVF menu_step, W
    XORLW 1
    BTFSC STATUS, 2
    GOTO KEYPAD_INPUT_1
    MOVF menu_step, W
    XORLW 2
    BTFSC STATUS, 2
    GOTO KEYPAD_INPUT_2
    MOVF menu_step, W
    XORLW 4
    BTFSC STATUS, 2
    GOTO KEYPAD_INPUT_3
    RETURN

; A key: Set flag to activate menu
KEYPAD_PROC_A:
    MOVLW 1
    MOVWF menu_flag
    RETURN

; Step 1: Input tens digit
KEYPAD_INPUT_1:
    MOVF key_last_pressed, W
    MOVWF input_tens
    CLRF input_ones
    CLRF input_decimal
    MOVLW 2
    MOVWF menu_step
    RETURN

; Step 2: Input ones digit
KEYPAD_INPUT_2:
    MOVF key_last_pressed, W
    MOVWF input_ones
    MOVLW 3
    MOVWF menu_step
    RETURN

; * key: Proceed to decimal input
KEYPAD_PROC_STAR:
    MOVF menu_step, W
    XORLW 3
    BTFSS STATUS, 2
    RETURN
    MOVLW 4
    MOVWF menu_step
    RETURN

; Step 4: Input decimal digit
KEYPAD_INPUT_3:
    MOVF key_last_pressed, W
    MOVWF input_decimal
    MOVLW 5
    MOVWF menu_step
    RETURN


;Validates and applies user input when # is pressed.
;  Valid range: 10.0 - 50.0 degrees Celsius.

KEYPAD_PROC_CONFIRM:
    MOVF menu_step, W
    XORLW 3
    BTFSC STATUS, 2
    GOTO KEYPAD_MODE_FULL
    MOVF menu_step, W
    XORLW 5
    BTFSC STATUS, 2
    GOTO TEMP_INPUT_LIMIT_CHECK
    RETURN

; Confirm without decimal
KEYPAD_MODE_FULL:
    CLRF input_decimal

; Validate input range (10-50)
TEMP_INPUT_LIMIT_CHECK:
    MOVF input_tens, F
    BTFSC STATUS, 2
    GOTO TEMP_INPUT_REJECT      ; tens=0 invalid
    MOVLW 6
    SUBWF input_tens, W
    BTFSC STATUS, 0
    GOTO TEMP_INPUT_REJECT      ; tens>=6 invalid
    
    ; Special case: 50.x not allowed (max is 50.0)
    MOVF input_tens, W
    XORLW 5
    BTFSS STATUS, 2
    GOTO TEMP_CALC_TARGET
    MOVF input_ones, F
    BTFSS STATUS, 2
    GOTO TEMP_INPUT_REJECT
    MOVF input_decimal, F
    BTFSS STATUS, 2
    GOTO TEMP_INPUT_REJECT

; Calculates target temperature from input digits.
;Formula: target = (tens * 10) + ones
; Uses shift-add method for multiplication.

TEMP_CALC_TARGET:
    MOVF input_tens, W
    MOVWF temp_target_int
    BCF STATUS, 0
    RLF temp_target_int, F      ; x2
    RLF temp_target_int, F      ; x4
    MOVF temp_target_int, W
    ADDWF input_tens, W         ; x4 + x1 = x5
    BCF STATUS, 0
    MOVWF temp_target_int
    RLF temp_target_int, F      ; x10
    MOVF input_ones, W
    ADDWF temp_target_int, F    ; + ones
    MOVF input_decimal, W
    MOVWF temp_target_frac
    CALL TEMP_UPDATE_LOGIC
    CLRF menu_step
    RETURN

TEMP_INPUT_REJECT:
    CLRF menu_step
    RETURN


; Converts digit (0-10) to 7-segment pattern.
; Input:  W = digit value (0-9 for numbers, 10 for dash)
; Output: W = segment pattern (bit 0-6 = segments a-g)

DISPLAY_GET_SEGMENT:
    MOVWF segment_code
    
    MOVLW 11
    SUBWF segment_code, W
    BTFSC STATUS, 0
    RETLW 00000000B             ; Blank for invalid
    
    MOVF segment_code, F
    BTFSC STATUS, 2
    RETLW 00111111B             ; 0
    
    DECF segment_code, F
    BTFSC STATUS, 2
    RETLW 00000110B             ; 1
    
    DECF segment_code, F
    BTFSC STATUS, 2
    RETLW 01011011B             ; 2
    
    DECF segment_code, F
    BTFSC STATUS, 2
    RETLW 01001111B             ; 3
    
    DECF segment_code, F
    BTFSC STATUS, 2
    RETLW 01100110B             ; 4
    
    DECF segment_code, F
    BTFSC STATUS, 2
    RETLW 01101101B             ; 5
    
    DECF segment_code, F
    BTFSC STATUS, 2
    RETLW 01111101B             ; 6
    
    DECF segment_code, F
    BTFSC STATUS, 2
    RETLW 00000111B             ; 7
    
    DECF segment_code, F
    BTFSC STATUS, 2
    RETLW 01111111B             ; 8
    
    DECF segment_code, F
    BTFSC STATUS, 2
    RETLW 01101111B             ; 9
    
    RETLW 01000000B             ; Dash (-)

;Initializes microcontroller hardware.
;   - Configures ADC for temperature reading
;   - Sets I/O pin directions
;   - Enables PORTB weak pull-ups

SYSTEM_INIT:
    MOVLW 10000001B             ; ADC on, channel 0, Fosc/8
    MOVWF ADCON0
    
    BSF STATUS, 5               ; Bank 1
    
    MOVLW 10001110B             ; AN0 analog, right justified
    MOVWF ADCON1
    
    MOVLW 00000001B             ; RA0 input (temp sensor)
    MOVWF TRISA
    MOVLW 11110000B             ; RB0-3 output, RB4-7 input
    MOVWF TRISB
    MOVLW 10000000B             ; RC7 input (UART RX)
    MOVWF TRISC
    CLRF TRISD                  ; All output (7-seg data)
    
    BCF OPTION_REG, 7           ; Enable PORTB pull-ups
    
    BCF STATUS, 5               ; Bank 0
    
    CLRF PORTC
    CLRF PORTD
    MOVLW 0xFF
    MOVWF PORTB
    RETURN

; Initializes UART for serial communication.
;  Baud rate: 9600 @ 4MHz crystal
;   8 data bits, no parity, 1 stop bit

UART_INIT:
    BSF STATUS, 5               ; Bank 1
    MOVLW 25                    ; SPBRG=25 for 9600 baud
    MOVWF SPBRG
    MOVLW 00100100B             ; TX enable, high speed mode
    MOVWF TXSTA
    BCF STATUS, 5               ; Bank 0
    MOVLW 10010000B             ; Serial port on, RX enable
    MOVWF RCSTA
    RETURN

; Checks for received UART data and processes commands.
;              Command format:
;              - 11xxxxxx: Set temperature integer (6-bit value)
;              - 10xxxxxx: Set temperature fraction (6-bit value)
;              - 0x01: Get target fraction
;              - 0x02: Get target integer
;              - 0x03: Get ambient fraction
;              - 0x04: Get ambient integer
;              - 0x05: Get fan status

UART_CHECK_DATA:
    BTFSS PIR1, 5               ; Check RCIF flag
    RETURN
    BTFSC RCSTA, 1
    GOTO UART_ERR_OERR
    BTFSC RCSTA, 2
    GOTO UART_ERR_FERR
    MOVF RCREG, W
    MOVWF uart_rx_data
    
    ; Parse command based on upper bits
    MOVF uart_rx_data, W
    ANDLW 11000000B
    XORLW 11000000B
    BTFSC STATUS, 2
    GOTO UART_CMD_SET_INT
    MOVF uart_rx_data, W
    ANDLW 11000000B
    XORLW 10000000B
    BTFSC STATUS, 2
    GOTO UART_CMD_SET_FRAC
    MOVF uart_rx_data, W
    XORLW 0x01
    BTFSC STATUS, 2
    GOTO UART_CMD_GET_TARGET_FRAC
    MOVF uart_rx_data, W
    XORLW 0x02
    BTFSC STATUS, 2
    GOTO UART_CMD_GET_TARGET_INT
    MOVF uart_rx_data, W
    XORLW 0x03
    BTFSC STATUS, 2
    GOTO UART_CMD_GET_AMBIENT_FRAC
    MOVF uart_rx_data, W
    XORLW 0x04
    BTFSC STATUS, 2
    GOTO UART_CMD_GET_AMBIENT_INT
    MOVF uart_rx_data, W
    XORLW 0x05
    BTFSC STATUS, 2
    GOTO UART_CMD_GET_FAN
    RETURN

; Handle overrun error by resetting receiver
UART_ERR_OERR:
    BCF RCSTA, 4
    BSF RCSTA, 4
    RETURN

; Handle framing error by reading bad byte
UART_ERR_FERR:
    MOVF RCREG, W
    RETURN

; Store integer part, wait for fraction
UART_CMD_SET_INT:
    MOVF uart_rx_data, W
    ANDLW 00111111B
    MOVWF uart_temp_int
    BSF update_flag, 0
    RETURN


;Receives fraction part and validates complete temp.
;  Applies new target if valid (10-50 range).

UART_CMD_SET_FRAC:
    MOVF uart_rx_data, W
    ANDLW 00111111B
    MOVWF uart_temp_frac
    BTFSS update_flag, 0
    RETURN

    ; Validate range 10-50
    MOVLW 10
    SUBWF uart_temp_int, W
    BTFSS STATUS, 0
    GOTO UART_ABORT
    MOVLW 51
    SUBWF uart_temp_int, W
    BTFSC STATUS, 0
    GOTO UART_ABORT
    
    ; If 50, fraction must be 0
    MOVF uart_temp_int, W
    XORLW 50
    BTFSS STATUS, 2
    GOTO UART_COMMIT
    MOVF uart_temp_frac, F
    BTFSS STATUS, 2
    GOTO UART_ABORT

UART_COMMIT:
    MOVF uart_temp_int, W
    MOVWF temp_target_int
    MOVF uart_temp_frac, W
    MOVWF temp_target_frac
    BCF update_flag, 0
    GOTO TEMP_UPDATE_LOGIC

UART_ABORT:
    BCF update_flag, 0
    RETURN


; Updates temp_target_total for hysteresis comparison.
;   Rounds up if fractional part >= 5.

TEMP_UPDATE_LOGIC:
    MOVF temp_target_int, W
    MOVWF temp_target_total
    XORLW 50
    BTFSC STATUS, 2
    RETURN                      ; No rounding at max temp
    MOVF temp_target_frac, W
    SUBLW 4
    BTFSC STATUS, 0
    RETURN                      ; frac <= 4, no rounding
    INCF temp_target_total, F   ; Round up
    RETURN

; UART query response handlers
UART_CMD_GET_TARGET_FRAC:
    MOVF temp_target_frac, W
    CALL UART_SEND_DATA
    RETURN
UART_CMD_GET_TARGET_INT:
    MOVF temp_target_int, W
    CALL UART_SEND_DATA
    RETURN
UART_CMD_GET_AMBIENT_FRAC:
    MOVLW 0
    CALL UART_SEND_DATA
    RETURN
UART_CMD_GET_AMBIENT_INT:
    MOVF temp_ambient, W
    CALL UART_SEND_DATA
    RETURN
UART_CMD_GET_FAN:
    MOVF fan_status, W
    CALL UART_SEND_DATA
    RETURN


; Transmits one byte via UART.
; Input: W = byte to transmit

UART_SEND_DATA:
    BSF STATUS, 5               ; Bank 1
UART_TX_WAIT:
    BTFSS TXSTA, 1              ; Wait for TRMT=1
    GOTO UART_TX_WAIT
    BCF STATUS, 5               ; Bank 0
    MOVWF TXREG
    RETURN


; Creates ~1ms delay for display multiplexing.
;  At 4MHz, each loop = 5 cycles, 195 loops â 975Âµs

DISPLAY_MUX_DELAY:
    MOVLW 195
    MOVWF delay_counter
SYSTEM_DELAY_LOOP:
    NOP
    DECFSZ delay_counter, F
    GOTO SYSTEM_DELAY_LOOP
    RETURN

;Reads temperature from analog sensor on AN0.
; Converts 10-bit ADC value to approximate temperature
; by dividing by 2.

ADC_READ_AMBIENT:
    BSF ADCON0, 2               ; Start conversion
ADC_WAIT_CONVERSION:
    BTFSC ADCON0, 2             ; Wait for GO/DONE=0
    GOTO ADC_WAIT_CONVERSION
    
    BSF STATUS, 5               ; Bank 1
    MOVF ADRESL, W              ; Read low byte
    BCF STATUS, 5               ; Bank 0
    MOVWF temp_ambient
    
    BCF STATUS, 0
    RRF temp_ambient, F         ; Divide by 2
    RETURN


;  Updates fan_status based on cooler output (RC4).
;              Returns 5 if fan is running, 0 if off.

FAN_STATUS_CHECK:
    BTFSC PORTC, 4              ; Check cooler pin
    GOTO FAN_IS_ACTIVE
    CLRF fan_status
    RETURN
FAN_IS_ACTIVE:
    MOVLW 5
    MOVWF fan_status
    RETURN

    END