.Include	SYS\Macro.inc
.Include	KEY\KEY.inc
.INCLUDE	Alarm\Alarm.inc
;.INCLUDE	RFC\RFC.inc
;==============================================================================
; Public declare area
;==============================================================================
.PUBLIC			F_ResetRealTimeClock
.PUBLIC			F_RealTimeClock
.PUBLIC			F_ClearIncStatus
.PUBLIC			F_ClearSecond
.PUBLIC			DEC_YMDHMS
.PUBLIC			INC_SEC	
.PUBLIC			INC_MIN  
.PUBLIC			INC_MIN1
.PUBLIC			INC_MIN2
.PUBLIC			INC_HR 
.PUBLIC			INC_HR1
.PUBLIC			INC_DAT 
.PUBLIC			INC_HR2		;x for RAM, a for Max 
.PUBLIC			INC_MON  
.PUBLIC			INC_YER  
.PUBLIC			MAXDCMP
.PUBLIC			WEEKCAL
.PUBLIC			R_TimeStatus
.PUBLIC			RTC
.PUBLIC			DATE
.PUBLIC			TR01
;==========================================
; Constant define area
;==========================================
;YearMonthDate	        EQU	    1			 ;define year month date enable 		
	
;------------------------------------------------------------------------------
.PAGE0
;
RTC		             .DS	 3
	; RTC+0 --> Hour (BCD)
	; RTC+1 --> Minute (BCD)
	; RTC+2 --> Second (BCD)
	;  -------------------------------------------
	; |             | RTC+0   | RTC+1   | RTC+2   |
	; |-------------|---------|---------|---------|
	; | Description | Hour    | Minute  | Second  |
	; |	            | 00 - 23 | 00 - 59 | 00 - 59 |        
	; |		        | (BCD)   | (BCD)   | (BCD)   |         |
	;  -------------------------------------------
;
DATE	            .DS	    3
	; DATE+0 --> 00-99(BCD) Year
	; DATE+1 --> .7 = 1 --> 20xx (Year)
	;		        = 0 --> 19xx (Year)
	;	         .6 - .4 --> 00H - 06H --> SUN - SAT (Week)
	;	         .3 - .0 --> 00H - 0BH --> JAN - DEC (Month)
	; DATE+2 --> 01 - 31(BCD) Date
;
R_TimeStatus	    .DS	    1       ;(.7 reserved!!!)
HalfSecToggle			EQU		01000000B
AddSecondOnly			EQU		00100000B
AddOthers				EQU		00010000B
TR00				.DS	    1
TR01				.DS		1
TR02		    	.DS		1
TR03				.DS		1
;------------------------------------------------------------------------------
.CODE
;==============================================================================
F_RealTimeClock:	;Level 1
	LDA	#HalfSecToggle
	EOR	R_TimeStatus
	STA	R_TimeStatus
	AND	#HalfSecToggle
	BNE	L_Time99	; 0.5 second only!!!
;	1 second!!!
	JSR	INC_SEC	;Level 2  
	BCC	L_OnlySEcAdd

	JSR	INC_MIN	;Level 2
	BCC	L_OnlyMinAdd
	
	
	JSR	INC_HR	;Level 2
	
;	IFDEF	YearMonthDate
	BCC	L_OnlyHourAdd
	JSR	INC_DAT	;Level 3
	BCC	L_Time01
	JSR	INC_MON	;Level 2
	BCC	L_Time01
	JSR	INC_YER	;Level 2
L_Time01:
	JSR	WEEKCAL	;Level 3
	JSR	MAXDCMP	;Level 3
;	ELSE
;	ENDIF
L_OnlyHourAdd:
L_OnlyMinAdd:	
	LDA	#AddOthers
	BNE	L_AddAll	;@JMP
L_OnlySEcAdd:
	LDA	#AddSecondOnly
L_AddAll:
	ORA	R_TimeStatus
	STA	R_TimeStatus
L_Time99:
	RTS
;
;------------------------------------------------------------------------------
;
F_ClearIncStatus:
	LDA	#(.NOT.(AddSecondOnly+AddOthers))
	AND	R_TimeStatus
	STA	R_TimeStatus
	RTS
;
;------------------------------------------------------------------------------
;
F_ResetRealTimeClock:          ;开机显示初值(默认值)
	LDA	#00H
	STA	RTC+0
	LDA	#00H
	STA	RTC+1
	LDA	#00H		;test use
	STA	RTC+2	
	LDA	#AddOthers
	STA	R_TimeStatus
;	IFDEF	YearMonthDate
	; DATE+0 --> 00-99 (Year)
	; DATE+1 --> .7 = 1 --> 20xx (Year)
	;		= 0 --> 19xx (Year)
	;	     .6 - .4 --> 00H - 06H --> SUM - SAT (Week)
	;	     .3 - .0 --> 00H - 0BH --> JAN - DEC (Month)
	; DATE+2 --> 01 - 31 (Date)
	LDA	#00100101B			; 2025-1-1 	;2(0010)4(0100)  (BCD8421)
	STA	DATE+0
	LDA	#10110000B			;1(20xx) 001(Mon) 0000(JAN)
	STA	DATE+1
;	STA	R_LaZhuMonth
	LDA	#00000001B
	STA	DATE+2				;DATE+2 --> 01 - 31 (Date)
;	ELSE
;	ENDIF
	RTS
;
;------------------------------------------------------------------------------
F_ClearSecond:
	LDA	#00
	STA	RTC+2
	RTS
;	IFDEF	YearMonthDate
;------------------------------------------------------------------------------
; --- Week Calculate for Month ---
; *** Use TR00 ***
;	  TR01
;	  TR02 Temp Week
;         TR03
;
WEEKCAL:
	LDA	DATE+1		;;
	BMI	WEC_00		;;
	LDA	#0
	STA	TR02		; 1/1/1900 as Sun
	LDA	DATE
	BNE	WEC_02
	LDA	#1		; 1/1/1900 Mon
	JMP	WEC_01
WEC_00:
	LDA	#6		; 1/1/2000 Sat
WEC_01:
	STA	TR02
WEC_02:
	LDA	DATE		; XXL_WeekX
	JSR	AROR
	STA	TR00
WEC_03:
	DEC	TR00
	BMI	WEC_04
	LDA	TR00
	AND	#00000001B
	BNE	L_Week01
	LDA	#06H
	JMP	L_Week02
L_Week01:
	LDA	#05H
L_Week02:
	STA	TR01
	JSR	WADDUP
	JMP	WEC_03
;
WEC_04:
	LDA	DATE		; XXX?
	AND	#00001111B
	STA	TR00
WEC_05:
	DEC	TR00
	BMI	WEC_06
	LDA	DATE
	AND	#00010000B
	BNE	L_Week001
	LDA	#00
	JMP	L_Week002
L_Week001:
	LDA	#02
L_Week002:
	STA	TR03
	LDA	TR00
	AND	#00000011B
	SEC
	SBC	TR03
	BEQ	L_Week003
	LDA	#1
	JMP	L_Week004
L_Week003:
	LDA	#2
L_Week004:
	STA	TR01
	JSR	WADDUP
	JMP	WEC_05
;
WEC_06: 			; ?/XX
	LDA	DATE+1
	AND	#00001111B
	STA	TR00
;
WEC_07:
	DEC	TR00
	BMI	WEC_08
	LDA	TR00
	JSR	MONCAL2
	AND	#00001111B
	CLC
	ADC	#08H
	CMP	#0FH
	BCS	L_Week0001
	ADC	#0AH
L_Week0001:
	AND	#00001111B
	STA	TR01
	JSR	WADDUP
	JMP	WEC_07
;
WEC_08: 			; X/??
;	LDA	#01H
;	STA	TR01
	LDA	DATE+2
	STA	TR01
	LDX	#TR01
WEC_09:
	LDA	TR01
;	CMP	#7
	CMP	#8
	BCC	L_Week00001
	LDA	#93H
	STA	TR00
	JSR	ADC_RT
	JMP	WEC_09
L_Week00001:
	DEC	TR01
	JSR	WADDUP
	LDA	TR02
	ROL	A
	ROL	A
	ROL	A
	ROL	A
	AND	#01110000B
	STA	TR02
	LDA	DATE+1
	AND	#10001111B
	ORA	TR02
	STA	DATE+1
	RTS

;
; ** TR02 = TR02 + TR01 **
; ** TR02 Range 0 - 6	**
WADDUP:
	LDA	TR02
	AND	#00001111B
	CLC
	ADC	TR01
	CMP	#7
	BCC	L_WeekAdd01
	ADC	#8		; +8 +C
	AND	#00001111B
L_WeekAdd01:
	STA	TR02
	RTS
;
;----------------------------------------------------------
; --- Max. Date Compare ---
;
MAXDCMP:
	JSR	MONCAL
	CMP	DATE+2
	BPL	L_Maxday01
	STA	DATE+2
L_Maxday01:
	RTS

;----------------------------------------------------------
; --- Max. Date of Month ---
; *** Use TR01 ***
; *** RTS Max. Date = TR01 & A ***
MONCAL1:
	LDA	R_TimeStatus
	BPL	MONCAL		; /DECF
;
	LDA	DATE+1
	AND	#00001111B
	STA	TR01
	DEC	TR01
	LDA	TR01
	JMP	MONCAL3
;---------------------------
MONCAL:
	LDA	DATE+1
MONCAL2:
	AND	#00001111B
	STA	TR01
MONCAL3:
	CMP	#1
	BEQ	L_Month20		; Feb
;
	INC	TR01
	LDA	TR01
	AND	#00001000B
	BEQ	L_Month07
	LDA	TR01
	EOR	#1
	STA	TR01
L_Month07:
	LDA	TR01
	AND	#00000001B
	ORA	#00110000B	; 3X
	JMP	L_Month25
;
L_Month20:
	LDA	DATE
	BNE	L_Month26
	LDA	DATE+1		;;
	BPL	L_Month22A		; 1990 FEB
L_Month26:
	LDA	DATE
	AND	#00010000B
	BNE	L_Month21
	LDA	#00
	STA	TR01
	JMP	L_Month22
L_Month21:
	LDA	#02
	STA	TR01
L_Month22:
	LDA	DATE
	AND	#00000011B
	SEC
	SBC	TR01
	BEQ	L_Month23		; 29
L_Month22A:
	LDA	#28H		; 28
	JMP	L_Month25
L_Month23:
	LDA	#29H
L_Month25:
	STA	TR01
	RTS

;----------------------------------------------------------
; Use:	TR00 - Min
;	TR01 - Max
;	Overflow RTS CY=1
INC_MON:
	LDA	DATE+1
	AND	#00001111B
	STA	TR00
	LDA	DATE+1
	AND	#11110000B
	STA	DATE+1
	LDA	R_TimeStatus
	BMI	INC_MON3
	INC	TR00
	LDA	TR00
	CMP	#0CH
	BCS	INC_M01
	JMP	INC_M04
INC_M01:
	JMP	INC_M03 	; = JAN
INC_MON3:
	DEC	TR00
	BMI	INC_M02
INC_M04:
	LDA	TR00
	ORA	DATE+1
	STA	DATE+1
	CLC
	RTS
INC_M02:			; = DEC
	LDA	#0BH
	ORA	DATE+1
	STA	DATE+1
INC_M03:
	SEC
	RTS
;
INC_DAT:
	LDX	#DATE+2
	JSR	MONCAL
INC_DAT1:
	LDA	#1
	STA	TR00
	JMP	INC_DET
;
INC_YER:
	LDX	#DATE
	LDA	#99H
	STA	TR01
	JMP	INC_MIN2
;	ELSE
;	ENDIF
;
INC_SEC:
	LDX	#RTC+2   ;second
	JMP	INC_MIN1
INC_MIN:
	LDX	#RTC+1   ;Minute
INC_MIN1:
	LDA	#59H
	STA	TR01
INC_MIN2:
	LDA	#00
	STA	TR00
	JMP	INC_DET
;
INC_HR:
	LDX	#RTC+0
INC_HR1:
	LDA	#23H
INC_HR2:
	STA	TR01
	JMP	INC_MIN2
INC_DET:
	LDA	R_TimeStatus
	BMI	DEC_DET
	LDA	0,X
	CMP	TR01
	BCS	INC_D01
	LDA	#01
	STA	TR00
	JMP	ADC_RT
INC_D01:
	LDA	TR00
INC_D02:
	STA	0,X
	SEC
	RTS
;
DEC_DET:
	LDA	0,X
	CMP	TR00
	BEQ	DEC_D01
	LDA	#99H
	STA	TR00
	JMP	ADC_RT
DEC_D01:
	LDA	TR01
	JMP	INC_D02
;
; Use:	TR00 - variable
;	TR01 - (X)
;	(X) = TR01+TR00
ADC_RT:
	CLC
	LDA	0,X
	STA	TR01
	AND	#00001111B
	ADC	TR00
	ADC	#6
	EOR	TR00
	AND	#11110000B
	BEQ	L_TimeAdd01
	LDA	#6
L_TimeAdd01:
	ADC	TR00
	ADC	TR01
	BCS	L_TimeAdd02
	CMP	#9AH
	BCC	L_TimeAdd03
L_TimeAdd02:
	ADC	#05FH
L_TimeAdd03:
	STA	0,X
	CLC
	RTS
;
;	A >> 4
AROR:
		ROR	A
		ROR	A
		ROR	A
		ROR	A
		AND	#0FH
		RTS
;
;	A << 4
AROL:
		ROL	A
		ROL	A
		ROL	A
		ROL	A
		AND	#F0H
		RTS
;
;------------------------------------------------------------------------------
;
;;;TR00 store Down value, TR00 store max value.
DEC_YMDHMS:				;input value for A,  max value for X
			STA	TR00
			TXA	
			STA	TR01
			JSR	DEC_COM
			LDA	TR00
			RTS	
		DEC_COM:
			SEC
			LDA	TR00
			SBC	#01
			BCC	DEC_COM_H	;if 
			STA	TR00
			AND	#0FH
			CMP	#0FH
			BEQ	End_DEC_COM
			RTS
		End_DEC_COM:
			LDA	TR00
			AND	#0F9H	;low set for 9
			STA	TR00
			RTS
		DEC_COM_H:
			LDA	TR01
			STA	TR00
			RTS
.END	




