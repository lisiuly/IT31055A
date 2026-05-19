
;===================================================
;			RAM Define
;====================================================
.EXTERN		F_JudgeRFC
.EXTERN		F_UpdateTHFromGXHTV4
.EXTERN		F_LoadHistoryViewBuffers
.EXTERN		F_ClearCurrentHistory
.EXTERN		F_MoldAlarm128Hz
.EXTERN		F_CheckLowBattery

.EXTERN		CalculateRFC    

.EXTERN		R_TempCH
.EXTERN		R_TempCL
.EXTERN		R_HUM
.EXTERN		MoldAlarm_RunPattern
.EXTERN		R_MoldAlarmTm
;.EXTERN			R_PortD_Data_Buf
;===================================================
;			Module Define
;====================================================
.EXTERN		R_KeyToneTm
.EXTERN		R_SoundOn

.EXTERN		R_HistoryClearTm
.EXTERN		R_HistoryViewFlags
D_HistoryViewValid	equ	0x01
D_HistoryViewTempValid	equ	0x02

.EXTERN		R_TrendFlags
.EXTERN		R_TrendTempEqCnt
.EXTERN		R_TrendHumEqCnt
.EXTERN		R_BatteryFlags
C_TrendEq60Min	equ	60
D_BatteryLow		equ	0x01
D_TempTrendUp		equ	0x02
D_TempTrendDown	equ	0x04
D_HumTrendUp		equ	0x08
D_HumTrendDown	equ	0x10
D_TempTrendRefresh	equ	0x20
D_HumTrendRefresh	equ	0x40


.EXTERN		R_SpecFlag	
.EXTERN		R_TempMin_Sign
.EXTERN		R_TempMax_Sign	
D_TempHH			equ	0x40
D_TempLL			equ	0x20
D_Neg				equ 0x10	;负温度
D_TF				equ 0x08	;华氏度
D_HumHH				equ	0x04
D_HumLL				equ	0x02
.EXTERN		R_DispTemper_F	
.EXTERN		R_MAXDispTemper_F
.EXTERN		R_MINDispTemper_F	
.EXTERN		R_DispTemper
.EXTERN		R_TempMax          ; 最高温度记录(BCD码，带符号)
.EXTERN		R_TempMin          ; 最低温度记录(BCD码，带符号)
.EXTERN		R_DispHum		
.EXTERN		R_HumMax       ; 最高湿度记录(BCD码，无符号)
.EXTERN		R_HumMin       ; 最低湿度记录(BCD码，无符号)
.EXTERN		R_TempFlag1		
D_MaxTemp		equ	0x01
D_MinTemp		equ	0x02

;.EXTERN		RFC_Process_Flag	
