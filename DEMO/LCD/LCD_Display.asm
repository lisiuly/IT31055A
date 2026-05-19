;==========================================
.SYNTAX 6502
.LINKLIST
.SYMBOLS
;==========================================
; Include file area
;==========================================
.INCLUDE 	GPL813x.inc
.INCLUDE	sys\Macro.inc
.INCLUDE	key\Key.inc
.INCLUDE	rtc\RTC.inc
.INCLUDE	Alarm\Alarm.inc

;.INCLUDE	Project.inc
.INCLUDE	GXHTV4\GXHTV4.inc
;==========================================
; Public declare area
;==========================================
.PUBLIC			R_Mode
.PUBLIC			D_AlarmMode
.PUBLIC			D_DateMode
.PUBLIC			D_TimeMode
.PUBLIC			R_ProductPage
.PUBLIC			R_HistoryPage
.PUBLIC			R_MoldSetValue
.PUBLIC			R_TempBuf
;==========================================
; Public declare area
;==========================================
.PUBLIC			T_Icon
.PUBLIC			LcdMapTab
.PUBLIC			T_NumberTable
.PUBLIC			F_Display
.PUBLIC			F_DisplayProductUI
.PUBLIC			F_DisplayHLValue
;==========================================
; Variable RAM declare area
;==========================================

R_Mode	ds	1
D_TimeMode	equ	01h
D_AlarmMode	equ	02h
D_DateMode	equ	04h

R_ProductPage	ds	1
D_PageStandard	equ	01h
D_PageHistory	equ	02h
D_PageMoldSet	equ	04h

R_HistoryPage	ds	1
D_HisToday		equ	01h
D_His48Hr		equ	02h
D_HisAllTm		equ	04h

R_MoldSetValue	ds	1
D_MoldDefault	equ	65H

R_TempBuf		ds	7

;=======================================================================
.CODE
.INCLUDE	LCD\LCD_Display.tab

;===================================================================
; Shared record initialization helper, still used by KEY.asm.
;===================================================================
.PUBLIC			F_Start_RFCMM_Value
F_Start_RFCMM_Value:
	%bitr	R_TempFlag1,(D_MaxTemp+D_MinTemp)
	LDA		#00H
	STA		R_HistoryClearTm
	LDA		R_DispTemper+0
	STA		R_TempMin+0
	STA		R_TempMax+0
	LDA		R_DispTemper+1
	STA		R_TempMin+1
	STA		R_TempMax+1
	LDA		R_DispTemper_F
	STA		R_MINDispTemper_F
	STA		R_MAXDispTemper_F

	LDA		R_DispTemper_F+1
	STA		R_MINDispTemper_F+1
	STA		R_MAXDispTemper_F+1

	LDA		R_DispHum
	STA		R_HumMax
	STA		R_HumMin

	LDA		R_SpecFlag
	STA		R_TempMax_Sign
	STA		R_TempMin_Sign

	LDA		R_TempFlag
	AND		#D_TempFReg
	ORA		R_TempMax_Sign
	STA		R_TempMax_Sign

	LDA		R_TempFlag
	AND		#D_TempFReg
	ORA		R_TempMin_Sign
	STA		R_TempMin_Sign
	RTS

;==============================================================================
; 产品显示框架
; 标准页和历史页共用同一套主布局，只切换页签和记录数据来源。
;==============================================================================
; 入口结构改成旧 RFC 的写法：最外层先按页面分发，再由各页面自己决定
; 是全刷、闪烁当前编辑位，还是直接返回。
F_Display:
F_DisplayProductUI:
			LDA		R_ProductPage
			CMP		#D_PageMoldSet
			BNE		Disp_ProductPage
			JMP		Disp_ProductMoldPage

Disp_ProductCheckHistory:
Disp_ProductStandardJump:
Disp_ProductStandardPage:
Disp_ProductHistoryPage:
Disp_ProductPage:
			; 标准页和历史页共用一个入口，是否显示历史页签由 R_ProductPage 决定。
			%btst	R_TimeStatus,AddOthers,Disp_ProductUpdateAll
			JMP		Disp_ProductIdleRefresh

Disp_ProductIdleRefresh:
			; 标准/历史页空闲时仍需要维持 Mold 图标的半秒闪烁，不必整页重刷。
			JMP		Disp_ProductShowMoldAlert

Disp_ProductStandardUpdateAll:
Disp_ProductHistoryUpdateAll:
Disp_ProductUpdateAll:
			; 标准页/历史页共用一套整页刷新，最后再按页面模式选择页签。
			JSR		Disp_ProductRefreshPagedBody
			LDA		R_ProductPage
			CMP		#D_PageHistory
			BEQ		Disp_ProductShowHistoryTab
			JMP		Disp_ProductShowTodayTab

Disp_ProductRefreshPagedBody:
			; 公共整页刷新：清增量标志，并刷新标准/历史页共用主体。
			JSR		F_ClearIncStatus
			JSR		Disp_ProductRefreshCommonBody
			RTS

Disp_ProductShowHistoryTab:
			LDA		R_HistoryPage
			CMP		#D_His48Hr
			BEQ		Disp_Product48Hr
			CMP		#D_HisAllTm
			BEQ		Disp_ProductAllTm

Disp_ProductShowTodayTab:
			LDX		#T_48Hr
			JSR		NoDisplay_OneBit
			LDX		#T_AllTm
			JSR		NoDisplay_OneBit
			LDX		#T_Today
			JMP		Display_OneBit

Disp_Product48Hr:
			LDX		#T_Today
			JSR		NoDisplay_OneBit
			LDX		#T_AllTm
			JSR		NoDisplay_OneBit
			LDX		#T_48Hr
			JMP		Display_OneBit

Disp_ProductAllTm:
			LDX		#T_Today
			JSR		NoDisplay_OneBit
			LDX		#T_48Hr
			JSR		NoDisplay_OneBit
			LDX		#T_AllTm
			JMP		Display_OneBit


;Disp_ProductPrepareNormalPage:
;			; T_Other 不是设置页专用图标，而是共享的固定辅助位，普通页也要保持点亮。
;			LDX		#T_Other
;			JMP		Display_OneBit


Disp_ProductRefreshCommonBody:
			; 公共主体刷新：
			; 1. 先准备当前页面对应的历史兼容缓冲。
			; 2. 再依次写当前值、历史值、舒适度、趋势、Mold 和电池图标。
			; 这些函数各自落在不同的 LCD 位区，不是重复写同一块区域。
			; 当前真正的浪费点是 AddOthers 只有一个粗粒度脏标志，
			; 只要任何一个区域变化，就会把整套主体刷新链都走一遍。
;			JSR		Disp_ProductPrepareNormalPage
			LDX		#T_Other
			JSR		Display_OneBit			
			JSR		F_LoadHistoryViewBuffers
			JSR		Disp_ProductRefreshValueArea
			JMP		Disp_ProductRefreshStatusIcons


Disp_ProductRefreshValueArea:
			; 数值区：当前温湿度 + 历史 MAX/MIN。
			; 这部分属于同一类“数码位刷新”，目前在 AddOthers 下整体更新。
			JSR		Disp_ProductCurrentTemp
			JSR		Disp_ProductTempRecords
			JSR		Disp_ProductCurrentHum
			JMP		Disp_ProductHumRecords


Disp_ProductRefreshStatusIcons:
			; 状态图标区：舒适度、趋势、Mold、电池。
			; 当前已经改成按目标状态直接更新，互斥组只清其它位，
			; 这样能避免目标图标在整页刷新时先灭再亮。
			; 如果后面还要继续省刷新，再考虑给这些状态组补“上次状态缓存”。
			JSR		Disp_ProductShowComfortState
			JSR		Disp_ProductShowTempTrend
			JSR		Disp_ProductShowHumTrend
			JSR		Disp_ProductShowMoldAlert
			JMP		Disp_ProductShowBatteryIcon


Disp_ProductHidePageTabs:
			; 这个 helper 现在只留给需要“整组页签全灭”的路径，例如 Mold 设置页。
			; 标准页/历史页已经改成按目标页签只清其它两位，避免当前页签闪烁。
			LDX		#T_Today
			JSR		NoDisplay_OneBit
			LDX		#T_48Hr
			JSR		NoDisplay_OneBit
			LDX		#T_AllTm
			JMP		NoDisplay_OneBit


Disp_ProductSetDisplay:
Disp_ProductMoldPage:
			; Mold 设置页沿用标准页底图，只让被编辑的图标和数值闪烁。
			; AddOthers 触发时重画整页底图，其余时间只在显示/隐藏编辑位之间切换。
			%btst	R_TimeStatus,AddOthers,Disp_ProductMoldUpdateAll
			%btsf	R_TimeStatus,HalfSecToggle,Disp_ProductSetRenderValue
			JMP		Disp_ProductSetHideValue

Disp_ProductMoldUpdateAll:
			; Mold 设置页需要先重画共用底图，再覆盖当前阈值显示。
			JSR		F_ClearIncStatus
			JSR		Disp_ProductRefreshCommonBody
			JSR		Disp_ProductHidePageTabs
			JMP		Disp_ProductSetRenderValue
;
;Disp_ProductMoldSet:
;			LDA		R_TimeStatus
;			AND		#HalfSecToggle
;			BEQ		Disp_ProductSetHideValue
;			JMP		Disp_ProductSetRenderValue

Disp_ProductSetHideValue:
			; 闪烁灭相只隐藏被编辑的 Mold 图标和湿度数字，不动其它常驻显示。
			LDX		#T_Mold
			JSR		NoDisplay_OneBit
			LDA		#0AH
			LDX		#T_CurHuL
			JSR		F_LcdDisplayDigital
			LDA		#0AH
			LDX		#T_CurHuH
			JMP		F_LcdDisplayDigital

Disp_ProductSetRenderValue:
			; 闪烁亮相重新点亮 Mold 图标，并把当前阈值写到湿度显示位。
			LDX		#T_Mold
			JSR		Display_OneBit	
			
			LDA		R_MoldSetValue
			JSR		F_DisplayHLValue
			LDX		#T_CurHuH
			jsr		F_LcdDisplayDigital			
			LDA		R_TempBuf
			LDX		#T_CurHuL
			JMP		F_LcdDisplayDigital
			

Disp_ProductShowComfortState:
			; 舒适度图标三选一：只清另外两位，保留当前目标位。
			LDA		R_DispHum
			CMP		#30H
			BCC		Disp_ProductShowComfortDry
			CMP		#70H
			BCC		Disp_ProductShowComfortComf
			LDX		#T_PDry
			JSR		NoDisplay_OneBit
			LDX		#T_PComf
			JSR		NoDisplay_OneBit
			LDX		#T_PWet
			JMP		Display_OneBit

Disp_ProductShowComfortDry:
			LDX		#T_PComf
			JSR		NoDisplay_OneBit
			LDX		#T_PWet
			JSR		NoDisplay_OneBit
			LDX		#T_PDry
			JMP		Display_OneBit

Disp_ProductShowComfortComf:
			LDX		#T_PDry
			JSR		NoDisplay_OneBit
			LDX		#T_PWet
			JSR		NoDisplay_OneBit
			LDX		#T_PComf
			JMP		Display_OneBit

Disp_ProductShowTempTrend:
			; 温度趋势图标三选一：命中目标时只清另外两位。
			LDA		R_TrendFlags
			AND		#D_TempTrendRefresh
			BEQ		Disp_ProductShowTempTrendNoRefresh
			%bitr	R_TrendFlags,D_TempTrendRefresh
			LDA		R_TrendFlags
			AND		#(D_TempTrendUp+D_TempTrendDown)
			BEQ		Disp_ProductShowTempTrendCheckEq
			AND		#D_TempTrendUp
			BNE		Disp_ProductShowTempTrendUp

Disp_ProductShowTempTrendDown:
			LDX		#T_TUp
			JSR		NoDisplay_OneBit
			LDX		#T_TEq
			JSR		NoDisplay_OneBit
			LDX		#T_TDn
			JMP		Display_OneBit

Disp_ProductShowTempTrendCheckEq:
			LDA		R_TrendTempEqCnt
			CMP		#C_TrendEq60Min
			BCC		Disp_ProductShowTempTrendExit

Disp_ProductShowTempTrendEq:
			LDX		#T_TUp
			JSR		NoDisplay_OneBit
			LDX		#T_TDn
			JSR		NoDisplay_OneBit
			LDX		#T_TEq
			JMP		Display_OneBit

Disp_ProductShowTempTrendUp:
			LDX		#T_TEq
			JSR		NoDisplay_OneBit
			LDX		#T_TDn
			JSR		NoDisplay_OneBit
			LDX		#T_TUp
			JMP		Display_OneBit

Disp_ProductShowTempTrendExit:
			LDX		#T_TUp
			JSR		NoDisplay_OneBit
			LDX		#T_TEq
			JSR		NoDisplay_OneBit
			LDX		#T_TDn
			JMP		NoDisplay_OneBit

Disp_ProductShowTempTrendNoRefresh:
			RTS

Disp_ProductShowHumTrend:
			; 湿度趋势图标三选一：命中目标时只清另外两位。
			LDA		R_TrendFlags
			AND		#D_HumTrendRefresh
			BEQ		Disp_ProductShowHumTrendNoRefresh
			%bitr	R_TrendFlags,D_HumTrendRefresh
			LDA		R_TrendFlags
			AND		#(D_HumTrendUp+D_HumTrendDown)
			BEQ		Disp_ProductShowHumTrendCheckEq
			AND		#D_HumTrendUp
			BNE		Disp_ProductShowHumTrendUp

Disp_ProductShowHumTrendDown:
			LDX		#T_HUp
			JSR		NoDisplay_OneBit
			LDX		#T_HEq
			JSR		NoDisplay_OneBit
			LDX		#T_HDn
			JMP		Display_OneBit

Disp_ProductShowHumTrendCheckEq:
			LDA		R_TrendHumEqCnt
			CMP		#C_TrendEq60Min
			BCC		Disp_ProductShowHumTrendExit

Disp_ProductShowHumTrendEq:
			LDX		#T_HUp
			JSR		NoDisplay_OneBit
			LDX		#T_HDn
			JSR		NoDisplay_OneBit
			LDX		#T_HEq
			JMP		Display_OneBit

Disp_ProductShowHumTrendUp:
			LDX		#T_HEq
			JSR		NoDisplay_OneBit
			LDX		#T_HDn
			JSR		NoDisplay_OneBit
			LDX		#T_HUp
			JMP		Display_OneBit

Disp_ProductShowHumTrendExit:
			LDX		#T_HUp
			JSR		NoDisplay_OneBit
			LDX		#T_HEq
			JSR		NoDisplay_OneBit
			LDX		#T_HDn
			JMP		NoDisplay_OneBit

Disp_ProductShowHumTrendNoRefresh:
			RTS

; 当前湿度达到 mold 阈值时点亮 Mold 图标。
Disp_ProductShowMoldAlert:
			; Mold 图标在超阈值时按半秒闪烁，退出阈值后立即熄灭。
			LDA		R_DispHum
			CMP		R_MoldSetValue
			BCC		Disp_ProductShowMoldAlertHide
			%btsf	R_TimeStatus,HalfSecToggle,Disp_ProductShowMoldAlertHide
			LDX		#T_Mold
			JMP		Display_OneBit
Disp_ProductShowMoldAlertHide:
			LDX		#T_Mold
			JMP		NoDisplay_OneBit

Disp_ProductShowBatteryIcon:
			; 电池图标同样按目标状态直接更新，避免低电时先灭后亮。
			LDA		R_BatteryFlags
			AND		#D_BatteryLow
			BEQ		Disp_ProductShowBatteryIconHide
			LDX		#T_Bat
			JMP		Display_OneBit
Disp_ProductShowBatteryIconHide:
			LDX		#T_Bat
			JMP		NoDisplay_OneBit

; 当前值直接使用兼容 RFC/GXHTV4 的实时缓冲。
; 先判断 HH/LL 和 C/F，再进入对应的具体显示分支。
Disp_ProductCurrentTemp:
			%btst	R_SpecFlag,D_TempHH,Disp_ProductCurrentTempHH
			%btst	R_SpecFlag,D_TempLL,Disp_ProductCurrentTempLL
			%btst	R_SpecFlag,D_TF,Disp_ProductCurrentTempF
			JMP		Disp_ProductCurrentTempC

Disp_ProductCurrentTempHH:
			LDA		#0CH
			JMP		Disp_ProductDisplayCurrentTempCode

Disp_ProductCurrentTempLL:
			LDA		#0FH
			JMP		Disp_ProductDisplayCurrentTempCode

; HH/LL 这种异常码直接写三位数码位，不再走正常温度拆位流程。
Disp_ProductDisplayCurrentTempCode:
			PHA
			LDX		#T_CurTeH
			JSR		F_LcdDisplayDigital
			PLA
			PHA
			LDX		#T_CurTeM
			JSR		F_LcdDisplayDigital
			PLA
			LDX		#T_CurTeL
			JSR		F_LcdDisplayDigital
			JSR		Disp_ProductShowCurrentUnit
			LDX		#T_TeNeg
			JSR		NoDisplay_OneBit
			LDX		#T_CurTe100
			JMP		NoDisplay_OneBit

; 当前温度单位图标互斥显示，只保留 C 或 F 其中一个。
Disp_ProductShowCurrentUnit:
			%btst	R_SpecFlag,D_TF,Disp_ProductShowCurrentUnitF

Disp_ProductShowCurrentUnitC:
			LDX		#T_CUnit
			JSR		Display_OneBit
			LDX		#T_MINCUnit
			JSR		Display_OneBit
			LDX		#T_MAXCUnit
			JSR		Display_OneBit						
			LDX		#T_MAXFUnit
			JSR		NoDisplay_OneBit
			LDX		#T_MINFUnit
			JSR		NoDisplay_OneBit				
			LDX		#T_FUnit
			JMP		NoDisplay_OneBit

Disp_ProductShowCurrentUnitF:
			LDX		#T_CUnit
			JSR		NoDisplay_OneBit
			LDX		#T_MINCUnit
			JSR		NoDisplay_OneBit
			LDX		#T_MAXCUnit
			JSR		NoDisplay_OneBit						
			LDX		#T_MAXFUnit
			JSR		Display_OneBit
			LDX		#T_MINFUnit
			JSR		Display_OneBit			
			LDX		#T_FUnit
			JMP		Display_OneBit

; 华氏度当前值不再重算，直接使用 Alarm 里已经准备好的 BCD 结果。
Disp_ProductCurrentTempF:
			LDA		R_DispTemper_F+0
			STA		R_TempBuf+5
			LDA		R_DispTemper_F+1
			STA		R_TempBuf+6
			JSR		Disp_ProductRenderCurrentTempFromBuf
			JSR		Disp_ProductShowCurrentUnitF
			LDX		#T_TeNeg
			JSR		NoDisplay_OneBit
			LDA		R_TempBuf+5
			JSR		F_DisplayHLValue
			BEQ		Disp_ProductCurrentTempF_No100
			LDX		#T_CurTe100
			JMP		Display_OneBit

Disp_ProductCurrentTempF_No100:
			LDX		#T_CurTe100
			JMP		NoDisplay_OneBit
			
; 摄氏度当前值走实时原始温度，重新转一次 BCD 后再显示。
; 这样能统一处理负号、百位留空和当前值三位数码位布局。
Disp_ProductCurrentTempC:
			LDA		R_DispTemper+0
			STA		R_TempBuf+5
			LDA		R_DispTemper+1
			STA		R_TempBuf+6
			JSR		Disp_ProductRenderCurrentTempFromBuf
			JSR		Disp_ProductShowCurrentUnitC
			%btst	R_SpecFlag,D_Neg,Disp_ProductCurrentTempC_Neg
			LDX		#T_TeNeg
			JSR		NoDisplay_OneBit
			LDX		#T_CurTe100
			JMP		NoDisplay_OneBit

Disp_ProductCurrentTempC_Neg:
			LDX		#T_TeNeg
			JSR		Display_OneBit
			LDX		#T_CurTe100
			JMP		NoDisplay_OneBit

;; F_CAL_HEX_BCD2 的结果在 OUT_M/OUT_L，这里先搬到通用显示缓冲，
;; 后面摄氏和华氏都复用同一套拆位显示逻辑。
;Disp_ProductRenderCurrentTempFromOut:
;			LDA		OUT_M
;			STA		R_TempBuf+5
;			LDA		OUT_L
;			STA		R_TempBuf+4
;			JMP		Disp_ProductRenderCurrentTempFromBuf

; R_TempBuf+5 是高两位 BCD，R_TempBuf+4 是低两位 BCD。
; F_DisplayHLValue 会把低 4 bit 放到 R_TempBuf，并把高 4 bit 留在 A。
; 这里先处理最高位：
; 1. 若十位非 0，就直接显示十位。
; 2. 若十位为 0 且百位非 0，就显示 0。
; 3. 若十位和百位都为 0，就最高位留空。
; 首次 PHA 只是为了让下面所有分支在 Disp_ProductCurTempH_Out 的 PLA 数量保持一致，
; 否则走“最高位留空”的分支时会把返回地址从栈里误弹出来，表现成跑飞或复位。
Disp_ProductRenderCurrentTempFromBuf:
			LDA		R_TempBuf+5
			JSR		F_DisplayHLValue
			STA		R_TempBuf+4
			LDA		R_TempBuf
			BNE		Disp_ProductCurTempH_Out			
			LDA		R_TempBuf+4
			BNE		Disp_ProductCurTempH_ShowZero
Disp_ProductCurTempH_Blank:
			LDA		#0AH
			JMP		Disp_ProductCurTempH_Out

Disp_ProductCurTempH_ShowZero:
			LDA		#00H
Disp_ProductCurTempH_Out:
			LDX		#T_CurTeH
			JSR		F_LcdDisplayDigital	
			LDA		R_TempBuf+6
			JSR		F_DisplayHLValue
			LDX		#T_CurTeM
			JSR		F_LcdDisplayDigital			
			LDA		R_TempBuf
			LDX		#T_CurTeL
			JMP		F_LcdDisplayDigital


; 当前湿度显示和温度不同，直接使用 Alarm 已整理好的 BCD 缓冲。
Disp_ProductCurrentHum:
			%btst	R_SpecFlag,D_HumHH,Disp_ProductCurrentHumHH
			%btst	R_SpecFlag,D_HumLL,Disp_ProductCurrentHumLL
			LDA		R_DispHum
			JSR		F_DisplayHLValue
			PHA
			LDA		R_TempBuf
			LDX		#T_CurHuL
			JSR		F_LcdDisplayDigital
			PLA
			BNE		Disp_ProductCurHumH_Out
			LDA		#0AH

Disp_ProductCurHumH_Out:
			LDX		#T_CurHuH
			JMP		F_LcdDisplayDigital

Disp_ProductCurrentHumHH:
			LDA		#0CH
			JMP		Disp_ProductDisplayCurrentHumCode

Disp_ProductCurrentHumLL:
			LDA		#0FH
			JMP		Disp_ProductDisplayCurrentHumCode

; 湿度 HH/LL 和温度一样，直接把异常码写到两位数码位。
Disp_ProductDisplayCurrentHumCode:
			PHA
			LDX		#T_CurHuH
			JSR		F_LcdDisplayDigital
			PLA
			LDX		#T_CurHuL
			JMP		F_LcdDisplayDigital

; 记录值目前仍复用旧 max/min 缓冲，后续会切到真实 history RAM。
Disp_ProductTempRecords:
			LDA		R_HistoryClearTm
			BNE		Disp_ProductTempRecordsDash
			LDA		R_HistoryViewFlags
			AND		#D_HistoryViewTempValid
			BEQ		Disp_ProductTempRecordsDash
			%btst	R_SpecFlag,D_TF,Disp_ProductTempRecordsF_1
			JMP		Disp_ProductTempRecordsC
Disp_ProductTempRecordsF_1:
			JMP		Disp_ProductTempRecordsF
Disp_ProductTempRecordsDash:
			%btst	R_SpecFlag,D_TF,Disp_ProductTempRecordsDashF
			JMP		Disp_ProductTempRecordsDashC

Disp_ProductTempRecordsDashC:
			LDX		#T_MaxTe100
			JSR		NoDisplay_OneBit
			LDX		#T_MinTe100
			JSR		NoDisplay_OneBit
			JSR		Disp_ProductRenderMaxTempDashC
			JMP		Disp_ProductRenderMinTempDashC

Disp_ProductTempRecordsDashF:
			JSR		Disp_ProductRenderMaxTempDashF
			JMP		Disp_ProductRenderMinTempDashF
			
Disp_ProductTempRecordsC:
Disp_ProductRenderMaxTempC:	
			LDX		#T_MaxTe100
			JSR		NoDisplay_OneBit
			LDX		#T_MinTe100
			JSR		NoDisplay_OneBit
			LDA		R_TempMax
			JSR		F_DisplayHLValue
			LDA		R_TempBuf
			BNE		Disp_ProductMaxTempC_HOut
			LDA		#0AH
Disp_ProductMaxTempC_HOut:
			LDX		#T_MaxTeH
			JSR		F_LcdDisplayDigital
			LDA		R_TempMax+1			
			JSR		F_DisplayHLValue
			LDX		#T_MaxTeM
			JSR		F_LcdDisplayDigital
			LDA		R_TempBuf
			LDX		#T_MaxTeL
			JSR		F_LcdDisplayDigital
			%btst	R_TempMax_Sign,D_Neg,Disp_ProductMaxTempC_Neg
			LDX		#T_MaxTeNeg
			JSR		NoDisplay_OneBit
			JMP		Disp_ProductRenderMinTempC
Disp_ProductMaxTempC_Neg:
			LDX		#T_MaxTeNeg
			JSR		Display_OneBit
			
Disp_ProductRenderMinTempC:
			LDA		R_TempMin+0
			JSR		F_DisplayHLValue
			LDA		R_TempBuf
			BNE		Disp_ProductMinTempC_HOut
			LDA		#0AH
Disp_ProductMinTempC_HOut:
			LDX		#T_MinTeH
			JSR		F_LcdDisplayDigital
			LDA		R_TempMin+1
			JSR		F_DisplayHLValue			
			LDX		#T_MinTeM
			JSR		F_LcdDisplayDigital
			LDA		R_TempBuf
			LDX		#T_MinTeL
			JSR		F_LcdDisplayDigital	
			%btst	R_TempMin_Sign,D_Neg,Disp_ProductMinTempC_Neg
			LDX		#T_MinTeNeg
			JMP		NoDisplay_OneBit
Disp_ProductMinTempC_Neg:
			LDX		#T_MinTeNeg
			JMP		Display_OneBit
			

Disp_ProductTempRecordsF:		;大小F值	
			LDA		R_MAXDispTemper_F+0
			JSR		F_DisplayHLValue
			BEQ		Disp_ProductMaxTempF_No100
			LDX		#T_MaxTe100
			JSR		Display_OneBit
			JMP		Disp_ProductMaxTempF_Digits
Disp_ProductMaxTempF_No100:
			LDX		#T_MaxTe100
			JSR		NoDisplay_OneBit
Disp_ProductMaxTempF_Digits			
			LDA		R_TempBuf
			LDX		#T_MaxTeH
			JSR		F_LcdDisplayDigital
			
			LDA		R_MAXDispTemper_F+1
			JSR		F_DisplayHLValue
			LDX		#T_MaxTeM
			JSR		F_LcdDisplayDigital
			LDA		R_TempBuf
			LDX		#T_MaxTeL
			JSR		F_LcdDisplayDigital

Disp_ProductMinTempF:			
			LDA		R_MINDispTemper_F+0
			JSR		F_DisplayHLValue
			BEQ		Disp_ProductMinTempF_No100
			LDX		#T_MinTe100
			JSR		Display_OneBit
			JMP		Disp_ProductMinTempF_Digits
Disp_ProductMinTempF_No100:
			LDX		#T_MinTe100
			JSR		NoDisplay_OneBit
Disp_ProductMinTempF_Digits:			
			LDA		R_TempBuf
			LDX		#T_MinTeH
			JSR		F_LcdDisplayDigital
			LDA		R_MINDispTemper_F+1
			JSR		F_DisplayHLValue
			LDX		#T_MinTeM
			JSR		F_LcdDisplayDigital
			LDA		R_TempBuf
			LDX		#T_MinTeL
			JMP		F_LcdDisplayDigital

			


Disp_ProductRenderMaxTempDashC:
			LDA		#0BH
			LDX		#T_MaxTeH
			JSR		F_LcdDisplayDigital
			LDA		#0BH
			LDX		#T_MaxTeM
			JSR		F_LcdDisplayDigital
			LDA		#0BH
			LDX		#T_MaxTeL
			JSR		F_LcdDisplayDigital
			LDX		#T_MaxTeNeg
			JMP		NoDisplay_OneBit

Disp_ProductRenderMinTempDashC:
			LDA		#0BH
			LDX		#T_MinTeH
			JSR		F_LcdDisplayDigital
			LDA		#0BH
			LDX		#T_MinTeM
			JSR		F_LcdDisplayDigital
			LDA		#0BH
			LDX		#T_MinTeL
			JSR		F_LcdDisplayDigital
			LDX		#T_MinTeNeg
			JMP		NoDisplay_OneBit

Disp_ProductRenderMaxTempDashF:
			LDX		#T_MaxTe100
			JSR		NoDisplay_OneBit
			LDA		#0BH
			LDX		#T_MaxTeH
			JSR		F_LcdDisplayDigital
			LDA		#0BH
			LDX		#T_MaxTeM
			JSR		F_LcdDisplayDigital
			LDA		#0BH
			LDX		#T_MaxTeL
			JMP		F_LcdDisplayDigital

Disp_ProductRenderMinTempDashF:
			LDX		#T_MinTe100
			JSR		NoDisplay_OneBit
			LDA		#0BH
			LDX		#T_MinTeH
			JSR		F_LcdDisplayDigital
			LDA		#0BH
			LDX		#T_MinTeM
			JSR		F_LcdDisplayDigital
			LDA		#0BH
			LDX		#T_MinTeL
			JMP		F_LcdDisplayDigital


Disp_ProductHumRecords:
			LDA		R_HistoryClearTm
			BNE		Disp_ProductHumRecordsDash
			LDA		R_HistoryViewFlags
			AND		#D_HistoryViewValid
			BEQ		Disp_ProductHumRecordsDash
			LDA		R_HumMax
			JSR		Disp_ProductRenderMaxHum
			LDA		R_HumMin
			JMP		Disp_ProductRenderMinHum

Disp_ProductHumRecordsDash:
			JSR		Disp_ProductRenderMaxHumDash
			JMP		Disp_ProductRenderMinHumDash

Disp_ProductRenderMaxHumDash:
			LDA		#0BH
			LDX		#T_MaxHuH
			JSR		F_LcdDisplayDigital
			LDA		#0BH
			LDX		#T_MaxHuL
			JSR		F_LcdDisplayDigital
			RTS

Disp_ProductRenderMinHumDash:
			LDA		#0BH
			LDX		#T_MinHuH
			JSR		F_LcdDisplayDigital
			LDA		#0BH
			LDX		#T_MinHuL
			JSR		F_LcdDisplayDigital
			RTS

Disp_ProductRenderMaxHum:
			JSR		F_DisplayHLValue
			PHA
			LDA		R_TempBuf
			LDX		#T_MaxHuL
			JSR		F_LcdDisplayDigital
			PLA
			BNE		Disp_ProductMaxHumH_Out
			LDA		#0AH

Disp_ProductMaxHumH_Out:
			LDX		#T_MaxHuH
			JMP		F_LcdDisplayDigital

Disp_ProductRenderMinHum:
			JSR		F_DisplayHLValue
			PHA
			LDA		R_TempBuf
			LDX		#T_MinHuL
			JSR		F_LcdDisplayDigital
			PLA
			BNE		Disp_ProductMinHumH_Out
			LDA		#0AH

Disp_ProductMinHumH_Out:
			LDX		#T_MinHuH
			JMP		F_LcdDisplayDigital

