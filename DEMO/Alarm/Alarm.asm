.SYNTAX 6502
.LINKLIST
.SYMBOLS
;==========================================
; Include file area
;==========================================
.INCLUDE	GPL813x.inc
.INCLUDE	SYS\Project.inc
.INCLUDE	SYS\Macro.inc
.INCLUDE	KEY\KEY.inc
.INCLUDE	RTC\RTC.inc
.INCLUDE	LCD\LCD_Display.inc
.INCLUDE	GXHTV4\GXHTV4.inc

.EXTERN		F_ReadGXHTV4Data
.EXTERN		TEMP_INTEGAH
.EXTERN		TEMP_INTEGAL
.EXTERN		HUM
;==========================================
; Public declare area
;==========================================
;.PUBLIC			R_PortD_Data_Buf
.PUBLIC			R_KeyToneTm
.PUBLIC			R_SoundOn
.PUBLIC			R_BatteryFlags
.PUBLIC			F_MoldAlarm128Hz
.PUBLIC			F_CheckLowBattery
.PUBLIC			F_LoadHistoryViewBuffers
.PUBLIC			F_ClearCurrentHistory
;==========================================
;Variable RAM declare area
;==========================================
RFCRAM	.section

R_SoundOn		ds	1
R_KeyToneTm		ds	1
R_MoldAlarmTm	ds	1
R_MoldAlarmIdx	ds	1
R_BatteryFlags	ds	1
R_BatteryDetCnt	ds	1
;R_PortD_Data_Buf	ds	1
R_TempCH		ds	1
R_TempCL		ds	1
R_HUM			ds	1

C_MoldDefaultThreshold	equ	65H
D_BatteryLow		equ	0x01
C_BatteryDetDebounce	equ	5

; history 状态位。
; 当前实现保留 Today / 48HrToday / Previous Day / All-time 四套记录。
; 48hr 页面显示的是独立 48HrToday + Previous Day 的聚合结果，
; 因此清 Today 不会影响 48hr。
R_HistoryFlags	ds	1
D_HistoryInit		equ	0x01
D_HisValid			equ	0x01
D_HisTempValid	equ	0x02
D_HisMaxNeg		equ	0x80
D_HisMinNeg		equ	0x40

R_TodayRecFlags		ds	1
R_TodayRecTempMax	ds	2
R_TodayRecTempMaxF	ds	2
R_TodayRecTempMin	ds	2
R_TodayRecTempMinF	ds	2
R_TodayRecHumMax	ds	1
R_TodayRecHumMin	ds	1

R_48TodayRecFlags	ds	1
R_48TodayRecTempMax		ds	2
R_48TodayRecTempMaxF	ds	2
R_48TodayRecTempMin		ds	2
R_48TodayRecTempMinF	ds	2
R_48TodayRecHumMax	ds	1
R_48TodayRecHumMin	ds	1

R_PrevRecFlags		ds	1
R_PrevRecTempMax	ds	2
R_PrevRecTempMaxF	ds	2
R_PrevRecTempMin	ds	2
R_PrevRecTempMinF	ds	2
R_PrevRecHumMax	ds	1
R_PrevRecHumMin	ds	1

R_AllRecFlags		ds	1
R_AllRecTempMax		ds	2
R_AllRecTempMaxF	ds	2
R_AllRecTempMin		ds	2
R_AllRecTempMinF	ds	2
R_AllRecHumMax	ds	1
R_AllRecHumMin	ds	1

; 每条 history record 固定占 11 字节：
; Flags(1) + TempMax(2) + TempMaxF(2) + TempMin(2) + TempMinF(2) + HumMax(1) + HumMin(1)
C_HisRecSize		equ	0BH
C_HisRecToday		equ	00H
C_HisRec48Today	equ	0BH	; 第 2 条记录起点 = 1 * C_HisRecSize
C_HisRecPrev		equ	16H	; 第 3 条记录起点 = 2 * C_HisRecSize
C_HisRecAll		equ	21H	; 第 4 条记录起点 = 3 * C_HisRecSize

; 清记录后用 3 秒 dash 覆盖当前记录显示。
R_HistoryClearTm	ds	1
R_HistoryViewFlags	ds	1
D_HistoryViewValid	equ	0x01
D_HistoryViewTempValid	equ	0x02
C_HistoryClear3Sec	equ	6

; 趋势状态按窗口法统计：记录窗口 max/min，并用 60 次采样计数决定是否显示平缓。
R_TrendFlags		ds	1
D_TrendInit			equ	0x01
D_TempTrendUp		equ	0x02
D_TempTrendDown	equ	0x04
D_HumTrendUp		equ	0x08
D_HumTrendDown	equ	0x10
D_TempTrendRefresh	equ	0x20
D_HumTrendRefresh	equ	0x40
R_TrendTempMaxH	ds	1
R_TrendTempMaxL	ds	1
R_TrendTempMinH	ds	1
R_TrendTempMinL	ds	1
R_TrendHumMax	ds	1
R_TrendHumMin	ds	1
R_TrendTempEqCnt	ds	1
R_TrendHumEqCnt	ds	1
C_TrendEq60Min	equ	60
C_TrendTempSpanTrig	equ	0BH	; 温度窗口跨度 > 1.0℃ 时触发方向趋势（0.1℃ 分辨率）
C_TrendHumSpanTrig	equ	06H	; 湿度窗口跨度 > 5%RH 时触发方向趋势（整数 %RH）

;---------------------------------------
.PUBLIC		R_TempCH
.PUBLIC		R_TempCL
.PUBLIC		R_HUM
.PUBLIC		R_TrendFlags
.PUBLIC		R_TrendTempEqCnt
.PUBLIC		R_TrendHumEqCnt
.PUBLIC		R_SpecFlag
.PUBLIC		R_TempMin_Sign
.PUBLIC		R_TempMax_Sign
.PUBLIC		R_DispTemper_F
.PUBLIC		R_MAXDispTemper_F
.PUBLIC		R_MINDispTemper_F
.PUBLIC		R_DispTemper
.PUBLIC		R_TempMax
.PUBLIC		R_TempMin
.PUBLIC		R_DispHum
.PUBLIC		R_HumMax
.PUBLIC		R_HumMin
.PUBLIC		R_TempFlag1
.PUBLIC		R_HistoryClearTm
.PUBLIC		R_HistoryViewFlags
R_SpecFlag		ds	1
R_TempMin_Sign	ds	1
R_TempMax_Sign	ds	1
R_HumMin_Sign	ds	1
R_HumMax_Sign	ds	1
D_HumHH				equ	0x80
D_TempHH			equ	0x40
D_TempLL			equ	0x20
D_Neg				equ 0x10	;负温度
D_TF				equ 0x08	;华氏度
D_HumLL				equ	0x02
C_HumRaw100		equ	64H
C_HumDisp99		equ	99H

R_DispTemper_F		ds  2
R_MAXDispTemper_F	ds  2
R_MINDispTemper_F	ds  2
R_DispTemper	ds  2	
R_TempMax       ds  2    ; 最高温度记录(BCD码，带符号)
R_TempMin       ds  2    ; 最低温度记录(BCD码，带符号)
R_DispHum		ds	1
R_HumMax    	ds	1    ; 最高湿度记录(BCD码，无符号)
R_HumMin     	ds	1    ; 最低湿度记录(BCD码，无符号)
R_TempFlag1		ds	1
D_MaxTemp		equ	0x01
D_MinTemp		equ	0x02

.CODE
;-------------------------------------------------------
; 函数: F_JudgeRFC
; 作用: 温湿度采样的统一入口，只在允许采样的时间点触发一次刷新。
; 输入: R_KeyFlag、RTC+2、R_TimeStatus.HalfSecToggle。
; 输出: 满足条件时跳到 F_UpdateTHFromGXHTV4 刷新温湿度；否则直接返回。
; 说明: 这里用“整分 00 秒 + 半秒翻转边沿”双重门控，避免同一分钟内重复采样。
.PUBLIC     F_JudgeRFC
F_JudgeRFC:					; 温度湿度RFC检测模块
    %btst	R_KeyFlag,D_KeyRelDis,ExitJudge

    ; 规格改为 60 秒采样，只在整分 00 秒触发一次。
    LDA     RTC+2
    CMP     #00H
    BNE     ExitJudge

CheckHalfSecToggle:
    ; 同步读取 GXHTV4，只在一个半秒边沿触发一次，避免 00/30 秒重复采样
    %btst   R_TimeStatus, HalfSecToggle, ExitJudge
    JMP     F_UpdateTHFromGXHTV4

;-------------------------------------------------------
; 函数: F_UpdateTHFromGXHTV4
; 作用: 从 GXHTV4 读取原始温湿度值，并回填到 Alarm 兼容变量。
; 输入: 外设读数 TEMP_INTEGAH/TEMP_INTEGAL/HUM。
; 输出: R_TempCH、R_TempCL、R_HUM 被更新，然后转入 CalculateRFC。
; 说明: 该函数只负责“采样搬运”，不做显示格式转换和极值更新。
.PUBLIC		F_UpdateTHFromGXHTV4
F_UpdateTHFromGXHTV4:
    JSR		F_ReadGXHTV4Data
    LDA		TEMP_INTEGAH
    STA		R_TempCH
    LDA		TEMP_INTEGAL
    STA		R_TempCL
    LDA		HUM
    STA		R_HUM
    JMP		CalculateRFC

;-------------------------------------------------------
; 函数: CalculateRFC
; 作用: 根据原始温度高字节的符号位设置当前温度正负标志，并进入温湿度换算主链。
; 输入: R_TempCH 的 bit7 符号位。
; 输出: R_SpecFlag.D_Neg 被更新，随后跳到 F_GetTHVlaue。
; 说明: 这里只做符号判定，不直接修改温度数值本身。
.PUBLIC		CalculateRFC
CalculateRFC:
    ; 温度符号检查
    LDA     R_TempCH
    AND     #80H
    BEQ     TemperatureIsPositive

    ; 温度为负值
    %bits   R_SpecFlag, D_Neg

LoadTemperatureValue:
    %bits   R_TimeStatus, AddOthers
    JMP     F_GetTHVlaue

TemperatureIsPositive:
    %bitr   R_SpecFlag, D_Neg
    JMP     LoadTemperatureValue

ExitJudge:
    RTS

;-------------------------------------------------------
; 函数: F_CheckLowBattery
; 作用: 读取 LVD 状态并做去抖，稳定后更新低电池标志。
; 输入: P_LVD_Ctrl.D_LVD_State、R_BatteryFlags、R_BatteryDetCnt。
; 输出: R_BatteryFlags.D_BatteryLow 可能被置位/清位，R_BatteryDetCnt 计数更新。
; 说明: 只有连续多次采样结果一致后才真正改标志，避免电压边缘抖动导致误报。
F_CheckLowBattery:
    LDA		P_LVD_Ctrl
    AND		#D_LVD_State
    BNE		BatterySampleLow

BatterySampleHigh:
    LDA		R_BatteryFlags
    AND		#D_BatteryLow
    BEQ		BatteryClearCounter
    INC		R_BatteryDetCnt
    LDA		R_BatteryDetCnt
    CMP		#C_BatteryDetDebounce
    BCC		BatteryExit
    LDA		R_BatteryFlags
    AND		#.not.D_BatteryLow
    STA		R_BatteryFlags
    %bits   R_TimeStatus, AddOthers
    LDA		#00H
    STA		R_BatteryDetCnt
    RTS

BatterySampleLow:
    LDA		R_BatteryFlags
    AND		#D_BatteryLow
    BNE		BatteryLowKeep
    INC		R_BatteryDetCnt
    LDA		R_BatteryDetCnt
    CMP		#C_BatteryDetDebounce
    BCC		BatteryExit
    LDA		R_BatteryFlags
    ORA		#D_BatteryLow
    STA		R_BatteryFlags
    %bits   R_TimeStatus, AddOthers

BatteryLowKeep:
    LDA		#00H
    STA		R_BatteryDetCnt
    RTS

BatteryClearCounter:
    LDA		#00H
    STA		R_BatteryDetCnt

BatteryExit:
    RTS

;-------------------------------------------------------
; 函数: F_MoldAlarm128Hz
; 作用: 以 128Hz 节拍驱动霉菌报警的开关节奏。
; 输入: R_MoldSetValue、R_DispHum、R_MoldAlarmTm、R_MoldAlarmIdx。
; 输出: R_SoundOn、R_MoldAlarmTm、R_MoldAlarmIdx。
; 说明: 当湿度达到阈值后，按 T_MoldAlarmPattern 预定义的节奏循环鸣叫。
F_MoldAlarm128Hz:
    LDA		R_MoldSetValue
    BNE		MoldAlarm_CheckHum
    LDA		#C_MoldDefaultThreshold

MoldAlarm_CheckHum:
    CMP		R_DispHum
    BCC		MoldAlarm_Active
    BEQ		MoldAlarm_Active

MoldAlarm_Stop:
    LDA		#00H
    STA		R_SoundOn
    STA		R_MoldAlarmTm
    STA		R_MoldAlarmIdx
	%bitr	R_KeyFlag,D_Alarming
    RTS

MoldAlarm_Active:
	%bits	R_KeyFlag,D_Alarming
    LDA		R_MoldAlarmTm
    BEQ		MoldAlarm_LoadStep
    DEC		R_MoldAlarmTm
    RTS

MoldAlarm_LoadStep:
    LDX		R_MoldAlarmIdx
    LDA		T_MoldAlarmPattern,X
    CMP		#0FFH
    BNE		MoldAlarm_StoreStep
    LDX		#00H
    STX		R_MoldAlarmIdx
    LDA		T_MoldAlarmPattern

MoldAlarm_StoreStep:
    STA		R_MoldAlarmTm
    LDA		T_MoldAlarmPattern+1,X
    STA		R_SoundOn
    INX
    INX
    STX		R_MoldAlarmIdx
    RTS

T_MoldAlarmPattern:
    DB		08,01,08,00
    DB		08,01,08,00
    DB		08,01,08,00
    DB		08,01,72,00
    DB		0FFH

;-------------------------------------------------------
; 输入：R_TempCH, R_TempCL - 温度值(高字节和低字节)
;       R_HUM - 湿度值
; 输出：R_DispTemper - 摄氏度温度显示值(BCD格式)
;       R_DispTemper_F - 华氏度温度显示值(BCD格式)
;       R_DispHum - 湿度显示值(BCD格式)
; 说明：这是 Alarm 模块的主处理链，依次完成温度换算、湿度换算、HH/LL 判定、极值更新、趋势更新和历史记录更新。
.PUBLIC     F_GetTHVlaue
F_GetTHVlaue:				; 获取温湿度值并转换为显示格式
    JSR     ProcessTemperature
    JSR     ProcessHumidity
    JSR     F_Judge_HHLL
    JSR     UpdateExtremeValues
    JSR		F_UpdateTrendState
    JMP		F_HistoryOnSample

;-------------------------------------------------------
; 函数: F_RefreshTrendFlags
; 作用: 兼容保留的空实现。
; 说明: 旧版“累计步进”趋势算法曾在这里统一刷新箭头；新窗口算法已直接在 F_UpdateTempTrendState / F_UpdateHumTrendState 内决定方向，
;       因此该入口保留为 RTS，避免旧调用点或阅读路径产生歧义。
F_RefreshTrendFlags:
    RTS

;-------------------------------------------------------
; 函数: ProcessTemperature
; 作用: 把当前温度原始值转成摄氏 BCD，并继续生成华氏显示值。
; 输入: R_TempCH、R_TempCL。
; 输出: R_DispTemper、R_DispTemper_F。
; 说明: 温度符号位在 CalculateRFC 中处理，这里先按绝对值转摄氏，再调用华氏换算。
ProcessTemperature:
    ; 处理摄氏度温度
    LDA     R_TempCH
    AND     #7FH                ; 清除符号位
    TAX
    LDA     R_TempCL
    
ConvertTemperatureToBCD:
    JSR     F_CAL_HEX_BCD2      ; 转换为BCD格式
    
    ; ; 保存温度显示值(BCD格式)
    ; LDA     OUT_M
    ; STA     R_DispTemper        ; 百位和十位
    ; ASL     R_DispTemper        ; 将十位左移4位，为个位腾出位置
    ; ASL     R_DispTemper
    ; ASL     R_DispTemper
    ; ASL     R_DispTemper
    
    ; LDA     OUT_L
    ; LSR     A                   ; 将个位右移4位
    ; LSR     A
    ; LSR     A
    ; LSR     A
    ; ORA     R_DispTemper        ; 合并十位和个位
    ; STA     R_DispTemper        ; 保存完整的温度值(十位个位)
    LDA     OUT_M
    STA     R_DispTemper+0    ; 百位和十位
    LDA     OUT_L
    STA     R_DispTemper+1    ; 个位和小数位	   
    ; 转换并保存华氏度温度
    JMP     ConvertToFahrenheit
 ;   RTS    
;-------------------------------------------------------
; 函数: ConvertToFahrenheit
; 作用: 将当前摄氏原始值转换成华氏值，并保存为 BCD 显示格式。
; 输入：R_TempCH, R_TempCL - 摄氏度温度值
; 输出：R_DispTemper_F - 华氏度温度显示值(BCD格式)
ConvertToFahrenheit:
    LDA     R_TempCH
    TAX
    LDA     R_TempCL
    JSR     F_CHANGE_CF         ; 调用摄氏度转华氏度函数
    
    ; 转换华氏度值为BCD格式
    LDX     X_M
    LDA     X_L
    JSR     F_CAL_HEX_BCD2
    
    ; 保存华氏度显示值
    LDA     OUT_M
    STA     R_DispTemper_F+0    ; 百位和十位
    LDA     OUT_L
    STA     R_DispTemper_F+1    ; 个位和小数位	
    RTS
    
;-------------------------------------------------------
; 函数: ProcessHumidity
; 作用: 把原始湿度值转换成 BCD 显示格式。
; 输入：R_HUM - 湿度值
; 输出：R_DispHum - 湿度显示值(BCD格式)
ProcessHumidity:
    LDA     R_HUM               ; 读取湿度值
	CMP		#C_HumRaw100
	BCC		ProcessHumidity_ConvertBCD
	LDA		#C_HumDisp99
	STA		R_DispHum           ; 两位湿度显示链路对 100%RH 做 99 封顶
	RTS

ProcessHumidity_ConvertBCD:
	LDX		#00
    LDA     R_HUM               ; 读取湿度值
    JSR     F_CAL_HEX_BCD2      ; 转换为BCD格式
    
    ; 保存湿度显示值
    LDA     OUT_L
    STA     R_DispHum           ; 保存湿度显示值(0-99%)
    RTS
    
;-------------------------------------------------------
;;判断温湿度有无超过上下限
; 输入：R_HUM R_DispTemper
; 输出：SpecFlag,(D_TempLL+D_TempHH+D_HumLL+D_HumHH)
; 说明：先清掉旧的 HH/LL 标志，再分别调用温度和湿度判断逻辑重算当前报警状态。
F_Judge_HHLL:		;判断温湿度有无超过上下限
     %bitr    R_SpecFlag,(D_TempLL+D_TempHH+D_HumLL+D_HumHH)	
	JSR		F_Judge_TempHHLL	
	JMP		F_Judge_HumHHLL	
;	RTS
	
F_Judge_TempHHLL:	
    %btst    R_SpecFlag,D_Neg,?L_JudgeLL   
    LDA		R_DispTemper+0		;判断有无超过上下限
        CMP		#0x05
        BCC		?L_Exit
        BNE		?L_SetHH
        LDA		R_DispTemper+1
        BEQ		?L_Exit
     ?L_SetHH:
         %bits    R_SpecFlag,D_TempHH	
   ?L_Exit: 
   	RTS   
    ?L_JudgeLL:
    LDA		R_DispTemper+0	
    CMP		#0x01
    BCC		?L_Exit
     %bits    R_SpecFlag,D_TempLL
   	RTS 
    
F_Judge_HumHHLL: 	
	LDA		R_HUM
	CMP		#C_HumRaw100
	BCC		JudgeHumHHLL_CheckDisp
	%bits    R_SpecFlag,D_HumHH 
	RTS

JudgeHumHHLL_CheckDisp:
    LDA		R_DispHum		;判断有无超过上下限
    CMP		#0x99
    BEQ		?L_Next
    BCC		?L_Next 
    %bits    R_SpecFlag,D_HumHH 
    RTS
   ?L_Next:
    LDA		R_DispHum  
	CMP		#0x01
    BCS		?L_Exit
    %bits    R_SpecFlag,D_HumLL
    ?L_Exit:
    RTS

;-------------------------------------------------------
; 函数: F_IsCurrentTempInRange
; 作用: 根据当前 HH/LL 标志判断温度是否仍处于可记录的显示范围内。
; 输出: C=1 表示当前温度在 -9.9~50.0 的记录范围内；C=0 表示已进入 HH/LL。
F_IsCurrentTempInRange:
	LDA		R_SpecFlag
	AND		#(D_TempHH+D_TempLL)
	BEQ		CurrentTempInRange
	CLC
	RTS

CurrentTempInRange:
	SEC
	RTS
        
; 更新温湿度极值记录(BCD格式)
; 输入：R_DispTemper - 当前温度值(BCD格式)
;       R_DispHum - 当前湿度值(BCD格式)
;       R_TempMax, R_TempMin - 温度最高/最低记录(BCD格式)
;       R_HumMax, R_HumMin - 湿度最高/最低记录(BCD格式)
; 说明：先更新温度极值，再更新湿度极值；两部分共享当前采样值，但比较规则不同。
UpdateExtremeValues:
    ; 更新温度极值
    JSR		F_IsCurrentTempInRange
    BCC		UpdateExtremeValues_SkipTemp
    JSR     UpdateTemperatureExtremes
    
    ; 更新湿度极值
UpdateExtremeValues_SkipTemp:
    JMP     UpdateHumidityExtremes
 ;   RTS
    
;-------------------------------------------------------
; 更新温度极值记录(BCD格式，符号位与数值分离)
; 输入：R_DispTemper - 当前温度值(BCD格式，正数)
;       R_SpecFlag.D_Neg - 当前温度符号(1=负，0=正)
;       R_TempMax, R_TempMin - 温度最高/最低记录(BCD格式)
;       R_TempMax_Sign, R_TempMin_Sign - 温度符号记录(1=负，0=正)
; 输出：更新R_TempMax, R_TempMin, R_TempMax_Sign, R_TempMin_Sign
; 说明：温度极值比较需要把“符号”和“绝对值”分开处理，因此正温、负温、跨零三类路径都是分支展开的。
UpdateTemperatureExtremes:
    ; 比较当前温度与最高温度记录
    LDA     R_SpecFlag
    AND     #D_Neg              ; 当前温度符号
    BNE     CurrentTempIsNeg_1    ; 当前温度为负
    
    ; 当前温度为正
    LDA     R_TempMax_Sign
    AND     #D_Neg              ; 当前温度符号    
    BNE     UpdateTempMax       ; 最高温度为负，当前为正，直接更新

    ; 两者均为正，比较数值
    LDA     R_DispTemper+0    ; 当前温度百位和十位
    CMP     R_TempMax+0    ; 最高温度百位和十位
    BEQ     CompareTempMaxLow   ; 百位和十位相等，比较个位和小数位
    BCS     UpdateTempMax       ; 当前温度>最高记录，更新最高温度
    JMP     CheckTempMin        ; 当前温度<最高记录，检查最低记录

CompareTempMaxLow:
    LDA     R_DispTemper+1    ; 当前温度个位和小数位
    CMP     R_TempMax+1    ; 最高温度个位和小数位
    BCC     CheckTempMin        ; 当前温度<最高记录，检查最低记录
    BEQ     CheckTempMin        ; 当前温度=最高记录，检查最低记录
    JMP     UpdateTempMax       ; 当前温度>最高记录，更新最高温度
    
UpdateTempMax:
    ; 更新最高温度记录
    LDA     R_DispTemper+0    
    STA     R_TempMax+0    ; 百位和十位
    LDA     R_DispTemper+1
    STA     R_TempMax+1    ; 个位和小数位
    
    LDA     R_SpecFlag
;    AND     #D_Neg
    STA     R_TempMax_Sign      ; 更新符号位    	
    LDA     R_DispTemper_F+0    ; 百位和十位
    STA		R_MAXDispTemper_F+0 
    LDA     R_DispTemper_F+1    ; 个位和小数位    
    STA		R_MAXDispTemper_F+1    	
    LDA		R_TempFlag
    AND		#D_TempFReg
    ORA		R_TempMax_Sign
    STA		R_TempMax_Sign
    JMP     CheckTempMin
CurrentTempIsNeg_1:    
	JMP   	CurrentTempIsNeg    
CheckTempMin:
    ; 检查当前温度符号
    LDA     R_SpecFlag
    AND     #D_Neg
    BNE     CurrentTempNegMin   ; 当前温度为负
    
    ; 当前温度为正
    LDA     R_TempMin_Sign
    AND     #D_Neg              ; 当前温度符号
    BNE     ExitTempUpdate       ; 最低温度为负，当前为正，不更新
    
    ; 两者均为正，比较数值
    LDA     R_DispTemper+0    ; 当前温度百位和十位
    CMP     R_TempMin+0
    BEQ     CompareTempMinLow   ; 百位和十位相等，比较个位和小数位
    BCC     UpdateTempMin       ; 当前温度<最低记录，更新最低温度
    JMP     ExitTempUpdate      ; 当前温度>最低记录，不更新
CompareTempMinLow:
    LDA     R_DispTemper+1    ; 当前温度个位和小数位
    CMP     R_TempMin+1
    BCS     ExitTempUpdate      ; 当前温度>最低记录，不更新
    JMP     UpdateTempMin       ; 当前温度<最低记录，更新最低温度
    
UpdateTempMin:
    ; 更新最低温度记录
    LDA     R_DispTemper+0
    STA     R_TempMin+0
    LDA     R_DispTemper+1
    STA     R_TempMin+1
    LDA     R_SpecFlag
;    AND     #D_Neg
    STA     R_TempMin_Sign      ; 更新符号位
    LDA     R_DispTemper_F+0    ; 百位和十位
    STA		R_MINDispTemper_F+0 
    LDA     R_DispTemper_F+1    ; 个位和小数位    
    STA		R_MINDispTemper_F+1    	
    LDA		R_TempFlag
    AND		#D_TempFReg
    ORA		R_TempMin_Sign
    STA		R_TempMin_Sign
    JMP     ExitTempUpdate
    
ExitTempUpdate:
    RTS    
	
CurrentTempIsNeg:
    ; 当前温度为负
    LDA     R_TempMax_Sign
    AND     #D_Neg              ; 当前温度符号    
    BNE     CompareNegativeMax  ; 最高温度也为负，比较数值
    
    ; 最高温度为正，当前为负，不更新
    JMP     CheckTempMin
    
CompareNegativeMax:
    ; 两者均为负，比较数值
    LDA     R_DispTemper+0
    CMP     R_TempMax+0
    BEQ     CompareNegativeMaxLow   ; 百位和十位相等，比较个位和小数位
    BCS     CheckTempMin        ; 当前温度>=最高记录（负数比较：绝对值越小，值越大）
    JMP     UpdateTempMax       ; 当前温度<最高记录，更新最高温度

CompareNegativeMaxLow:
    LDA     R_DispTemper+1    ; 当前温度个位和小数位
    CMP     R_TempMax+1
    BCS     CheckTempMin      ; 当前温度>=最高记录，不更新
    JMP     UpdateTempMax     ; 当前温度<最高记录，更新最高温度
    
    
CurrentTempNegMin:
    ; 当前温度为负
    LDA     R_TempMin_Sign
    AND     #D_Neg              ; 当前温度符号    
    BNE     CompareNegativeMin  ; 最低温度也为负，比较数值
    
    ; 最低温度为正，当前为负，更新
    JMP     UpdateTempMin
    
CompareNegativeMin:
    ; 两者均为负，比较数值
    LDA     R_DispTemper+0
    CMP     R_TempMin+0
    BEQ     CompareNegativeMinLow   ; 百位和十位相等，比较个位和小数位
    BCS     UpdateTempMin       ; 当前温度<最低记录（负数比较：绝对值越大，值越小）
    ; 当前温度>=最低记录，不更新
    JMP     ExitTempUpdate    
CompareNegativeMinLow:
    LDA     R_DispTemper+1    ; 当前温度个位和小数位
    CMP     R_TempMin+1
    BCS     ExitTempUpdate      ; 当前温度>=最低记录，不更新
    JMP     UpdateTempMin       ; 当前温度<最低记录，更新最低温度

    

;    RTS			
    
;-------------------------------------------------------
; 更新湿度极值记录(BCD格式，无符号比较)
; 输入：R_DispHum - 当前湿度值(BCD格式)
;       R_HumMax, R_HumMin - 湿度最高/最低记录(BCD格式)
; 输出：更新R_HumMax, R_HumMin
; 说明：湿度没有正负号，因此直接按无符号大小更新最大/最小值即可。
UpdateHumidityExtremes:
    ; 比较当前湿度与最高湿度记录
    LDA     R_DispHum
    CMP     R_HumMax
    BCC     CheckHumMin         ; 如果当前湿度<=最高记录，检查最低记录
    
    ; 当前湿度>最高记录，更新最高湿度
    LDA     R_DispHum
    STA     R_HumMax
    LDA		R_SpecFlag
	STA		R_HumMax_Sign    
	RTS
CheckHumMin:
    ; 比较当前湿度与最低湿度记录
    LDA     R_DispHum
    CMP     R_HumMin
    BCS     ExitHumUpdate       ; 如果当前湿度>=最低记录，直接退出
    
    ; 当前湿度<最低记录，更新最低湿度
    LDA     R_DispHum
    STA     R_HumMin
    LDA		R_SpecFlag
    STA		R_HumMin_Sign
ExitHumUpdate:
    RTS    
;============================================================
; 温湿趋势判断 —— 窗口规格说明：
;   首次采样：当前值同时作为窗口 max/min，计数清零。
;   后续采样：当前值先尝试刷新窗口 max/min，再累计一次计数。
;   温度：当窗口 max-min > 1.0℃ 时，若本次刷新的是 max 则显示 Up，刷新的是 min 则显示 Down。
;   湿度：当窗口 max-min > 5%RH 时，若本次刷新的是 max 则显示 Up，刷新的是 min 则显示 Down。
;   方向触发后：该项目的窗口 max/min 重置为当前值，计数清零。
;   若 60 次采样内窗口跨度始终未触发阈值，则 EqCnt 饱和到 60，显示平缓。
;============================================================
; 函数: F_UpdateTrendState
; 作用: 趋势窗口算法入口，分别更新温度和湿度趋势状态。
; 输入: 当前温湿度原始值，以及窗口内保存的 max/min/counter。
; 输出: R_TrendFlags 的 Up/Down/Refresh 位，以及 R_TrendTempEqCnt/R_TrendHumEqCnt。
; 说明: 这里只保留 Init 位，方向位和刷新位只在本次采样真正触发图标变化时重新置位。
F_UpdateTrendState:
    LDA     R_TrendFlags
    AND     #D_TrendInit
    BEQ     F_TrendSeedCurrent
    STA     R_TrendFlags
    JSR     F_UpdateTempTrendState
    JMP     F_UpdateHumTrendState

;-------------------------------------------------------
; 函数: F_TrendSeedCurrent
; 作用: 首次进入趋势逻辑时，用当前值建立温湿度窗口，并主动把趋势图标刷成平缓。
; 输出: Temp/Hum 窗口 max/min 均被初始化为当前值，EqCnt 置为 60，刷新位被置位。
F_TrendSeedCurrent:
    LDA     #D_TrendInit
    STA     R_TrendFlags
    JSR     F_TrendResetTempWindowCurrent
    JSR     F_TrendResetHumWindowCurrent
    LDA     #C_TrendEq60Min
    STA     R_TrendTempEqCnt
    STA     R_TrendHumEqCnt
    LDA     #(D_TrendInit+D_TempTrendRefresh+D_HumTrendRefresh)
    STA     R_TrendFlags
    RTS

;-------------------------------------------------------
; 函数: F_TrendResetTempWindowCurrent
; 作用: 温度窗口重置为“当前值即 max/min”，并清零温度计数。
F_TrendResetTempWindowCurrent:
    LDA     R_TempCH
    STA     R_TrendTempMaxH
    STA     R_TrendTempMinH
    LDA     R_TempCL
    STA     R_TrendTempMaxL
    STA     R_TrendTempMinL
    LDA     #00H
    STA     R_TrendTempEqCnt
    RTS

;-------------------------------------------------------
; 函数: F_TrendResetHumWindowCurrent
; 作用: 湿度窗口重置为“当前值即 max/min”，并清零湿度计数。
F_TrendResetHumWindowCurrent:
    LDA     R_HUM
    STA     R_TrendHumMax
    STA     R_TrendHumMin
    LDA     #00H
    STA     R_TrendHumEqCnt
    RTS

;-------------------------------------------------------
; 函数: F_UpdateTempTrendState
; 作用: 按温度窗口 max/min 的扩张方向判定 Up/Down；若未触发则累计温度计数。
; 说明: 当前样本只有在刷新了窗口 max 或 min 时，才有可能触发方向变化。
F_UpdateTempTrendState:
    JSR     F_TrendTempCurrentGtMax
    BCC     TrendTemp_CheckMin
    LDA     R_TempCH
    STA     R_TrendTempMaxH
    LDA     R_TempCL
    STA     R_TrendTempMaxL
    JSR     F_TrendTempSpanReached
    BCC     TrendTemp_StepCount
    LDA     R_TrendFlags
    ORA     #(D_TempTrendUp+D_TempTrendRefresh)
    STA     R_TrendFlags
    JMP     F_TrendResetTempWindowCurrent

TrendTemp_CheckMin:
    JSR     F_TrendTempCurrentLtMin
    BCC     TrendTemp_StepCount
    LDA     R_TempCH
    STA     R_TrendTempMinH
    LDA     R_TempCL
    STA     R_TrendTempMinL
    JSR     F_TrendTempSpanReached
    BCC     TrendTemp_StepCount
    LDA     R_TrendFlags
    ORA     #(D_TempTrendDown+D_TempTrendRefresh)
    STA     R_TrendFlags
    JMP     F_TrendResetTempWindowCurrent

TrendTemp_StepCount:
    LDA     R_TrendTempEqCnt
    CMP     #C_TrendEq60Min
    BCS     TrendTemp_Exit
    INC     R_TrendTempEqCnt
    LDA     R_TrendTempEqCnt
    CMP     #C_TrendEq60Min
    BNE     TrendTemp_Exit
    LDA     R_TrendFlags
    ORA     #D_TempTrendRefresh
    STA     R_TrendFlags
TrendTemp_Exit:
    RTS

;-------------------------------------------------------
; 函数: F_TrendTempCurrentGtMax
; 作用: 判断当前温度是否大于窗口内的温度最大值。
; 输出: C=1 表示当前值 > TempMax，C=0 表示否。
F_TrendTempCurrentGtMax:
    LDA     R_TempCH
    AND     #80H
    BEQ     TrendTempGtMax_CurrentPos

    ; 当前温度为负：只有最大值也为负时才需要比较，且绝对值越小温度越大。
    LDA     R_TrendTempMaxH
    AND     #80H
    BEQ     TrendTempGtMax_False
    LDA     R_TempCH
    CMP     R_TrendTempMaxH
    BCC     TrendTempGtMax_True
    BNE     TrendTempGtMax_False
    LDA     R_TempCL
    CMP     R_TrendTempMaxL
    BCC     TrendTempGtMax_True
    JMP     TrendTempGtMax_False

TrendTempGtMax_CurrentPos:
    ; 当前温度为正：只要原最大值还是负数，就一定刷新最大值。
    LDA     R_TrendTempMaxH
    AND     #80H
    BNE     TrendTempGtMax_True
    LDA     R_TempCH
    AND     #7FH
    CMP     R_TrendTempMaxH
    BCC     TrendTempGtMax_False
    BNE     TrendTempGtMax_True
    LDA     R_TempCL
    CMP     R_TrendTempMaxL
    BCC     TrendTempGtMax_False
    BEQ     TrendTempGtMax_False

TrendTempGtMax_True:
    SEC
    RTS

TrendTempGtMax_False:
    CLC
    RTS

;-------------------------------------------------------
; 函数: F_TrendTempCurrentLtMin
; 作用: 判断当前温度是否小于窗口内的温度最小值。
; 输出: C=1 表示当前值 < TempMin，C=0 表示否。
F_TrendTempCurrentLtMin:
    LDA     R_TempCH
    AND     #80H
    BEQ     TrendTempLtMin_CurrentPos

    ; 当前温度为负：只要原最小值还是正数，就一定刷新最小值。
    LDA     R_TrendTempMinH
    AND     #80H
    BEQ     TrendTempLtMin_True
    LDA     R_TempCH
    CMP     R_TrendTempMinH
    BCC     TrendTempLtMin_False
    BNE     TrendTempLtMin_True
    LDA     R_TempCL
    CMP     R_TrendTempMinL
    BCC     TrendTempLtMin_False
    BEQ     TrendTempLtMin_False
    JMP     TrendTempLtMin_True

TrendTempLtMin_CurrentPos:
    ; 当前温度为正：若最小值已为负，则当前值不可能更小。
    LDA     R_TrendTempMinH
    AND     #80H
    BNE     TrendTempLtMin_False
    LDA     R_TempCH
    AND     #7FH
    CMP     R_TrendTempMinH
    BCC     TrendTempLtMin_True
    BNE     TrendTempLtMin_False
    LDA     R_TempCL
    CMP     R_TrendTempMinL
    BCC     TrendTempLtMin_True

TrendTempLtMin_False:
    CLC
    RTS

TrendTempLtMin_True:
    SEC
    RTS

;-------------------------------------------------------
; 函数: F_TrendTempSpanReached
; 作用: 判断当前温度窗口的 max/min 跨度是否已经超过 1.0℃。
; 输出: C=1 表示跨度已触发趋势，C=0 表示仍在平缓窗口内。
; 说明: 正温、负温和跨零三种情况分别计算，避免简单二进制比较在负温下失真。
F_TrendTempSpanReached:
    LDA     R_TrendTempMaxH
    AND     #80H
    BEQ     TrendTempSpan_MaxPositive

    ; 两端都为负时，跨度 = 低温绝对值 - 高温绝对值，按 16 位 0.1℃ 值比较。
    SEC
    LDA     R_TrendTempMinL
    SBC     R_TrendTempMaxL
    TAX
    LDA     R_TrendTempMinH
    SBC     R_TrendTempMaxH
    BCC     TrendTempSpan_False
    BNE     TrendTempSpan_True
    TXA
    CMP     #C_TrendTempSpanTrig
    BCC     TrendTempSpan_False
    JMP     TrendTempSpan_True

TrendTempSpan_MaxPositive:
    LDA     R_TrendTempMinH
    AND     #80H
    BNE     TrendTempSpan_CrossZero

    ; 两端都为正时，跨度 = 高温 - 低温，按 16 位 0.1℃ 值比较。
    SEC
    LDA     R_TrendTempMaxL
    SBC     R_TrendTempMinL
    TAX
    LDA     R_TrendTempMaxH
    SBC     R_TrendTempMinH
    BCC     TrendTempSpan_False
    BNE     TrendTempSpan_True
    TXA
    CMP     #C_TrendTempSpanTrig
    BCC     TrendTempSpan_False
    JMP     TrendTempSpan_True

TrendTempSpan_CrossZero:
    ; 跨零时，跨度 = 正温绝对值 + 负温绝对值，按 16 位 0.1℃ 值比较。
    CLC
    LDA     R_TrendTempMaxL
    ADC     R_TrendTempMinL
    TAX
    LDA     R_TrendTempMinH
    AND     #7FH
    ADC     R_TrendTempMaxH
    BNE     TrendTempSpan_True
    TXA
    CMP     #C_TrendTempSpanTrig
    BCC     TrendTempSpan_False

TrendTempSpan_True:
    SEC
    RTS

TrendTempSpan_False:
    CLC
    RTS

;-------------------------------------------------------
; 函数: F_UpdateHumTrendState
; 作用: 按湿度窗口 max/min 的扩张方向判定 Up/Down；若未触发则累计湿度计数。
F_UpdateHumTrendState:
    LDA     R_HUM
    CMP     R_TrendHumMax
    BCC     TrendHum_CheckMin
    BEQ     TrendHum_CheckMin
    STA     R_TrendHumMax
    JSR     F_TrendHumSpanReached
    BCC     TrendHum_StepCount
    LDA     R_TrendFlags
    ORA     #(D_HumTrendUp+D_HumTrendRefresh)
    STA     R_TrendFlags
    JMP     F_TrendResetHumWindowCurrent

TrendHum_CheckMin:
    LDA     R_HUM
    CMP     R_TrendHumMin
    BCS     TrendHum_StepCount
    STA     R_TrendHumMin
    JSR     F_TrendHumSpanReached
    BCC     TrendHum_StepCount
    LDA     R_TrendFlags
    ORA     #(D_HumTrendDown+D_HumTrendRefresh)
    STA     R_TrendFlags
    JMP     F_TrendResetHumWindowCurrent

TrendHum_StepCount:
    LDA     R_TrendHumEqCnt
    CMP     #C_TrendEq60Min
    BCS     TrendHum_Exit
    INC     R_TrendHumEqCnt
    LDA     R_TrendHumEqCnt
    CMP     #C_TrendEq60Min
    BNE     TrendHum_Exit
    LDA     R_TrendFlags
    ORA     #D_HumTrendRefresh
    STA     R_TrendFlags
TrendHum_Exit:
    RTS

;-------------------------------------------------------
; 函数: F_TrendHumSpanReached
; 作用: 判断当前湿度窗口的 max/min 跨度是否已经超过 5%RH。
; 输出: C=1 表示已触发趋势，C=0 表示仍处于平缓窗口。
F_TrendHumSpanReached:
    LDA     R_TrendHumMax
    SEC
    SBC     R_TrendHumMin
    CMP     #C_TrendHumSpanTrig
    BCC     TrendHumSpan_False
    SEC
    RTS

TrendHumSpan_False:
    CLC
    RTS

; 每到整分 00 秒，把当前样本并入 Today / 48Hr / All-time，
; 若跨到 00:00:00，则先把独立 48Hr 今天桶滚到 Previous Day。
; 函数: F_HistoryOnSample
; 作用: history 采样主入口，负责首采样初始化、日切换和日内增量更新。
; 输入: RTC 当前时间、当前温湿度显示值、history 初始化标志。
; 输出: Today / 48HrToday / Previous Day / All-time 四套记录中的对应字段。
; 说明: 这套逻辑把“48 小时视图”拆成 48HrToday + Previous Day 两套源数据，显示时再聚合。
F_HistoryOnSample:
    LDA		R_HistoryFlags
    AND		#D_HistoryInit
    BNE		HistorySample_Update
    LDA		#00H
    STA		R_PrevRecFlags
    JSR		F_HistorySeedTodayFromCurrent
    JSR		F_HistorySeed48TodayFromCurrent
    JSR		F_HistorySeedAllFromCurrent
    LDA		#D_HistoryInit
    STA		R_HistoryFlags

HistorySample_InitSkip:
    RTS

HistorySample_Update:
    LDA		RTC+0
    BNE		HistorySample_UpdateToday
    LDA		RTC+1
    BNE		HistorySample_UpdateToday
    LDA		RTC+2
    BNE		HistorySample_UpdateToday
    LDA		R_48TodayRecFlags
    AND		#D_HisValid
    BEQ		HistorySample_ResetToday
    JSR		F_HistoryCopy48TodayToPrev
HistorySample_ResetToday:
    JSR		F_HistorySeedTodayFromCurrent
    JSR		F_HistorySeed48TodayFromCurrent
    JMP		F_HistoryUpdateAllFromCurrent

HistorySample_UpdateToday:
    JSR		F_HistoryUpdateTodayFromCurrent
    JSR		F_HistoryUpdate48TodayFromCurrent
    JMP		F_HistoryUpdateAllFromCurrent

;-------------------------------------------------------
; 函数: F_LoadHistoryViewBuffers
; 作用: 根据当前页面状态，把指定 history 记录装入旧显示兼容缓冲。
; 输入: R_ProductPage、R_HistoryPage、history valid 标志。
; 输出: R_TempMax/R_TempMin/R_HumMax/R_HumMin 以及对应符号/华氏缓存。
; 说明: LCD 层仍复用旧 max/min 渲染链，所以这里要把新 history 结构整理回兼容缓冲。
F_LoadHistoryViewBuffers:
	LDA		#00H
	STA		R_HistoryViewFlags
    LDA		R_HistoryFlags
    AND		#D_HistoryInit
    BNE		HistoryLoadView_Select
    JMP		F_HistoryClearCompat

HistoryLoadView_Select:
    LDA		R_ProductPage
    CMP		#D_PageHistory
    BEQ		HistoryLoadView_PageHistory
    JMP		F_HistoryLoadTodayToCompat

HistoryLoadView_PageHistory:
    LDA		R_HistoryPage
    CMP		#D_His48Hr
    BEQ		HistoryLoadView_48Hr
    CMP		#D_HisAllTm
    BEQ		HistoryLoadView_All
    JMP		F_HistoryLoadTodayToCompat

HistoryLoadView_All:
    JMP		F_HistoryLoadAllToCompat

HistoryLoadView_48Hr:
    LDA		R_48TodayRecFlags
    AND		#D_HisValid
    BEQ		HistoryLoadView_48HrSeedFromPrev
    JSR		F_HistoryLoad48TodayToCompat
    LDA		R_PrevRecFlags
    AND		#D_HisValid
    BEQ		HistoryLoadView_48HrDone
    JMP		F_HistoryMergePrevIntoCompat
HistoryLoadView_48HrSeedFromPrev:
    LDA		R_PrevRecFlags
    AND		#D_HisValid
    BEQ		HistoryLoadView_48HrClear
    JMP		F_HistoryLoadPrevToCompat
HistoryLoadView_48HrClear:
    JMP		F_HistoryClearCompat
HistoryLoadView_48HrDone:
    RTS

;-------------------------------------------------------
; 函数: F_ClearCurrentHistory
; 作用: 按当前所在页面清除对应 history 记录，并启动 3 秒清除反馈显示。
; 输入: R_ProductPage、R_HistoryPage。
; 输出: 对应记录被清零，R_HistoryClearTm 被装载，兼容缓冲重载。
; 说明: Today、48Hr、All-time 的清理范围不同；48Hr 会同时清 48HrToday 和 Previous Day 两个源桶。
F_ClearCurrentHistory:
    LDA		R_ProductPage
    CMP		#D_PageHistory
    BEQ		HistoryClear_SelectCurrentPage
    JSR		F_HistoryClearToday
	JSR		F_HistoryReseedTodayFromCurrent
    JMP		HistoryClear_StartFeedback

HistoryClear_SelectCurrentPage:
    LDA		R_HistoryPage
    CMP		#D_His48Hr
    BEQ		HistoryClear_48Hr
    CMP		#D_HisAllTm
    BEQ		HistoryClear_All
    JSR		F_HistoryClearToday
	JSR		F_HistoryReseedTodayFromCurrent
    JMP		HistoryClear_StartFeedback

; 48hr 当前仍由 Today + Previous Day 聚合，清除时同步清掉两套来源记录。
HistoryClear_48Hr:
    JSR		F_HistoryClear48Today
    JSR		F_HistoryClearPrev
	JSR		F_HistoryReseed48TodayFromCurrent
    JMP		HistoryClear_StartFeedback

HistoryClear_All:
    JSR		F_HistoryClearAll
	JSR		F_HistoryReseedAllFromCurrent

HistoryClear_StartFeedback:
    LDA		#C_HistoryClear3Sec
    STA		R_HistoryClearTm
    JMP		F_LoadHistoryViewBuffers

; 函数: F_HistoryReseedTodayFromCurrent
; 作用: 清除反馈期间，后台用当前样本重建 Today 记录。
; 说明: 前台仍会先显示 3 秒横杠，倒计时结束后即可直接恢复为当前刷新数据。
F_HistoryReseedTodayFromCurrent:
	%bits	R_HistoryFlags,D_HistoryInit
	JSR		F_HistorySeedTodayFromCurrent
	RTS

; 函数: F_HistoryReseed48TodayFromCurrent
; 作用: 清除 48hr 后，用当前样本重建独立 48HrToday 桶。
F_HistoryReseed48TodayFromCurrent:
	%bits	R_HistoryFlags,D_HistoryInit
	JSR		F_HistorySeed48TodayFromCurrent
	RTS

; 函数: F_HistoryReseedAllFromCurrent
; 作用: 清除 all-time 后，用当前样本重建 all-time 记录。
F_HistoryReseedAllFromCurrent:
	%bits	R_HistoryFlags,D_HistoryInit
	JSR		F_HistorySeedAllFromCurrent
	RTS

; 函数: F_HistoryClearToday
; 作用: 选择 Today 记录并跳到通用清空逻辑。
F_HistoryClearToday:
    LDX		#C_HisRecToday
    JMP		F_HistoryClearRecord

; 函数: F_HistoryClear48Today
; 作用: 选择 48HrToday 记录并跳到通用清空逻辑。
F_HistoryClear48Today:
    LDX		#C_HisRec48Today
    JMP		F_HistoryClearRecord

; 函数: F_HistoryClearPrev
; 作用: 选择 Previous Day 记录并跳到通用清空逻辑。
F_HistoryClearPrev:
    LDX		#C_HisRecPrev
    JMP		F_HistoryClearRecord

; 函数: F_HistoryClearAll
; 作用: 选择 All-time 记录并跳到通用清空逻辑。
F_HistoryClearAll:
    LDX		#C_HisRecAll
    JMP		F_HistoryClearRecord

;-------------------------------------------------------
; 函数: F_HistoryClearRecord
; 作用: 按 X 指向的记录起始偏移，把整条 history record 清零。
; 输入: X = C_HisRecToday / C_HisRec48Today / C_HisRecPrev / C_HisRecAll。
; 输出: 该 record 的 flags、温度、华氏、湿度最大最小值全部清零。
; 说明: 这里正是为什么偏移量必须按 11 字节步长递增；否则清零会落到别的字段上。
F_HistoryClearRecord:
    LDA     #00H
    STA     R_TodayRecFlags,X        ; Flags
    STA     R_TodayRecTempMax,X      ; TempMax 低字节
    STA     R_TodayRecTempMax+1,X    ; TempMax 高字节
    STA     R_TodayRecTempMaxF,X     ; TempMaxF 低字节
    STA     R_TodayRecTempMaxF+1,X   ; TempMaxF 高字节
    STA     R_TodayRecTempMin,X      ; TempMin 低字节
    STA     R_TodayRecTempMin+1,X    ; TempMin 高字节
    STA     R_TodayRecTempMinF,X     ; TempMinF 低字节
    STA     R_TodayRecTempMinF+1,X   ; TempMinF 高字节
    STA     R_TodayRecHumMax,X       ; HumMax
    STA     R_TodayRecHumMin,X       ; HumMin
    RTS
;    LDA		#00H
;    STA		R_TodayRecFlags,X
;    STA		R_TodayRecTempMax,X
;    
;    STA		R_TodayRecTempMaxF,X
;
;    STA		R_TodayRecTempMin,X
;
;    STA		R_TodayRecTempMinF,X
;    
;    STA		R_TodayRecHumMax,X
;    STA		R_TodayRecHumMin,X
;    RTS

; Previous Day 只在跨日时整体接管独立 48Hr 今天桶的上一日结果，
; 这里保留完整的 C/F/湿度记录，避免显示时再做额外换算。
; 函数: F_HistoryCopy48TodayToPrev
; 作用: 跨日时把“昨天结束时的 48HrToday 桶”整体复制到 Previous Day。
F_HistoryCopy48TodayToPrev:
    LDX		#C_HisRec48Today
    LDY		#C_HisRecPrev
    JMP		F_HistoryCopyRecord

;-------------------------------------------------------
; 函数: F_HistoryCopyRecord
; 作用: 把 X 指向的整条 history record 拷贝到 Y 指向的另一条 record。
; 输入: X = 源记录偏移，Y = 目标记录偏移。
; 输出: 目标记录被完整覆盖。
; 说明: 复制时按字段顺序逐项搬运，而不是按裸内存块复制，方便后续结构扩展时逐项维护。
F_HistoryCopyRecord:
    ; Flags
    LDA     R_TodayRecFlags,X
    STA     R_TodayRecFlags,Y
    ; TempMax 2 字节
    LDA     R_TodayRecTempMax,X
    STA     R_TodayRecTempMax,Y
    LDA     R_TodayRecTempMax+1,X
    STA     R_TodayRecTempMax+1,Y
    ; TempMaxF 2 字节
    LDA     R_TodayRecTempMaxF,X
    STA     R_TodayRecTempMaxF,Y
    LDA     R_TodayRecTempMaxF+1,X
    STA     R_TodayRecTempMaxF+1,Y
    ; TempMin 2 字节
    LDA     R_TodayRecTempMin,X
    STA     R_TodayRecTempMin,Y
    LDA     R_TodayRecTempMin+1,X
    STA     R_TodayRecTempMin+1,Y
    ; TempMinF 2 字节
    LDA     R_TodayRecTempMinF,X
    STA     R_TodayRecTempMinF,Y
    LDA     R_TodayRecTempMinF+1,X
    STA     R_TodayRecTempMinF+1,Y
    ; HumMax
    LDA     R_TodayRecHumMax,X
    STA     R_TodayRecHumMax,Y
    ; HumMin
    LDA     R_TodayRecHumMin,X
    STA     R_TodayRecHumMin,Y
    RTS

; 函数: F_HistorySeedTodayFromCurrent
; 作用: 用当前采样值初始化 Today 记录。
F_HistorySeedTodayFromCurrent:
    LDX		#C_HisRecToday
    JMP		F_HistorySeedRecordFromCurrent

; 函数: F_HistorySeed48TodayFromCurrent
; 作用: 用当前采样值初始化 48HrToday 记录。
F_HistorySeed48TodayFromCurrent:
    LDX		#C_HisRec48Today
    JMP		F_HistorySeedRecordFromCurrent

; 函数: F_HistorySeedAllFromCurrent
; 作用: 用当前采样值初始化 All-time 记录。
F_HistorySeedAllFromCurrent:
    LDX		#C_HisRecAll
    JMP		F_HistorySeedRecordFromCurrent

;-------------------------------------------------------
; 函数: F_HistorySeedRecordFromCurrent
; 作用: 用当前样本覆盖指定 record；湿度始终写入，温度只在量程内时写入。
; 输入: X = 目标记录偏移，当前温湿度显示值与温度符号位。
; 输出: 指定 record 至少带当前湿度；若温度在量程内，temp max/min 也被初始化。
; 说明: 第一次采样时最大值和最小值都等于当前值，所以 max/min 两套字段都会写同一份数据。
F_HistorySeedRecordFromCurrent:
    LDA     #D_HisValid
    STA     R_TodayRecFlags,X
    LDA     R_DispHum
    STA     R_TodayRecHumMax,X
    STA     R_TodayRecHumMin,X
	JSR		F_IsCurrentTempInRange
	BCC		HistorySeedRecord_Exit
    JMP     HistorySeedRecord_SeedTempFromCurrent

HistorySeedRecord_Exit:
    RTS

HistorySeedRecord_SeedTempFromCurrent:
    LDA     R_TodayRecFlags,X
    AND     #.not.D_HisMaxNeg
    AND     #.not.D_HisMinNeg
    ORA     #D_HisTempValid
    STA     R_TodayRecFlags,X
    LDA     R_SpecFlag
    AND     #D_Neg
    BEQ     HistorySeedRecord_Positive
    LDA     R_TodayRecFlags,X
    ORA     #(D_HisMaxNeg+D_HisMinNeg)
    STA     R_TodayRecFlags,X
HistorySeedRecord_Positive:
    ; 温度 BCD 双字节
    LDA     R_DispTemper+0
    STA     R_TodayRecTempMax,X
    STA     R_TodayRecTempMin,X
    LDA     R_DispTemper+1
    STA     R_TodayRecTempMax+1,X
    STA     R_TodayRecTempMin+1,X
    ; 华氏度 BCD 双字节
    LDA     R_DispTemper_F+0
    STA     R_TodayRecTempMaxF,X
    STA     R_TodayRecTempMinF,X
    LDA     R_DispTemper_F+1
    STA     R_TodayRecTempMaxF+1,X
    STA     R_TodayRecTempMinF+1,X
    RTS

; 函数: F_HistoryUpdateTodayFromCurrent
; 作用: 用当前样本更新 Today 记录。
F_HistoryUpdateTodayFromCurrent:
    LDX		#C_HisRecToday
    JMP		F_HistoryUpdateRecordFromCurrent

; 函数: F_HistoryUpdate48TodayFromCurrent
; 作用: 用当前样本更新 48HrToday 记录。
F_HistoryUpdate48TodayFromCurrent:
    LDX		#C_HisRec48Today
    JMP		F_HistoryUpdateRecordFromCurrent

; 函数: F_HistoryUpdateAllFromCurrent
; 作用: 用当前样本更新 All-time 记录。
F_HistoryUpdateAllFromCurrent:
    LDX		#C_HisRecAll
    JMP		F_HistoryUpdateRecordFromCurrent

;-------------------------------------------------------
; 函数: F_HistoryUpdateRecordFromCurrent
; 作用: 把当前样本并入指定 record，按规则更新温度/湿度最大最小值。
; 输入: X = 目标记录偏移，当前温湿度显示值、当前温度正负标志。
; 输出: 目标 record 内的 max/min 字段和正负号标志可能被刷新。
; 说明: 温度比较仍需区分正温和负温；湿度则直接按无符号大小更新。
F_HistoryUpdateRecordFromCurrent:
    LDA		R_TodayRecFlags,X
    AND		#D_HisValid
    BNE		HistoryUpdateRecord_SeedContinue
    JMP		F_HistorySeedRecordFromCurrent
HistoryUpdateRecord_SeedContinue:
	JSR		F_IsCurrentTempInRange
    BCS		HistoryUpdateRecord_CheckTempRange
    JMP		HistoryUpdateRecord_CheckHum
HistoryUpdateRecord_CheckTempRange:
    LDA		R_TodayRecFlags,X
    AND		#D_HisTempValid
    BEQ		HistoryUpdateRecord_SeedTempOnly
    JMP		HistoryUpdateRecord_CheckTemp
HistoryUpdateRecord_SeedTempOnly:
    JSR		HistorySeedRecord_SeedTempFromCurrent
    JMP		HistoryUpdateRecord_CheckHum

HistoryUpdateRecord_CheckTemp:

    LDA		R_SpecFlag
    AND		#D_Neg
    BEQ		HistoryUpdateRecord_MaxPosPath
    JMP		HistoryUpdateRecord_MaxNeg
HistoryUpdateRecord_MaxPosPath:
    LDA		R_TodayRecFlags,X
    AND		#D_HisMaxNeg
    BNE		HistoryUpdateRecord_UpdateMaxPosJump
    LDA		R_DispTemper+0
    CMP		R_TodayRecTempMax,X
    BCC		HistoryUpdateRecord_CheckMin
    BNE		HistoryUpdateRecord_UpdateMaxPosJump
    LDA		R_DispTemper+1
    CMP		R_TodayRecTempMax+1,X
    BCC		HistoryUpdateRecord_CheckMin
    BEQ		HistoryUpdateRecord_CheckMin
HistoryUpdateRecord_UpdateMaxPosJump:
    JMP		HistoryUpdateRecord_UpdateMaxPos
HistoryUpdateRecord_UpdateMaxPos:
;     LDA		R_DispTemper+0
; ;    STA		R_TodayRecTempMax,X
;     STA		R_TodayRecTempMax+0
;     LDA		R_DispTemper+1
;     STA		R_TodayRecTempMax+1
    
;     LDA		R_DispTemper_F+0
; ;    STA		R_TodayRecTempMaxF0,X
;     STA		R_TodayRecTempMaxF+0
;     LDA		R_DispTemper_F+1
;     STA		R_TodayRecTempMaxF+1
; ;    STA		R_TodayRecTempMaxF1,X
    LDA     R_DispTemper+0
    STA     R_TodayRecTempMax,X     ; 用 X 索引
    LDA     R_DispTemper+1
    STA     R_TodayRecTempMax+1,X   ; 高字节
    LDA     R_DispTemper_F+0
    STA     R_TodayRecTempMaxF,X
    LDA     R_DispTemper_F+1
    STA     R_TodayRecTempMaxF+1,X
        
    LDA		R_TodayRecFlags,X
    AND		#.not.D_HisMaxNeg
    ORA		#D_HisValid
    STA		R_TodayRecFlags,X
    JMP		HistoryUpdateRecord_CheckMin

HistoryUpdateRecord_MaxNeg:
    LDA		R_TodayRecFlags,X
    AND		#D_HisMaxNeg
    BEQ		HistoryUpdateRecord_CheckMin
    LDA		R_DispTemper+0
    CMP		R_TodayRecTempMax,X
    BCC		HistoryUpdateRecord_UpdateMaxNeg
    BNE		HistoryUpdateRecord_CheckMin
    LDA		R_DispTemper+1
    CMP		R_TodayRecTempMax+1,X
    BCC		HistoryUpdateRecord_UpdateMaxNeg
    JMP		HistoryUpdateRecord_CheckMin
HistoryUpdateRecord_UpdateMaxNeg:
    LDA		R_DispTemper+0
    STA		R_TodayRecTempMax,X
    LDA		R_DispTemper+1
    STA		R_TodayRecTempMax+1,X
    LDA		R_DispTemper_F+0
    STA		R_TodayRecTempMaxF,X
    LDA		R_DispTemper_F+1
    STA		R_TodayRecTempMaxF+1,X
    LDA		R_TodayRecFlags,X
    ORA		#(D_HisValid+D_HisMaxNeg)
    STA		R_TodayRecFlags,X

HistoryUpdateRecord_CheckMin:
    LDA		R_SpecFlag
    AND		#D_Neg
    BEQ		HistoryUpdateRecord_MinPosPath
    JMP		HistoryUpdateRecord_MinNeg
HistoryUpdateRecord_MinPosPath:
    LDA		R_TodayRecFlags,X
    AND		#D_HisMinNeg
    BNE		HistoryUpdateRecord_CheckHum
    LDA		R_DispTemper+0
    CMP		R_TodayRecTempMin,X
    BCC		HistoryUpdateRecord_UpdateMinPos
    BNE		HistoryUpdateRecord_CheckHum
    LDA		R_DispTemper+1
    CMP		R_TodayRecTempMin+1,X
    BCC		HistoryUpdateRecord_UpdateMinPos
    JMP		HistoryUpdateRecord_CheckHum
HistoryUpdateRecord_UpdateMinPos:
    LDA		R_DispTemper+0
	STA		R_TodayRecTempMin,X
    LDA		R_DispTemper+1
	STA		R_TodayRecTempMin+1,X
    
    LDA		R_DispTemper_F+0
    STA		R_TodayRecTempMinF,X
    LDA		R_DispTemper_F+1
    STA		R_TodayRecTempMinF+1,X
    LDA		R_TodayRecFlags,X
    AND		#.not.D_HisMinNeg
    ORA		#D_HisValid
    STA		R_TodayRecFlags,X
    JMP		HistoryUpdateRecord_CheckHum

HistoryUpdateRecord_MinNeg:
    LDA		R_TodayRecFlags,X
    AND		#D_HisMinNeg
    BEQ		HistoryUpdateRecord_UpdateMinNeg
    LDA		R_DispTemper+0
    CMP		R_TodayRecTempMin,X
    BCC		HistoryUpdateRecord_CheckHum
    BNE		HistoryUpdateRecord_UpdateMinNeg
    LDA		R_DispTemper+1
    CMP		R_TodayRecTempMin+1,X
    BCC		HistoryUpdateRecord_CheckHum
    BEQ		HistoryUpdateRecord_CheckHum
HistoryUpdateRecord_UpdateMinNeg:
    LDA		R_DispTemper+0
    STA		R_TodayRecTempMin,X
    LDA		R_DispTemper+1
    STA		R_TodayRecTempMin+1,X
    LDA		R_DispTemper_F+0
    STA		R_TodayRecTempMinF,X
    LDA		R_DispTemper_F+1
    STA		R_TodayRecTempMinF+1,X
    LDA		R_TodayRecFlags,X
    ORA		#(D_HisValid+D_HisMinNeg)
    STA		R_TodayRecFlags,X

HistoryUpdateRecord_CheckHum:
    LDA		R_DispHum
    CMP		R_TodayRecHumMax,X
    BCC		HistoryUpdateRecord_CheckHumMin
    LDA		R_DispHum
    STA		R_TodayRecHumMax,X
HistoryUpdateRecord_CheckHumMin:
    LDA		R_DispHum
    CMP		R_TodayRecHumMin,X
    BCS		HistoryUpdateRecord_Exit
    LDA		R_DispHum
    STA		R_TodayRecHumMin,X
HistoryUpdateRecord_Exit:
    RTS

; 把 Today 记录装到兼容显示缓冲，供 LCD 直接复用旧的 max/min 渲染逻辑。
; 函数: F_HistoryLoadTodayToCompat
; 作用: 装载 Today record 到兼容显示缓冲。
F_HistoryLoadTodayToCompat:
    LDX		#C_HisRecToday
    JMP		F_HistoryLoadRecordToCompat

; 函数: F_HistoryLoad48TodayToCompat
; 作用: 装载 48HrToday record 到兼容显示缓冲。
F_HistoryLoad48TodayToCompat:
	LDX		#C_HisRec48Today
	JMP		F_HistoryLoadRecordToCompat

; 函数: F_HistoryLoadAllToCompat
; 作用: 装载 All-time record 到兼容显示缓冲。
F_HistoryLoadAllToCompat:
	LDX		#C_HisRecAll
	JMP		F_HistoryLoadRecordToCompat

; 函数: F_HistoryLoadPrevToCompat
; 作用: 装载 Previous Day record 到兼容显示缓冲。
F_HistoryLoadPrevToCompat:
	LDX		#C_HisRecPrev
	JMP		F_HistoryLoadRecordToCompat

;-------------------------------------------------------
; 函数: F_HistoryLoadRecordToCompat
; 作用: 把指定 record 的历史值回填到旧显示兼容缓冲，供 LCD 直接显示。
; 输入: X = 目标记录偏移。
; 输出: R_TempMax、R_TempMin、R_MAXDispTemper_F、R_MINDispTemper_F、R_HumMax、R_HumMin 等兼容变量。
; 说明: 你断点看到的 LDA R_TodayRecHumMin,X 就在这里；X 必须是正确的 record 起始偏移，否则会读错字段。
F_HistoryLoadRecordToCompat:
	LDA		R_TodayRecFlags,X
	AND		#D_HisValid
	BNE		HistoryLoadRecord_Copy
	JMP		F_HistoryClearCompat

HistoryLoadRecord_Copy:
    LDA     R_TodayRecHumMax,X
    STA     R_HumMax
    LDA     R_TodayRecHumMin,X
    STA     R_HumMin
    LDA     #D_HistoryViewValid
    STA     R_HistoryViewFlags

    LDA     R_TodayRecFlags,X
    AND     #D_HisTempValid
    BNE     HistoryLoadRecord_CopyTemp
    JSR     HistoryClearCompatTempOnly
    RTS

HistoryLoadRecord_CopyTemp:
    LDA     R_TodayRecTempMax,X
    STA     R_TempMax+0
    LDA     R_TodayRecTempMax+1,X
    STA     R_TempMax+1
    LDA     R_TodayRecTempMaxF,X
    STA     R_MAXDispTemper_F+0
    LDA     R_TodayRecTempMaxF+1,X
    STA     R_MAXDispTemper_F+1

    LDA     R_TodayRecFlags,X
    AND     #D_HisMaxNeg
    BEQ     HistoryLoadRecord_MaxPos
    LDA     #D_Neg
    BNE     HistoryLoadRecord_MaxStore
HistoryLoadRecord_MaxPos:
    LDA     #00H
HistoryLoadRecord_MaxStore:
    STA     R_TempMax_Sign

    ; 最小值
    LDA     R_TodayRecTempMin,X
    STA     R_TempMin+0
    LDA     R_TodayRecTempMin+1,X
    STA     R_TempMin+1
    LDA     R_TodayRecTempMinF,X
    STA     R_MINDispTemper_F+0
    LDA     R_TodayRecTempMinF+1,X
    STA     R_MINDispTemper_F+1

    LDA     R_TodayRecFlags,X
    AND     #D_HisMinNeg
    BEQ     HistoryLoadRecord_MinPos
    LDA     #D_Neg
    BNE     HistoryLoadRecord_MinStore
HistoryLoadRecord_MinPos:
    LDA     #00H
HistoryLoadRecord_MinStore:
    STA     R_TempMin_Sign
    LDA     R_HistoryViewFlags
    ORA     #D_HistoryViewTempValid
    STA     R_HistoryViewFlags
    RTS

HistoryClearCompatTempOnly:
    LDA		#00H
    STA		R_TempMax+0
    STA		R_TempMax+1
    STA		R_TempMin+0
    STA		R_TempMin+1
    STA		R_MAXDispTemper_F+0
    STA		R_MAXDispTemper_F+1
    STA		R_MINDispTemper_F+0
    STA		R_MINDispTemper_F+1
    STA		R_TempMax_Sign
    STA		R_TempMin_Sign
    RTS

;-------------------------------------------------------
; 函数: F_HistoryClearCompat
; 作用: 清空旧显示兼容缓冲，表示当前没有可显示的历史值。
; 输出: 温度/湿度 max/min 兼容变量和有效标志全部清零。
F_HistoryClearCompat:
    JSR		HistoryClearCompatTempOnly
    LDA		#00H
    STA		R_HumMax
    STA		R_HumMin
    STA		R_HistoryViewFlags
    RTS

; 48hr 页面把 Previous Day 合并进独立 48Hr 今天桶，
; 形成 yesterday + today 的视图。
; 函数: F_HistoryMergePrevIntoCompat
; 作用: 在 48Hr 页面上，把 Previous Day record 合并到当前兼容缓冲，形成两天聚合结果。
; 输入: 兼容缓冲中已加载的 48HrToday record，以及 Previous Day record。
; 输出: 兼容缓冲中的温度/湿度 max/min 被合并成 yesterday + today 的结果。
; 说明: 这里的温度比较同样区分正负号，湿度仍按无符号大小直接合并。
F_HistoryMergePrevIntoCompat:
    LDA		R_PrevRecFlags
    AND		#D_HisTempValid
    BNE		HistoryMergePrev_HasTemp
    JMP		HistoryMergePrev_CheckHum
HistoryMergePrev_HasTemp:
    LDA		R_HistoryViewFlags
    AND		#D_HistoryViewTempValid
    BNE		HistoryMergePrev_CheckMax
    JSR		HistoryMergePrev_LoadTempOnly
    JMP		HistoryMergePrev_CheckHum

HistoryMergePrev_CheckMax:
    LDA		R_PrevRecFlags
    AND		#D_HisMaxNeg
    BNE		HistoryMergePrev_MaxNeg
    LDA		R_TempMax_Sign
    AND		#D_Neg
    BNE		HistoryMergePrev_UpdateMaxPos
    LDA		R_PrevRecTempMax+0
    CMP		R_TempMax+0
    BCC		HistoryMergePrev_CheckMin
    BNE		HistoryMergePrev_UpdateMaxPos
    LDA		R_PrevRecTempMax+1
    CMP		R_TempMax+1
    BCC		HistoryMergePrev_CheckMin
    BEQ		HistoryMergePrev_CheckMin
HistoryMergePrev_UpdateMaxPos:
;    LDA		R_PrevRecTempMax
;    STA		R_TempMax
;    LDA		R_PrevRecTempMaxF0
;    STA		R_MAXDispTemper_F+0
;    LDA		R_PrevRecTempMaxF1
;    STA		R_MAXDispTemper_F+1
    LDA		R_PrevRecTempMax+0
    STA		R_TempMax+0
    LDA		R_PrevRecTempMax+1
    STA		R_TempMax+1    
    LDA		R_PrevRecTempMaxF+0
    STA		R_MAXDispTemper_F+0
    LDA		R_PrevRecTempMaxF+1
    STA		R_MAXDispTemper_F+1    
    LDA		#00H
    STA		R_TempMax_Sign
    JMP		HistoryMergePrev_CheckMin

HistoryMergePrev_MaxNeg:
    LDA		R_TempMax_Sign
    AND		#D_Neg
    BEQ		HistoryMergePrev_CheckMin
    LDA		R_PrevRecTempMax+0
    CMP		R_TempMax+0
    BCC		HistoryMergePrev_UpdateMaxNeg
    BNE		HistoryMergePrev_CheckMin
    LDA		R_PrevRecTempMax+1
    CMP		R_TempMax+1
    BCC		HistoryMergePrev_UpdateMaxNeg
    JMP		HistoryMergePrev_CheckMin
HistoryMergePrev_UpdateMaxNeg:
;    LDA		R_PrevRecTempMax
;    STA		R_TempMax
;    LDA		R_PrevRecTempMaxF0
;    STA		R_MAXDispTemper_F+0
;    LDA		R_PrevRecTempMaxF1
;    STA		R_MAXDispTemper_F+1
    LDA		R_PrevRecTempMax+0
    STA		R_TempMax+0
    LDA		R_PrevRecTempMax+1
    STA		R_TempMax+1   
    LDA		R_PrevRecTempMaxF+0
    STA		R_MAXDispTemper_F+0
    LDA		R_PrevRecTempMaxF+1
    STA		R_MAXDispTemper_F+1
    
    LDA		#D_Neg
    STA		R_TempMax_Sign

HistoryMergePrev_CheckMin:
    LDA		R_PrevRecFlags
    AND		#D_HisMinNeg
    BNE		HistoryMergePrev_MinNeg
    LDA		R_TempMin_Sign
    AND		#D_Neg
    BEQ		HistoryMergePrev_MinPosCompare
    JMP		HistoryMergePrev_CheckHum
HistoryMergePrev_MinPosCompare:
    LDA		R_PrevRecTempMin+0
    CMP		R_TempMin+0
    BCC		HistoryMergePrev_UpdateMinPos
    BEQ		HistoryMergePrev_MinPosCompareHigh
    JMP		HistoryMergePrev_CheckHum
HistoryMergePrev_MinPosCompareHigh:
    LDA		R_PrevRecTempMin+1
    CMP		R_TempMin+1
    BCC		HistoryMergePrev_UpdateMinPos
    JMP		HistoryMergePrev_CheckHum
HistoryMergePrev_UpdateMinPos:
;    LDA		R_PrevRecTempMin
;    STA		R_TempMin
;    LDA		R_PrevRecTempMinF0
;    STA		R_MINDispTemper_F+0
;    LDA		R_PrevRecTempMinF1
;    STA		R_MINDispTemper_F+1
    LDA		R_PrevRecTempMin+0
    STA		R_TempMin+0
    LDA		R_PrevRecTempMin+1
    STA		R_TempMin+1   
    LDA		R_PrevRecTempMinF+0
    STA		R_MINDispTemper_F+0
    LDA		R_PrevRecTempMinF+1
    STA		R_MINDispTemper_F+1    
    LDA		#00H
    STA		R_TempMin_Sign
    JMP		HistoryMergePrev_CheckHum

HistoryMergePrev_MinNeg:
    LDA		R_TempMin_Sign
    AND		#D_Neg
    BNE		HistoryMergePrev_MinNegCompare
    JMP		HistoryMergePrev_UpdateMinNeg
HistoryMergePrev_MinNegCompare:
    LDA		R_PrevRecTempMin+0
    CMP		R_TempMin+0
    BCC		HistoryMergePrev_CheckHumJump
    BNE		HistoryMergePrev_UpdateMinNeg
    LDA		R_PrevRecTempMin+1
    CMP		R_TempMin+1
    BCC		HistoryMergePrev_CheckHumJump
    BEQ		HistoryMergePrev_CheckHumJump
HistoryMergePrev_CheckHumJump:
    JMP		HistoryMergePrev_CheckHum
HistoryMergePrev_UpdateMinNeg:
;    LDA		R_PrevRecTempMin
;    STA		R_TempMin
;    LDA		R_PrevRecTempMinF0
;    STA		R_MINDispTemper_F+0
;    LDA		R_PrevRecTempMinF1
;    STA		R_MINDispTemper_F+1
    LDA		R_PrevRecTempMin+0
    STA		R_TempMin+0
    LDA		R_PrevRecTempMin+1
    STA		R_TempMin+1    
    LDA		R_PrevRecTempMinF+0
    STA		R_MINDispTemper_F+0
    LDA		R_PrevRecTempMinF+1
    STA		R_MINDispTemper_F+1	
    LDA		#D_Neg
    STA		R_TempMin_Sign

HistoryMergePrev_LoadTempOnly:
    LDA		R_PrevRecTempMax+0
    STA		R_TempMax+0
    LDA		R_PrevRecTempMax+1
    STA		R_TempMax+1
    LDA		R_PrevRecTempMaxF+0
    STA		R_MAXDispTemper_F+0
    LDA		R_PrevRecTempMaxF+1
    STA		R_MAXDispTemper_F+1
    LDA		R_PrevRecFlags
    AND		#D_HisMaxNeg
    BEQ		HistoryMergePrev_LoadTempOnlyMaxPos
    LDA		#D_Neg
    BNE		HistoryMergePrev_LoadTempOnlyMaxStore
HistoryMergePrev_LoadTempOnlyMaxPos:
    LDA		#00H
HistoryMergePrev_LoadTempOnlyMaxStore:
    STA		R_TempMax_Sign

    LDA		R_PrevRecTempMin+0
    STA		R_TempMin+0
    LDA		R_PrevRecTempMin+1
    STA		R_TempMin+1
    LDA		R_PrevRecTempMinF+0
    STA		R_MINDispTemper_F+0
    LDA		R_PrevRecTempMinF+1
    STA		R_MINDispTemper_F+1
    LDA		R_PrevRecFlags
    AND		#D_HisMinNeg
    BEQ		HistoryMergePrev_LoadTempOnlyMinPos
    LDA		#D_Neg
    BNE		HistoryMergePrev_LoadTempOnlyMinStore
HistoryMergePrev_LoadTempOnlyMinPos:
    LDA		#00H
HistoryMergePrev_LoadTempOnlyMinStore:
    STA		R_TempMin_Sign
    LDA		R_HistoryViewFlags
    ORA		#D_HistoryViewTempValid
    STA		R_HistoryViewFlags
    RTS

HistoryMergePrev_CheckHum:
    LDA		R_PrevRecHumMax
    CMP		R_HumMax
    BCC		HistoryMergePrev_CheckHumMin
    LDA		R_PrevRecHumMax
    STA		R_HumMax
HistoryMergePrev_CheckHumMin:
    LDA		R_PrevRecHumMin
    CMP		R_HumMin
    BCS		HistoryMergePrev_Exit
    LDA		R_PrevRecHumMin
    STA		R_HumMin
HistoryMergePrev_Exit:
    RTS

.END	
	
	
	
	
	
	
