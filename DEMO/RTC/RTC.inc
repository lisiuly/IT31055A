
;===================================================
;			RAM Define
;====================================================
.extern			R_TimeStatus
HalfSecToggle			EQU		01000000B

AddSecondOnly			EQU		00100000B
AddOthers				EQU		00010000B
.extern			RTC
.extern			DATE
.EXTERN			TR01
;===================================================
;			Module Define
;====================================================
.extern			F_ResetRealTimeClock
.extern			F_RealTimeClock
.extern			F_ClearIncStatus
.extern			F_ClearSecond
.extern			DEC_YMDHMS
.extern			INC_SEC	
.extern			INC_MIN  
.EXTERN			INC_MIN1
.EXTERN			INC_MIN2
.extern			INC_HR 
.extern			INC_HR1 
.extern			INC_DAT 
.extern			INC_HR2		;x for RAM, a for Max 
.extern			INC_MON  
.extern			INC_YER  
.extern			MAXDCMP
.extern			WEEKCAL



;====================================================

