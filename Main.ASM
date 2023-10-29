;********************************************************************
;Filename:	Main.asm						*
;PCB:	Model 13 Version 5-4e						*
;Date:	20080726	start development				*
;Date:	20090326	first controlled temp				*
;Date:	20090404	1°F stability observed				*
;Date:	20100320	modified PID(DCBIAS) - 1°F stability achieved	*
;PCB:	Model 14 Version 1						*
;PCB:	Model 14 Version 2d		11/18/2010			*
;PCB:	Model 14 Version 3		 2/12/2011			*
;Date:	20110228	new integer PID(DCBIAS) - best stability 	*
;Date:	20110307	really sustained stability			*
;Date:	20130110	PID using table lookup for gains		*
;PCB:	Model 15 Version 1		 4/12/2018			*
;Date:	20190302	download/upload with PICkit4			*
;PCB:	BTm15v3-20190818	 	 8/18/2019			*
;********************************************************************
;user input - 2 buttons
;before/after session -
;	BTN1	click:	UNUSED
;		hold:	reset saved SETPOINT to FACTORY
;	BTN2	click:	UNUSED
;		hold:	start session
;during session -
;	BTN1	click:	increase current SETPOINT +5F
;		hold:	UNUSED
;	BTN2	click:	decrease current SETPOINT -4F
;		hold:	set saved SETPOINT to current 
;********************************************************************

	errorlevel	-302
	errorlevel	-305
	expand

	list     	p=12F683	;list directive to define processor

	#include	p12F683.inc	;processor specific EQUs
	#include	Vars.asm
	#include	Macro.asm

config1=    _PWRTE_OFF  & _WDT_ON   & _INTOSCIO
config2=    _CPD_OFF    & _CP_OFF   & _MCLRE_OFF
config3=    _FCMEN_ON   & _IESO_OFF & _BOD_OFF
	__CONFIG    config1 & config2 & config3

;***** RESET *****
	ORG	0x0000		;reset vector location
	goto	main		;go to beginning of program
;*********************

;***** INTERRUPT *****
	ORG	0x0004		;interrupt vector location
;   100 msec Heartbeat Interrupt
;*********************

	Save_W_STATUS
	Disable_Interrupts

	If_Heartbeat_Interrupt THEN	;else, dismiss the interrupt

	    ;NOTE:  2.66ms for interrupt handler execution

	    Stop_Heartbeat
	    Clear_Heartbeat_Interrupt_Flag

	    Read_Button			;check for button press

	    If_vRun THEN

		Reset_Watchdog		;restart 250 msec WDT

		Read_Coil_Temperature	;every 3rd tick
		;save in eePROM
		;abort if TOO HOT / MISSING SENSOR / ZERO VALUE
		;test for BAD READING - reuse previous 3 times

intr_done:
		;count calls to interrupt
		Increment_Counter ceeCounter3

		Start_Heartbeat
		Set_vSTATE vTick	;set the heartbeat flag

intr_exit:
	Enable_Interrupts
	Restore_W_STATUS
	retfie

;******************
;end of interrupt
;******************



;***** MAIN *****
;all resets come here: POR, BOR, WDT
;POR = power on reset
;BOR = brown-out reset
;WDT = watch dog timer
;todo: detect POR|BOR from AC power supply and decrease the full-on @ startup
;so PS doesn't fault from apparent short from .3 ohm heater ribbon coil
main:

	;check for WDT reset and SHUT DOWN!!!
	If_WDT_Reset_Then_Shutdown

	;7.5 minute runtime from power-up start
	Initialize_Start_Time
	;set to saved setpoint temperature
	Initialize_SETPOINT
	goto	main1

main_restart:
	;3.5 extra minutes of runtime
	Initialize_Restart_Time
	;continue with current setpoint

main1:
	;init PIC components
	Disable_PWM
	Initialize_Oscillator
	Initialize_GPIO
	Initialize_Watchdog		;set WDT for 4.5 minute timeout

	;init state variables
	Initialize_vSTATE
	Initialize_vSENSOR
	Initialize_vERROR
	Initialize_COILTEMPptr
	Reset_COILTEMPdelay
	Initialize_DCBIAS
	Initialize_SPERRORtrip
	Initialize_eeCOILTEMPptr
	Initialize_eeDUTYCYCLEptr

	;start heartbeat (Timer1)
	Initialize_Heartbeat	;10 ticks/second (100 msec/tick)
	Start_Heartbeat

;***** wait for 1 second BTN2 press *****
main_ready:
;******************

	;set vSTATE to "WAITING"
	Set_vSTATE vWait
	Initialize_LED_vWait		;3 flash @ 3 seconds
	Reset_BTNdelay cBTNdelay	;hold Btn1 or Btn2 for 1 second

	;loop until start up signal (BTNdelay=0)
main_ready_0:

	;wait for next button reading (each tick)
	Wait_vSENSOR vBtn
	Clear_vSENSOR vBtn

	;test for BTN1 press - restore factory settings
	btfss	vSENSOR,vBtn1
	  goto	main_ready_1
	btfss	vSENSORold,vBtn1
	  goto	main_ready_1

	;same button, so decrement BTNdelay
	decfsz	BTNdelay	;is BTN1 on long enough?
	  goto	main_ready_3	;no, update LED

	;restore factory settings
	call	RestoreFactory

	;acknowledge button press
	call	LEDon
	Wait_Release_BTN vBtn1
	call	LEDoff
	goto	main_ready_2

main_ready_1:
	;test for BTN2 press - start vape session
	btfss	vSENSOR,vBtn2	    ;is BTN2?
	  goto	main_ready_2	    ;no, continue waiting
	btfss	vSENSORold,vBtn2    ;was BTN2?
	  goto	main_ready_2	    ;no, continue waiting

	;same button, so decrement BTNdelay
	decfsz	BTNdelay	    ;is BTN2 on long enough?
	  goto	main_ready_3	    ;no, update LED

	;***** TURN ON VAPE *****
	goto	vape_start	    ;yes, Run!
	;************************

main_ready_2:
	;reset BTN2 delay for 1 seconds (10 ticks)
	Reset_BTNdelay cBTNdelay

main_ready_3:
	;flash LED 3 times every 5 seconds
	call 	UpdateLED

	goto	main_ready_0
;***** end of wait for BTN2 *************

;***** start the vape, drive to SETPOINT *****
vape_start:
;******************

	;---- wait for button release -----
	;signal vape in "start" mode
	call	LEDon

	;wait for release of BTN2
	Wait_Release_BTN vBtn2
	Reset_BTNdelay cBTNdelay

	;signal buttons now live
	call	LEDoff
	;--------------------

	;initialize state variables
	Initialize_vCOILTEMP
	Initialize_vPWM

	;initialize PID variables
	Initialize_PID

	;init eePROM run data storage
	Clear_eePROM_Buffers
	;count calls to Read_Coil_Temperature from interrupt
	Clear_Counter ceeCounter3

	;start the PWM
	Initialize_PWM
	Set_vPWM vPWMon

	;enter "Run" mode
	Clear_vSTATE vWait
	Set_vSTATE vRun

;***********************
;While (TRUE) DO
;***********************
;loop runs once per tick
vape_run:
	Wait_vSTATE vTick	;wait for next heartbeat tick
	Clear_vSTATE vTick

	;check run time and exit
	If_Maximum_Run_Time	Error_RunTime

	;check for button press
run_BTN:
	If_BUTTON_Adjust_SETPOINT

	;set DutyCycle after sensor reading
run_DC:
	Update_Duty_Cycle	;save in eePROM

	;activate LED if COILTEMP at or above SETPOINT
run_LED:
	Signal_SETPOINT

	;processing done - wait for next tick
	goto vape_run

;*********
;	WEND
;*********


;***** WATCHDOG Timer interrupt *****
Error_WDT:
;------------------
	Set_vERROR vWDT
	Write_Error vWDT
	Initialize_LED_WDT	;1 flash @ 1/2 seconds
	goto Error_Shutdown	;run LED flash sequence
;------------------


;***** zero reading from MAX6675 *****
Error_ZeroRead:
;------------------
	Set_vERROR vZeroR
	Write_Error vZeroR
	Initialize_LED_ZeroReading  ;2 flash @ 1/2 seconds
	goto Error_Shutdown	    ;run LED flash sequence
;------------------


;***** Type-K Thermocouple is missing *****
Error_Sensor:
;------------------
	Set_vERROR vKmissing
	Write_Error vKmissing
	Initialize_LED_Sensor	    ;1 flash @ 2 seconds
	goto Error_Shutdown	    ;run LED flash sequence
;------------------


;***** COILTEMP exceeds maximum *****
Error_TooHot:
;------------------
	Set_vERROR vTooHot
	Write_Error	vTooHot
	Initialize_LED_TooHot	    ;2 flashes @ 2 seconds
	goto	Error_Shutdown	    ;run LED flash sequence
;------------------


;***** RUNTIME exceeds maximum *****
Error_RunTime:
;------------------
	Write_Error	vRuntime
;	Set_vERROR vRuntime
;	Initialize_LED_RunTime	    ;3 flashes @ 2 second
;	goto	Error_Shutdown	    ;run LED flash sequence
	goto	main_restart	    ;allow continue for 3.5 minutes
;------------------


;***** Battery is dead ***** how to detect?
Error_Battery:
;------------------
	Write_Error	vBattery
	Set_vERROR vBattery
	Initialize_LED_Battery	    ;4 flashes @ 2 second
	goto	Error_Shutdown	    ;run LED flash sequence
;------------------


;***** shutdown loop *****
Error_Shutdown:
	call	eePutvERROR
	Initialize_Watchdog	    ;set 4.5 minute timeout
	Clear_vSTATE vRun	    ;just a heartbeat 
	Set_vSTATE vError
	Disable_PWM		    ;shutdown heater
	
;flash LED during error state
err_LED:
	Wait_vSTATE vTick	    ;wait for next heartbeat tick
	Clear_vSTATE vTick
	call 	UpdateLED	    ;execute LED flash pattern
	goto	err_LED
;******************


;******************
	#include    Lib.asm
	#include    DC.asm
	#include    LED.asm
;******************
	END			    ;directive 'end of program'

