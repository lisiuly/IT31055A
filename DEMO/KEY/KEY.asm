.SYNTAX 6502
.LINKLIST
.SYMBOLS
;==========================================
; Include file area
;==========================================
.INCLUDE	GPL813X.inc
.INCLUDE	SYS\Macro.inc
.include	RTC\RTC.inc
.INCLUDE	SYS\Project.inc
.INCLUDE	Alarm\Alarm.inc
.INCLUDE	LCD\LCD_Display.inc
;.INCLUDE	RFC\RFC.inc
;==========================================
; External declare area
;==========================================   

;==========================================
; Public declare area
;==========================================
.PUBLIC	        F_KeyScan	

;==========================================
; Public declare area
;==========================================
;.PUBLIC		R_Option
.PUBLIC		R_Set
.PUBLIC		R_LEDFlag	
;.PUBLIC		R_LampTime		;play LED time
.PUBLIC		R_BLTime		
.PUBLIC		R_KeyValue		
.PUBLIC		R_KeyTemp		
;.PUBLIC		R_SpecFlag		
.PUBLIC		R_LongKeyTime	
.PUBLIC		R_SetBack					
.PUBLIC		R_OldKeyValue
.PUBLIC		R_DebounceCnt
.PUBLIC		R_LEDTemp
.PUBLIC		R_KeyFlag
.PUBLIC		F_Check_LED
;.PUBLIC		InitLED
;.PUBLIC		Enable_KeyTone
;.PUBLIC		Down_Month
;.PUBLIC		Sub_AlmMinute
;.PUBLIC		Down_Year
;.PUBLIC		Sub_AlmHour
;.PUBLIC		Sub_AlmHour
;.PUBLIC		Down_Day
.PUBLIC			R_KeyFlag1	
;==========================================
;Variable RAM declare area
;==========================================
.PAGE0
;R_Option		ds	1
R_Set			ds	1
D_SetConver		equ	02h
D_SetTimeHour	equ	04h
D_SetTimeMin	equ	08h
D_SetTimeMax	equ	10h

;D_SetAConver	equ	02h
D_SetAlarmHour	equ	02h
D_SetAlarmMin	equ	04h
D_SetAlarmMax	equ	08h

D_SetDateYear	equ	02h
D_SetDateMonth	equ	04h
D_SetDateDay	equ	08h
D_SetDateMax	equ	10h

D_SetHour	equ	02h
D_SetMin	equ	04h
D_SetMax	equ	08h

R_KeyFlag		ds	1
D_KeyTone		equ	01h
D_EnableFastAdd	equ	02h		
D_EnableAlarm	equ	04h
D_EnableSnooze	equ	08h
D_KeyRelDis		equ	10h
D_ToneOn		equ	20h
D_Alarming		equ	40h
D_24Mode		equ	80h		;must for bit7/24mode
	
R_KeyFlag1		ds	1
D_TimeFlag			equ		01h
D_Timering_Short	equ		02H
D_NoKeyTone			equ		04H
D_DC				equ		08H	
D_EnableSnooze1		equ		10h

R_LEDFlag		ds	1
D_LED_ON	equ		0x08		;无DC有小亮

;R_LampTime		ds	1		;play LED time
;D_LampTime		equ	20h

R_BLTime			ds	1
D_8SecBL			equ	16
D_2SecBL			equ	4
D_20Sec				equ	40
D_DefaultMoldValue	equ	65H
D_MoldValue60		equ	60H
D_MoldValue65		equ	65H
D_MoldValue70		equ	70H
D_MoldValue75		equ	75H

Key_Status			ds		1
R_LongKeyTime		ds		1		
	
R_TempTime			ds		1
R_SetBack			ds		1
C_Sleep20Sec	equ	40	
C_MoldSet10Sec	equ	20


;---------------------------------------------------
C_LongKey3Sec		equ		6
C_FastAdd			equ		24		;1秒加8次

R_KeyTemp			ds		1	
R_KeyValue			ds		1		
R_OldKeyValue		ds		1
D_KeyFcClear		equ		0x01
D_KeyAllTime		equ		0x02
D_KeyLight			equ		0x04
D_KeyUnused		equ		0x08


R_DebounceCnt		ds		1
C_KeyDebounce		equ		2	
;---------------------------------------------------
R_LEDTemp		ds	1

R_ToneDuty		ds	1
R_ToneVol		ds	1
;=====================================================
.CODE

F_KeyScan:	
		LDA		P_IO_PortE_Data
		AND		#(D_Bit2+D_Bit1+D_Bit0)
		BEQ		?ReleaseAllKey

		LDA		#00H
		STA		R_KeyTemp

		LDA		P_IO_PortE_Data
		AND		#D_Bit0
		BEQ		?L_CheckAllTimeKey
		LDA		R_KeyTemp
		ORA		#D_KeyAllTime
		STA		R_KeyTemp

	?L_CheckAllTimeKey:
		LDA		P_IO_PortE_Data
		AND		#D_Bit1
		BEQ		?L_CheckLightKey
		LDA		R_KeyTemp
		ORA		#D_KeyFcClear
		STA		R_KeyTemp

	?L_CheckLightKey:
		LDA		P_IO_PortE_Data
		AND		#D_Bit2
		BEQ		?L_HaveKey
		LDA		R_KeyTemp
		ORA		#D_KeyLight
		STA		R_KeyTemp

	?L_HaveKey:
		LDA		R_KeyTemp
		CMP		R_KeyValue
		BEQ		?CheckKeyDebounce
		LDA		R_KeyTemp
		STA		R_KeyValue
		LDA		#C_KeyDebounce
		STA		R_DebounceCnt
		CLI
		RTS
				
?ReleaseAllKey:					;按键释放
		%btst	R_KeyFlag,D_KeyRelDis,?L_Exit	
		LDA	R_OldKeyValue
		BEQ	?L_Exit
		
	?L_Dis_KeyTone:		
		LDA		R_OldKeyValue
		CMP		#D_KeyLight
		BNE		$+5		
		JMP		Enable_LightKey			

		CMP		#D_KeyAllTime
		BNE		$+5		
		JMP		Enable_AllTimeKey

		CMP		#D_KeyFcClear
		BNE		$+5		
		JMP		Enable_FcClearKey
		
	?L_Exit:		        ; 将按键值变量清零，退出
		LDA		#00
		STA		R_OldKeyValue
		STA		R_KeyValue
		STA		R_KeyTemp
		LDA	#C_KeyDebounce
		STA	R_DebounceCnt
		LDA	#C_LongKey3Sec
		STA	R_LongKeyTime
		%bitr	R_KeyFlag,(D_EnableFastAdd+D_KeyRelDis)
		RTS
		
?CheckKeyDebounce:
		LDA	R_DebounceCnt
		BEQ	?Key_Process		
		RTS	

	?Key_Process:
		LDA	R_KeyValue
		CMP	R_OldKeyValue
		BEQ	$+5
		JMP	Enable_NewKey	
		

Hold_Key:							;长按按键功能
		LDA		R_LongKeyTime
		BNE		?L_LongExit
		LDA		#C_LongKey3Sec
		STA		R_LongKeyTime
		LDA		R_OldKeyValue
		AND		#D_KeyAllTime
		BNE		?L_LongAllTimeKey
		LDA		R_OldKeyValue
		AND		#D_KeyFcClear
		BEQ		?L_LongExit
		JMP		Enable_longFcClearKey
	?L_LongAllTimeKey:
		JMP		Enable_longAllTimeKey
	?L_LongExit:
		RTS
				
Enable_NewKey:
		LDA		R_KeyValue
		STA		R_OldKeyValue		
		LDA		#C_LongKey3Sec
		STA		R_LongKeyTime	;长按3秒开始计时
		RTS
	
Enable_AllTimeKey:			; 切换历史页签/退出 Mold 页
		JSR		F_UpdateKey	
		LDA		R_ProductPage
		CMP		#D_PageMoldSet
		BEQ		Product_AllTimeExitMold
		CMP		#D_PageHistory
		BEQ		Product_AllTimeToggleHistory
		LDA		#D_PageHistory
		STA		R_ProductPage
		LDA		#D_His48Hr
		STA		R_HistoryPage
		RTS
Product_AllTimeToggleHistory:
		LDA		R_HistoryPage
		CMP		#D_His48Hr
		BEQ		Product_AllTimeSetAll
		CMP		#D_HisAllTm
		BEQ		Product_AllTimeSetToday
		LDA		#D_His48Hr
		STA		R_HistoryPage
		RTS
Product_AllTimeSetAll:
		LDA		#D_HisAllTm
		STA		R_HistoryPage
		RTS
Product_AllTimeSetToday:
		LDA		#D_PageStandard
		STA		R_ProductPage
		RTS
	Product_AllTimeExitMold:
		LDA		#D_PageStandard
		STA		R_ProductPage
		RTS
;===================FcClearKey======================	 		
Enable_FcClearKey:			; 短按切换 C/F，Mold 页循环阈值
		JSR		F_UpdateKey	
		LDA		R_ProductPage
		CMP		#D_PageMoldSet
		BNE		Product_FcClearToggleUnit
		JMP		F_MoldValueCycle

Product_FcClearToggleUnit:
		LDA		R_SpecFlag
		EOR		#D_TF
		STA		R_SpecFlag
		RTS

Enable_longFcClearKey:
		LDA		R_ProductPage
		CMP		#D_PageMoldSet
		BEQ		LongFcClearKey_Exit
		JSR		F_UpdateKey
		JMP		F_ClearCurrentHistory

LongFcClearKey_Exit:
		RTS

Enable_longAllTimeKey:
		LDA		R_ProductPage
		CMP		#D_PageStandard
		BNE		LongAllTimeKey_Exit
		JSR		F_UpdateKey
		LDA		#D_PageMoldSet
		STA		R_ProductPage
		LDA		#C_MoldSet10Sec
		STA		R_SetBack
		RTS

LongAllTimeKey_Exit:
		RTS
		
				
;==========================================
Enable_LightKey:	
		JSR		F_UpdateKey
		JMP		F_backlightOpen

F_MoldValueCycle:
		LDA		R_MoldSetValue
		CMP		#D_MoldValue60
		BEQ		MoldValueSet65
		CMP		#D_MoldValue65
		BEQ		MoldValueSet70
		CMP		#D_MoldValue70
		BEQ		MoldValueSet75
		LDA		#D_MoldValue60
		STA		R_MoldSetValue
		RTS

MoldValueSet65:
		LDA		#D_MoldValue65
		STA		R_MoldSetValue
		RTS

MoldValueSet70:
		LDA		#D_MoldValue70
		STA		R_MoldSetValue
		RTS

MoldValueSet75:
		LDA		#D_MoldValue75
		STA		R_MoldSetValue
		RTS


.PUBLIC		F_backlightOpen		
F_backlightOpen:
		CLI
		LDA		#D_LED_ON
		STA		R_LEDFlag
		LDA		P_IO_PortB_Data
		ORA		#D_Bit0
		STA		P_IO_PortB_Data
		LDA		#00H
		STA		R_LEDTemp
		LDA		#D_8SecBL
		STA		R_BLTime
		RTS

		
.PUBLIC		INT_PlayPWM
INT_PlayPWM:				;在中断里调用
	    LDA     R_LEDFlag
	    AND     #D_LED_ON
	    BEQ     ?DisLED		; 背光改成直接高低电平，不再做软件 PWM
		LDA		P_IO_PortB_Data
		ORA		#D_Bit0
		STA		P_IO_PortB_Data
		RTS

	?DisLED:
		LDA		P_IO_PortB_Data
		AND		#.not.D_Bit0
		STA		P_IO_PortB_Data
		RTS			
		
		
Check_1224Mode:		
		LDA	R_KeyFlag
		EOR	#D_24Mode
		STA	R_KeyFlag
		RTS		
.PUBLIC		F_PlayKeyTone		
F_PlayKeyTone:		;键音
		%btst	R_KeyFlag,D_Alarming,F_DisKeyToneDuringAlarm

		%btst	R_KeyFlag1,D_NoKeyTone,?Dis_KeyTone		
		%btst	R_KeyFlag,D_KeyTone,F_EnKeyTone		
	?Dis_KeyTone:	
		RTS	

F_DisKeyToneDuringAlarm:
		%bitr	R_KeyFlag,(D_KeyTone+D_ToneOn)
		LDA		#00H
		STA		R_KeyToneTm
		RTS
 F_EnKeyTone:
		CLI
		%bits	R_KeyFlag,D_ToneOn	
		LDA		#08
		STA		R_KeyToneTm	
		L_Loop:
		LDA		R_KeyToneTm
		BNE		L_Loop
		%bitr	R_KeyFlag,D_ToneOn
		RTS	
		
.PUBLIC		F_Judge_ToneIO	
F_Judge_ToneIO:		
		%bitr	R_KeyFlag1,D_NoKeyTone
		RTS

;===============================================================
	F_Check_LED:
		LDA		R_BLTime
		BEQ		?Exit_LED
		DEC		R_BLTime
		BNE		?Exit_LED
		LDA		#00
		STA		R_LEDFlag
		STA		R_LEDTemp
		LDA		P_IO_PortB_Data
		AND		#.not.D_Bit0
		STA		P_IO_PortB_Data
		?Exit_LED:		
		RTS
;==============================================================
F_UpdateKey:						
		%bits	R_KeyFlag,D_KeyTone
		%bits	R_KeyFlag,D_KeyRelDis	
F_UpdateKey2:							
		LDA		R_ProductPage
		CMP		#D_PageMoldSet
		BNE		StoreNormalTimeout
		LDA		#C_MoldSet10Sec
		BNE		StoreSetBackTime

StoreNormalTimeout:
		LDA		#C_Sleep20Sec

StoreSetBackTime:
		STA		R_SetBack
		%bits	R_TimeStatus,AddOthers			
		RTS	
		
.PUBLIC		F_2Hz_Cnt		
F_2Hz_Cnt:
		LDA		R_HistoryClearTm
		BEQ		CheckHistoryClearTimeout
		DEC		R_HistoryClearTm
		BNE		CheckHistoryClearTimeout
		%bits	R_TimeStatus,AddOthers

CheckHistoryClearTimeout:
		LDA		R_LongKeyTime
		BEQ		CheckKeyHoldTimeout
		DEC		R_LongKeyTime

CheckKeyHoldTimeout:
		jsr		Check_SetBackTime
		JSR		F_Check_LED
		JMP		F_Check_Temp
;		RTS
		
F_Check_Temp:
		%btsf	R_TempFlag1,(D_MaxTemp+D_MinTemp),?Exit_Check
		LDA		R_TempTime
		BEQ		?Exit_Check
		DEC		R_TempTime
		BNE		?Exit_Check
 		%bitr	R_TempFlag1,(D_MaxTemp+D_MinTemp) 
		?Exit_Check:		
		RTS		
	
Check_SetBackTime:
		LDA		R_SetBack
		BEQ		?L_Exit		
		dec		R_SetBack
		bne		?L_Exit	
		LDA		#00H
		STA		R_Set
		%bits	R_TimeStatus,AddOthers	
		LDA		#D_PageStandard
		STA		R_ProductPage
	?L_Exit:	
		RTS
		
;.PUBLIC		F_DC_Judge	
;F_DC_Judge:
;		LDA		P_IO_PortE_Data
;		AND		#D_Bit2
;		BNE		?L_HaveDC
;		%btsf	R_KeyFlag1,D_DC,?L_Exit		
;		%bitr	R_KeyFlag1,D_DC		
;		LDA		#00
;		STA		R_LEDFlag
; 		LDA     #$25        ;中亮占空比
;  		STA     R_ToneVol
;  	?L_Exit:	
;  		RTS
;	?L_HaveDC:
;		%btst	R_KeyFlag1,D_DC,?L_Exit	
;		%bits	R_KeyFlag1,D_DC			
;		JMP		HasDC_LED_1		
;;		RTS	
;	
.PUBLIC		F_initSet		
F_initSet:
		; LDA		#D_TimeMode
		; STA		R_Mode
		LDA		#00H
		STA		R_Set
		LDA		#D_PageStandard
		STA		R_ProductPage
		LDA		#D_His48Hr
		STA		R_HistoryPage
		LDA		#D_DefaultMoldValue
		STA		R_MoldSetValue
		LDA		#C_Sleep20Sec
		STA		R_SetBack
		JMP		F_Start_RFCMM_Value
;		RTS
	
.end





