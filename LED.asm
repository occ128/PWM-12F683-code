;Manage the LED

;	ToggleLED
;	LEDon
;	LEDoff
;	ResetLED
;	UpdateLED
;	SignalSETPOINT

;------------------
;check LED state and flip
ToggleLED:
	btfsc	vSTATE,vLEDon
	  goto LEDoff

	;drop into toggle LED ON

;------------------
;set LED on
LEDon:
	banksel	GPIO
	bsf	LED			;turn LED on
	Set_vSTATE vLEDon		;set LED ON flag
	return

;------------------
;set LED off
LEDoff:
	banksel	GPIO
	bcf	LED			;turn LED off
	Clear_vSTATE vLEDon		;clear LED ON flag
	return

;reset LED for current state
ResetLED:
	banksel	FLASHdelay0
	movf	FLASHdelay0,W
	  movwf	FLASHdelay
	movf	FLASHcount0,W
	  movwf	FLASHcnt
	movlw	cLEDONticks
	  movwf	LEDcnt		;set flash ON duration (ticks)
	Clear_vSTATE vLEDact	;clear LED ACTIVE flag
	call LEDoff
	return

;------------------
;Update LED status
UpdateLED:
	btfsc	vSTATE,vLEDact	;is LED ACTIVE?
	  goto	UpdateLED_ctrl	;yes
	decfsz	FLASHdelay	;time to flash LED?
	  return		;no, wait for next tick

UpdateLED_act:	;activate LED flash sequence
	Set_vSTATE vLEDact	;set LED to ACTIVE
	banksel	LEDcnt
	movlw	cLEDONticks
	movwf	LEDcnt
	incf	LEDcnt
	goto	UpdateLED_on	;and turn on

UpdateLED_ctrl:	;test current LED state on/off
	btfss	vSTATE,vLEDon	;is LED on?
	  goto	UpdateLED_off	;no, continue LED off activity
	
UpdateLED_on:	;turn on for cLEDONticks ticks
	call	LEDon
	banksel	LEDcnt
	decfsz	LEDcnt		;LED on enough ticks?
	  return		;no, wait for next tick

	;time to change LED status (ON -> OFF)
	banksel	LEDcnt
	movlw	cLEDOFFticks
	movwf	LEDcnt
	incf	LEDcnt

UpdateLED_off:	;turn off for cLEDOFFticks ticks
	call	LEDoff
	banksel	LEDcnt
	decfsz	LEDcnt		;LED off enough ticks?
	  return		;no, wait for next tick

	;one complete flash - ON / OFF

	;repeat FLASHcnt times
	banksel	FLASHcnt
	decfsz	FLASHcnt	;enough flashes?
	  goto	UpdateLED_act	;no, start another flash

	;re-initialize LED params for vSTATE = vWait
	call	ResetLED
	return

;------------------
;turn on GREEN LED if COILTEMP >= SETPOINT (NOT vBelow)
;wait for COILTEMP at/above SETPOINT for 2-byte TOKEITdelay ticks
SignalSETPOINT:

	;test if delay active
	banksel	TOKEITgo
	movf	TOKEITgo
	Skip_If_ZERO
	  goto	s_sp_test
	Skip_If_vBelow
	  incf	TOKEITgo	;mark first vAbove (i.e. NOT vBelow)
	goto	s_sp_off

	;test if delay expired
s_sp_test:
	movf	TOKEITdelay
	Skip_If_ZERO
	  goto	s_sp_dec
	movf	TOKEITdelay+1	;check for zero value
	Skip_If_ZERO
	  goto	s_sp_dec

	;delay expired, check vBelow
	Skip_If_vBelow
	  goto	s_sp_on		;turn on LED if ^vBelow
	goto	s_sp_off	;turn off LED if vBelow

	;delay not expired so decrement delay
s_sp_dec:
	movlw	.1
	subwf	TOKEITdelay
	Skip_If_CARRY_CLR	;1 > lo(TOKEITdelay)
	  return
	subwf	TOKEITdelay+1	;1 > lo(TOKEITdelay)
	Skip_If_CARRY_CLR
	  return
	clrf	TOKEITdelay
	clrf	TOKEITdelay+1
	return

s_sp_on:	;turn LED on
	call	LEDon
	return

s_sp_off:	;turn LED off
	call	LEDoff
	return


;end	*****