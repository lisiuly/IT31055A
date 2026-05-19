;==========================================
; Compiler parameter define
;==========================================
;==========================================
.SYNTAX 6502 ; SYNTAX指定汇编器的语法格式
.LINKLIST
.SYMBOLS

;==========================================
; Constant define area
;==========================================

;==========================================
; Include file area
;==========================================

.INCLUDE		GPL813x.inc
.INCLUDE		SYS\Macro.inc
.INCLUDE		Alarm\Alarm.inc
.INCLUDE		RTC\RTC.inc
.INCLUDE		GXHTV4\GXHTV4.inc
.INCLUDE		LCD\LCD_Display.inc
.INCLUDE		KEY\KEY.inc
.INCLUDE		I2C\D_I2C.inc

;==========================================
; Include file area
;==========================================




;==========================================
; External declare area
;==========================================
.PUBLIC	R_2Hz 
.PUBLIC	R_128Hz
.PUBLIC	R_INTFlag
.PUBLIC F_2HzWakeUp
.PUBLIC Wait1_2Sec

;==========================================
; Public declare area
;==========================================
.PUBLIC	L_PowerOn
.PUBLIC V_RESET
;.PUBLIC		IOD_Attmap	
;.PUBLIC		IOD_Dirmap	
;.PUBLIC		IOD_Datmap
;==========================================
;Variable RAM declare area
;==========================================
.PAGE0 ; PAGE指定列在一页上的最大列数和一行上最大的字符数
R_2Hz		ds	1
R_128Hz		ds	1
R_INTFlag	ds	1

;IOD_Attmap	ds	1
;IOD_Dirmap	ds	1
;IOD_Datmap	ds	1
;==========================================
; code starting 
;==========================================
.CODE
V_RESET:
; User_Code_Start:
; Code_Start:
		SEI					; 置中断禁止位
		LDX		#FFH		;
		TXS					;x-->栈指针

		LDA		P_WAKEUP_Ctrl	;唤醒源代码控制寄存器
		TAX
		AND		#(D_WakeupKey+D_WakeupTMBA);+D_Wakeup128Hz) ;WakeupKey+TimeBaseA wake up(1/2hz)---------开启128Hz唤醒
		BEQ		L_PowerOn        ;No Wakeup     
		
        LDA		#00
		STA		P_WAKEUP_Ctrl    ;clear wakeup flag
			
		LDA		#0x20
		STA		P_CLK_CPU_Ctrl		; //after sleep mode wake up, sys=4M CPU=4M/1;			

		TXA
		AND		#D_WakeupTMBA  
;   	BNE		F_2HzWakeUp
		BEQ		F_keyWakeup    ;Judge Wakeup
		JMP		F_2HzWakeUp
;		TXA		
;		AND		#D_Wakeup128Hz
;		BNE		F_128HzWakeUp
;		

F_keyWakeup:
;       LDA		#D_TBL_Clr
;		STA		P_INT_Clear1   
		CLI
		nop
		JMP		L_ServiceLoop
		
F_2HzWakeUp:                           ;半秒 0.5s	  
  		LDA		#00
  		STA		R_2Hz
  		LDA		#D_TMBAInt
		STA		P_INT_TimeBaseA_Clear
  		JSR		F_2Hz_Cnt
	    JSR		F_CheckLowBattery
	    JSR		F_RealTimeClock   ;rtc		
	    JSR	    F_JudgeRFC		;温湿度检测	    	
	    JMP		L_ServiceLoop	
	    
F_128HzWakeUp:
		LDA		#00
		STA		R_128Hz
;		JSR		F_128Hz_Cnt
		JMP		L_ServiceLoop
		
L_PowerOn:  ;---------------------;POWER UP	开机		
		%InitSystem
		
		;CPU时钟选择
		LDA		#0x44					;0100 0100
		STA		P_CLK_CPU_Ctrl ;		; Set Fcpu = (500KHz) / 16
		nop
		LDA		#0x24					;0010 0100
		STA		P_CLK_CPU_Ctrl;			; Set Fcpu = (4MHz) / 16
		nop
		LDA		#0x20					;0010 0000
		STA		P_CLK_CPU_Ctrl		; //sys=4M cpu=4M/1;

		%ClrSRAM
		%InitLCD
		%F_InitINT	
		%F_Initinal_IO	
		JSR		F_ResetRealTimeClock	
		%bits	R_TimeStatus,AddOthers
		; %bits	R_TempFlag,D_WithRTRH
	
		LDA		#D_LVD_24		; 上电/唤醒后统一把低电检测门槛拉到 2.4V
		STA		P_LVD_Ctrl
		
		%FillLcdDpram #FFH
		CLI		
		JSR		F_UpdateTHFromGXHTV4		;上电同步读取一次温湿度
		LDA		#1
		STA     R_LEDTemp 
;		JSR		F_DC_Judge			
	Wait1_2Sec:
		%WatchDogClear		
		LDA		R_2Hz
		CMP		#06H		
		BCC		Wait1_2Sec
		
	Jump_DispAll:
		%FillLcdDpram #00H 
		JSR		F_initSet
;		%bits	R_KeyFlag,D_KeyTone	
;		JSR		F_PlayKeyTone
			
;================================================
L_ServiceLoop:
		%WatchDogClear
		JSR		F_KeyScan		;按键扫描
		JSR		F_PlayKeyTone	;按键音
	
;		JSR		F_DC_Judge
		JSR		F_Display
		
	?L_NoDispNormal:
		LDA		R_2Hz		;2Hz唤醒
		BEQ		$+5
		JMP		F_2HzWakeUp
		LDA		R_KeyValue		;按键
		BNE		L_ServiceLoop
		LDA		R_KeyTemp
		BNE		L_ServiceLoop
							
		LDA		R_128Hz
		BEQ		$+5
		JMP		F_128HzWakeUp
		
	?Next:	
		%btst	R_LEDFlag,D_LED_ON,L_ServiceLoop	
		%btst	R_KeyFlag,(D_ToneOn+D_Alarming),L_ServiceLoop		

		LDA		R_SoundOn
		BNE		L_ServiceLoop
	
	L_Enter_Sleep2Hz:
		LDA		#0x21
		STA		P_CLK_CPU_Ctrl		; //before enter sleep mode, sys=4M CPU=4M/2;	

		LDA		P_IO_PortE_DataLatch		
		LDA		#00h
		STA		P_WAKEUP_Ctrl	;clear wakeup flag
			
		LDA		#D_WakeupTMBA+D_WakeupKey	;+D_Wakeup128Hz
		STA		P_WAKEUP_Ctrl
		STA		P_SYSTEM_Ctrl
		NOP
		NOP
		JMP		V_RESET	

.END

