;==================================================================================
; The information contained herein is the exclusive property of
; Generalplus Technology Co. And shall not be distributed, reproduced,
; or disclosed in whole in part without prior written permission.
;       (C) COPYRIGHT 2017   Generalplus TECHNOLOGY CO.                            
;                   ALL RIGHTS RESERVED
; The entire notice above must be reproduced on all authorized copies.
;==================================================================================
;==================================================================================
; Name                  : Startup.asm
; Applied Body          : GPL813X
; Programmer            : 
; Description           : 
; History version       : 
;==================================================================================

;==========================================
; Compiler parameter define
;==========================================
.SYNTAX 6502
.LINKLIST
.SYMBOLS

;==========================================
; Constant define area
;==========================================




;==========================================
; Include file area
;==========================================




;==========================================
; External declare area
;==========================================
.EXTERN User_Code_Start

;==========================================
; Public declare area
;==========================================
.PUBLIC V_RESET

;==========================================================================
; Product build reset entry. Factory test table is removed to recover ROM.
;==========================================================================
TEST_CODE:	.SECTION
V_RESET:
	SEI
	LDX		#FFH
	TXS
	JMP		User_Code_Start
	.ENDS

.END

