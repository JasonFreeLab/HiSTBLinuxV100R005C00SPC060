#include "hi_asm_define.h"
	.arch armv8-a+fp+simd
	.file	"vdm_hal_vp9.c"
	.global	_mcount
	.text
	.align	2
	.p2align 3,,7
	.global	VP9HAL_V5R2C1_InitHal
	.type	VP9HAL_V5R2C1_InitHal, %function
VP9HAL_V5R2C1_InitHal:
	stp	x29, x30, [sp, -16]!
	add	x29, sp, 0
	mov	x0, x30
	bl	_mcount
	mov	w0, 0
	ldp	x29, x30, [sp], 16
	ret
	.size	VP9HAL_V5R2C1_InitHal, .-VP9HAL_V5R2C1_InitHal
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	VP9HAL_V5R2C1_CfgReg
	.type	VP9HAL_V5R2C1_CfgReg, %function
VP9HAL_V5R2C1_CfgReg:
	stp	x29, x30, [sp, -96]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	stp	x21, x22, [sp, 32]
	stp	x23, x24, [sp, 48]
	stp	x25, x26, [sp, 64]
	mov	x21, x0
	mov	x0, x30
	mov	w19, w2
	mov	x20, x3
	mov	x24, x1
	bl	_mcount
	ldr	x1, .LC1
	sbfiz	x0, x19, 6, 32
	ldr	x2, .LC0
	cmp	x20, xzr
	str	wzr, [x29, 92]
	ldrb	w1, [x1]
	add	x0, x2, x0
	ccmp	w1, 1, 4, eq
	ldr	w0, [x0, 8]
	bne	.L17
	ldr	x2, .LC5
	ldr	x0, [x2, w0, sxtw 3]
	cbz	x0, .L12
	ldr	w25, [x0, 1312]
.L5:
	cmp	w1, 1
	beq	.L6
	strb	w25, [x20, 1]
.L6:
	cmp	w19, wzr
	bgt	.L18
	ldr	x0, [x24]
	cbz	x0, .L19
.L8:
	add	x21, x21, 270336
	ldr	w4, [x24, 1212]
	ldr	w0, [x29, 92]
	mov	x3, x20
	and	w4, w4, -16
	mov	w2, w19
	str	w4, [x21, 2352]
	mov	w22, 3
	ldr	w1, [x21, 2088]
	mov	w23, 3075
	ldr	w4, [x24, 1216]
	movk	w23, 0x30, lsl 16
	and	w4, w4, -16
	str	w4, [x21, 2356]
	ldr	w4, [x21, 2092]
	mul	w1, w1, w4
	sub	w1, w1, #1
	bfi	w0, w1, 0, 20
	str	w0, [x29, 92]
	ubfx	x0, x0, 24, 6
	strb	w0, [x29, 95]
	mov	w0, 8
	ldr	w26, [x29, 92]
	mov	w1, w26
	bl	MFDE_ConfigReg
	ldr	x1, .LC11
	mov	w2, w26
	mov	w0, w22
	bl	dprint_vfmw
	strh	w22, [x29, 94]
	mov	w0, 0
	ldr	w3, [x21, 2468]
	ldr	w2, [x21, 2488]
	bfi	w0, w25, 4, 1
	and	w0, w0, -33
	mov	w1, 0
	bfi	w1, w2, 4, 1
	bfi	w0, w3, 6, 1
	orr	w1, w1, -64
	mov	w2, 14
	strb	w1, [x29, 93]
	and	w0, w0, 127
	strb	w2, [x29, 92]
	mov	x3, x20
	strb	w0, [x29, 95]
	mov	w2, w19
	mov	w0, 12
	strb	wzr, [x21, 2081]
	ldr	w26, [x29, 92]
	mov	w1, w26
	bl	MFDE_ConfigReg
	ldr	x1, .LC13
	mov	w2, w26
	mov	w0, w22
	bl	dprint_vfmw
	ldr	w26, [x24, 72]
	mov	x3, x20
	mov	w2, w19
	and	w26, w26, -16
	mov	w0, 16
	mov	w1, w26
	bl	MFDE_ConfigReg
	ldr	x1, .LC15
	mov	w2, w26
	mov	w0, w22
	bl	dprint_vfmw
	ldr	w26, [x24, 56]
	mov	x3, x20
	mov	w2, w19
	and	w26, w26, -16
	mov	w0, 20
	mov	w1, w26
	bl	MFDE_ConfigReg
	ldr	x1, .LC17
	mov	w2, w26
	mov	w0, w22
	bl	dprint_vfmw
	ldr	w26, [x21, 2128]
	mov	x3, x20
	mov	w2, w19
	mov	w1, w26
	mov	w0, 24
	bl	MFDE_ConfigReg
	ldr	x1, .LC19
	mov	w2, w26
	mov	w0, w22
	bl	dprint_vfmw
	ldr	w26, [x24, 1180]
	mov	x3, x20
	mov	w2, w19
	and	w26, w26, -16
	mov	w0, 128
	mov	w1, w26
	bl	MFDE_ConfigReg
	ldr	x1, .LC21
	mov	w2, w26
	mov	w0, w22
	bl	dprint_vfmw
	ldr	w24, [x24, 1184]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 132
	mov	w1, w24
	bl	MFDE_ConfigReg
	ldr	x1, .LC23
	mov	w2, w24
	mov	w0, w22
	bl	dprint_vfmw
	str	wzr, [x29, 92]
	mov	x3, x20
	mov	w2, w19
	mov	w1, 0
	mov	w0, 152
	bl	MFDE_ConfigReg
	ldr	x1, .LC25
	mov	w2, 0
	mov	w0, w22
	bl	dprint_vfmw
	ldr	w0, [x21, 2088]
	mov	x3, x20
	mov	w2, w19
	cmp	w0, 256
	mov	w0, 4
	cset	w1, ls
	bl	SCD_ConfigReg
	str	w23, [x29, 92]
	mov	w0, 60
	mov	x3, x20
	mov	w2, w19
	mov	w1, w23
	bl	MFDE_ConfigReg
	mov	x3, x20
	mov	w2, w19
	mov	w1, w23
	mov	w0, 64
	bl	MFDE_ConfigReg
	mov	x3, x20
	mov	w2, w19
	mov	w1, w23
	mov	w0, 68
	bl	MFDE_ConfigReg
	mov	x3, x20
	mov	w2, w19
	mov	w1, w23
	mov	w0, 72
	bl	MFDE_ConfigReg
	mov	x3, x20
	mov	w2, w19
	mov	w1, w23
	mov	w0, 76
	bl	MFDE_ConfigReg
	mov	x3, x20
	mov	w2, w19
	mov	w1, w23
	mov	w0, 80
	bl	MFDE_ConfigReg
	mov	x3, x20
	mov	w2, w19
	mov	w1, w23
	mov	w0, 84
	bl	MFDE_ConfigReg
	cmp	w25, 1
	beq	.L20
.L10:
	ldr	w22, [x21, 2440]
	mov	x3, x20
	mov	w0, 96
	mov	w2, w19
	and	w22, w22, -16
	mov	w1, w22
	bl	MFDE_ConfigReg
	ldr	x1, .LC29
	mov	w2, w22
	mov	w0, 3
	bl	dprint_vfmw
	ldr	w22, [x21, 2096]
	mov	x3, x20
	mov	w0, 100
	mov	w1, w22
	mov	w2, w19
	bl	MFDE_ConfigReg
	ldr	x1, .LC31
	mov	w2, w22
	mov	w0, 3
	bl	dprint_vfmw
	ldr	w22, [x21, 2108]
	mov	x3, x20
	mov	w0, 104
	mov	w1, w22
	mov	w2, w19
	bl	MFDE_ConfigReg
	ldr	x1, .LC33
	mov	w2, w22
	mov	w0, 3
	bl	dprint_vfmw
	ldr	w22, [x21, 2504]
	mov	x3, x20
	mov	w0, 108
	mov	w1, w22
	mov	w2, w19
	bl	MFDE_ConfigReg
	ldr	x1, .LC35
	mov	w2, w22
	mov	w0, 3
	bl	dprint_vfmw
	ldr	w22, [x21, 2508]
	mov	x3, x20
	mov	w0, 116
	mov	w1, w22
	mov	w2, w19
	bl	MFDE_ConfigReg
	ldr	x1, .LC37
	mov	w2, w22
	mov	w0, 3
	bl	dprint_vfmw
	ldr	w22, [x21, 2512]
	mov	x3, x20
	mov	w0, 120
	mov	w1, w22
	mov	w2, w19
	bl	MFDE_ConfigReg
	ldr	x1, .LC39
	mov	w2, w22
	mov	w0, 3
	bl	dprint_vfmw
	ldr	w22, [x21, 2516]
	mov	x3, x20
	mov	w0, 124
	mov	w2, w19
	mov	w1, w22
	str	w22, [x29, 92]
	bl	MFDE_ConfigReg
	ldr	x1, .LC41
	mov	w2, w22
	mov	w0, 3
	bl	dprint_vfmw
	cmp	w25, 1
	beq	.L21
.L11:
	mov	w0, 32
	mov	x3, x20
	mov	w2, w19
	mov	w1, -1
	bl	MFDE_ConfigReg
	mov	w0, 0
.L4:
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x25, x26, [sp, 64]
	ldp	x29, x30, [sp], 96
	ret
	.p2align 3
.L12:
	mov	w25, 0
	b	.L5
	.p2align 3
.L19:
	mov	w0, -121438208
	bl	MEM_Phy2Vir
	cbz	x0, .L9
	str	x0, [x24]
	b	.L8
	.p2align 3
.L21:
	ldr	w21, [x21, 2496]
	mov	w2, w19
	mov	w0, 112
	mov	x3, x20
	mov	w1, w21
	bl	MFDE_ConfigReg
	ldr	x1, .LC43
	mov	w2, w21
	mov	w0, 3
	bl	dprint_vfmw
	b	.L11
	.p2align 3
.L20:
	mov	w2, w19
	mov	w1, 60
	mov	w0, 92
	mov	x3, x20
	bl	MFDE_ConfigReg
	ldr	x1, .LC27
	mov	w2, 60
	mov	w0, w22
	bl	dprint_vfmw
	b	.L10
	.p2align 3
.L18:
	ldr	x2, .LC2
	mov	w4, 0
	ldr	x1, .LC7
	mov	w3, w19
	mov	w0, 0
	bl	dprint_vfmw
	mov	w0, -1
	b	.L4
.L17:
	ldr	x2, .LC2
	mov	x3, x20
	ldr	x1, .LC4
	mov	w0, 0
	bl	dprint_vfmw
	mov	w0, -1
	b	.L4
.L9:
	ldr	x1, .LC9
	mov	w0, 0
	bl	dprint_vfmw
	mov	w0, -1
	b	.L4
	.size	VP9HAL_V5R2C1_CfgReg, .-VP9HAL_V5R2C1_CfgReg
	.align	3
.LC0:
	.xword	g_VdmDrvParam
	.align	3
.LC1:
	.xword	g_HalDisable
	.align	3
.LC2:
	.xword	.LANCHOR0
	.align	3
.LC4:
	.xword	.LC3
	.align	3
.LC5:
	.xword	s_pstVfmwChan
	.align	3
.LC7:
	.xword	.LC6
	.align	3
.LC9:
	.xword	.LC8
	.align	3
.LC11:
	.xword	.LC10
	.align	3
.LC13:
	.xword	.LC12
	.align	3
.LC15:
	.xword	.LC14
	.align	3
.LC17:
	.xword	.LC16
	.align	3
.LC19:
	.xword	.LC18
	.align	3
.LC21:
	.xword	.LC20
	.align	3
.LC23:
	.xword	.LC22
	.align	3
.LC25:
	.xword	.LC24
	.align	3
.LC27:
	.xword	.LC26
	.align	3
.LC29:
	.xword	.LC28
	.align	3
.LC31:
	.xword	.LC30
	.align	3
.LC33:
	.xword	.LC32
	.align	3
.LC35:
	.xword	.LC34
	.align	3
.LC37:
	.xword	.LC36
	.align	3
.LC39:
	.xword	.LC38
	.align	3
.LC41:
	.xword	.LC40
	.align	3
.LC43:
	.xword	.LC42
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	VP9HAL_V5R2C1_CfgFrameMsg
	.type	VP9HAL_V5R2C1_CfgFrameMsg, %function
VP9HAL_V5R2C1_CfgFrameMsg:
	stp	x29, x30, [sp, -112]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	stp	x21, x22, [sp, 32]
	stp	x23, x24, [sp, 48]
	stp	x25, x26, [sp, 64]
	stp	x27, x28, [sp, 80]
	mov	x20, x1
	mov	x19, x0
	mov	x0, x30
	bl	_mcount
	ldr	w0, [x20, 72]
	bl	MEM_Phy2Vir
	mov	x22, x0
	cbz	x0, .L29
	ldr	w0, [x19]
	add	x21, x19, 270336
	str	w0, [x22]
	mov	w0, 4
	ldr	x27, .LC50
	ldr	w2, [x22]
	mov	x1, x27
	bl	dprint_vfmw
	ldr	x26, .LC52
	ldr	w0, [x19, 4]
	str	w0, [x22, 4]
	mov	x1, x26
	mov	w0, 4
	ldr	w2, [x22, 4]
	bl	dprint_vfmw
	ldr	x25, .LC54
	ldr	w0, [x19, 8]
	str	w0, [x22, 8]
	mov	x1, x25
	mov	w0, 4
	ldr	w2, [x22, 8]
	bl	dprint_vfmw
	ldr	x24, .LC56
	ldr	w0, [x19, 12]
	str	w0, [x22, 12]
	mov	x1, x24
	mov	w0, 4
	ldr	w2, [x22, 12]
	bl	dprint_vfmw
	ldr	x23, .LC58
	ldr	w0, [x19, 16]
	str	w0, [x22, 16]
	mov	x1, x23
	mov	w0, 4
	ldr	w2, [x22, 16]
	bl	dprint_vfmw
	ldr	w0, [x19, 20]
	str	w0, [x22, 20]
	mov	w0, 4
	ldr	x1, .LC60
	ldr	w2, [x22, 20]
	bl	dprint_vfmw
	ldr	w0, [x19, 24]
	str	w0, [x22, 24]
	mov	w0, 4
	ldr	x1, .LC62
	ldr	w2, [x22, 24]
	bl	dprint_vfmw
	ldr	w0, [x19, 28]
	str	w0, [x22, 28]
	mov	w0, 4
	ldr	x1, .LC64
	ldr	w2, [x22, 28]
	bl	dprint_vfmw
	ldr	w0, [x19, 32]
	str	w0, [x22, 32]
	mov	w0, 4
	ldr	x1, .LC66
	ldr	w2, [x22, 32]
	bl	dprint_vfmw
	ldr	w0, [x19, 36]
	str	w0, [x22, 36]
	mov	w0, 4
	ldr	x1, .LC68
	ldr	w2, [x22, 36]
	bl	dprint_vfmw
	ldr	w0, [x19, 40]
	str	w0, [x22, 40]
	mov	w0, 4
	ldr	x1, .LC70
	ldr	w2, [x22, 40]
	bl	dprint_vfmw
	ldr	w0, [x19, 44]
	str	w0, [x22, 44]
	mov	w0, 4
	ldr	x1, .LC72
	ldr	w2, [x22, 44]
	bl	dprint_vfmw
	ldr	w0, [x19, 48]
	str	w0, [x22, 48]
	mov	w0, 4
	ldr	x1, .LC74
	ldr	w2, [x22, 48]
	bl	dprint_vfmw
	ldr	w0, [x19, 52]
	str	w0, [x22, 52]
	mov	w0, 4
	ldr	x1, .LC76
	ldr	w2, [x22, 52]
	bl	dprint_vfmw
	ldr	w0, [x19, 56]
	str	w0, [x22, 56]
	mov	w0, 4
	ldr	x1, .LC78
	ldr	w2, [x22, 56]
	bl	dprint_vfmw
	ldr	w0, [x19, 60]
	str	w0, [x22, 60]
	mov	w0, 4
	ldr	x1, .LC80
	ldr	w2, [x22, 60]
	bl	dprint_vfmw
	ldr	w0, [x19, 64]
	str	w0, [x22, 64]
	mov	w0, 4
	ldr	x1, .LC82
	ldr	w2, [x22, 64]
	bl	dprint_vfmw
	ldr	w0, [x19, 68]
	str	w0, [x22, 68]
	mov	w0, 4
	ldr	x1, .LC84
	ldr	w2, [x22, 68]
	bl	dprint_vfmw
	ldr	w0, [x19, 72]
	str	w0, [x22, 72]
	mov	w0, 4
	ldr	x1, .LC86
	ldr	w2, [x22, 72]
	bl	dprint_vfmw
	ldr	w0, [x19, 76]
	str	w0, [x22, 76]
	mov	w0, 4
	ldr	x1, .LC88
	ldr	w2, [x22, 76]
	bl	dprint_vfmw
	ldr	w0, [x19, 80]
	str	w0, [x22, 80]
	mov	w0, 4
	ldr	x1, .LC90
	ldr	w2, [x22, 80]
	bl	dprint_vfmw
	ldr	w0, [x19, 84]
	str	w0, [x22, 84]
	mov	w0, 4
	ldr	x1, .LC92
	ldr	w2, [x22, 84]
	bl	dprint_vfmw
	ldr	w0, [x19, 88]
	str	w0, [x22, 88]
	mov	w0, 4
	ldr	x1, .LC94
	ldr	w2, [x22, 88]
	bl	dprint_vfmw
	ldr	w0, [x19, 92]
	str	w0, [x22, 92]
	mov	w0, 4
	ldr	x1, .LC96
	ldr	w2, [x22, 92]
	bl	dprint_vfmw
	ldr	w0, [x19, 96]
	str	w0, [x22, 96]
	mov	w0, 4
	ldr	x1, .LC98
	ldr	w2, [x22, 96]
	bl	dprint_vfmw
	ldr	w0, [x19, 100]
	str	w0, [x22, 100]
	mov	w0, 4
	ldr	x1, .LC100
	ldr	w2, [x22, 100]
	bl	dprint_vfmw
	ldr	w0, [x19, 104]
	str	w0, [x22, 104]
	mov	w0, 4
	ldr	x1, .LC102
	ldr	w2, [x22, 104]
	bl	dprint_vfmw
	ldr	w0, [x19, 108]
	str	w0, [x22, 108]
	mov	w0, 4
	ldr	x1, .LC104
	ldr	w2, [x22, 108]
	bl	dprint_vfmw
	ldr	w0, [x19, 112]
	str	w0, [x22, 112]
	mov	w0, 4
	ldr	x1, .LC106
	ldr	w2, [x22, 112]
	bl	dprint_vfmw
	ldr	w0, [x19, 116]
	str	w0, [x22, 116]
	mov	w0, 4
	ldr	x1, .LC108
	ldr	w2, [x22, 116]
	bl	dprint_vfmw
	ldr	w0, [x19, 120]
	str	w0, [x22, 120]
	mov	w0, 4
	ldr	x1, .LC110
	ldr	w2, [x22, 120]
	bl	dprint_vfmw
	ldr	w0, [x21, 2440]
	str	w0, [x22, 128]
	mov	w0, 4
	ldr	x1, .LC112
	ldr	w2, [x22, 128]
	bl	dprint_vfmw
	ldr	w0, [x21, 2444]
	str	w0, [x22, 132]
	mov	w0, 4
	ldr	x1, .LC114
	ldr	w2, [x22, 132]
	bl	dprint_vfmw
	ldr	w0, [x21, 2448]
	str	w0, [x22, 136]
	mov	w0, 4
	ldr	x1, .LC116
	ldr	w2, [x22, 136]
	bl	dprint_vfmw
	ldr	w0, [x21, 2452]
	str	w0, [x22, 140]
	mov	w0, 4
	ldr	x1, .LC118
	ldr	w2, [x22, 140]
	bl	dprint_vfmw
	ldr	w0, [x20, 1160]
	ldr	x1, .LC120
	and	w0, w0, -16
	str	w0, [x22, 144]
	mov	w0, 4
	ldr	w2, [x22, 144]
	bl	dprint_vfmw
	ldr	w0, [x20, 1164]
	ldr	x1, .LC122
	and	w0, w0, -16
	str	w0, [x22, 148]
	mov	w0, 4
	ldr	w2, [x22, 148]
	bl	dprint_vfmw
	ldr	w0, [x20, 1168]
	ldr	x1, .LC124
	and	w0, w0, -16
	str	w0, [x22, 152]
	mov	w0, 4
	ldr	w2, [x22, 152]
	bl	dprint_vfmw
	ldr	w28, [x20, 1212]
	ldr	x1, .LC126
	mov	w0, 4
	and	w28, w28, -16
	str	w28, [x22, 156]
	ldr	w2, [x22, 156]
	bl	dprint_vfmw
	mov	w0, w28
	bl	MEM_Phy2Vir
	str	x0, [x29, 104]
	cbz	x0, .L30
	ldr	x28, .LC129
	add	x1, x19, 262144
	add	x1, x1, 1029
	mov	x2, 4608
	ldr	x5, [x28, 104]
	blr	x5
	ldr	w0, [x20, 1176]
	ldr	x1, .LC131
	and	w0, w0, -16
	str	w0, [x22, 160]
	mov	w0, 4
	ldr	w2, [x22, 160]
	bl	dprint_vfmw
	ldr	w0, [x20, 1216]
	ldr	x1, .LC133
	and	w0, w0, -16
	str	w0, [x22, 164]
	mov	w0, 4
	ldr	w2, [x22, 164]
	bl	dprint_vfmw
	ldr	w0, [x21, 2456]
	ldr	x1, .LC135
	and	w0, w0, -16
	str	w0, [x22, 168]
	mov	w0, 4
	ldr	w2, [x22, 168]
	bl	dprint_vfmw
	ldr	w0, [x20, 1208]
	ldr	x1, .LC137
	and	w0, w0, -16
	str	w0, [x22, 172]
	mov	w0, 4
	ldr	w2, [x22, 172]
	bl	dprint_vfmw
	ldr	w0, [x19, 180]
	str	w0, [x22, 180]
	mov	w0, 4
	ldr	x1, .LC139
	ldr	w2, [x22, 180]
	bl	dprint_vfmw
	ldr	w0, [x19, 184]
	str	w0, [x22, 184]
	mov	w0, 4
	ldr	x1, .LC141
	ldr	w2, [x22, 184]
	bl	dprint_vfmw
	ldr	w0, [x19, 188]
	str	w0, [x22, 188]
	mov	w0, 4
	ldr	x1, .LC143
	ldr	w2, [x22, 188]
	bl	dprint_vfmw
	ldr	w0, [x19, 192]
	str	w0, [x22, 192]
	mov	w0, 4
	ldr	x1, .LC145
	ldr	w2, [x22, 192]
	bl	dprint_vfmw
	ldr	w0, [x19, 196]
	str	w0, [x22, 196]
	mov	w0, 4
	ldr	x1, .LC147
	ldr	w2, [x22, 196]
	bl	dprint_vfmw
	ldr	w0, [x19, 200]
	str	w0, [x22, 200]
	mov	w0, 4
	ldr	x1, .LC149
	ldr	w2, [x22, 200]
	bl	dprint_vfmw
	ldr	w0, [x19, 204]
	str	w0, [x22, 204]
	mov	w0, 4
	ldr	x1, .LC151
	ldr	w2, [x22, 204]
	bl	dprint_vfmw
	ldr	w0, [x19, 208]
	str	w0, [x22, 208]
	mov	w0, 4
	ldr	x1, .LC153
	ldr	w2, [x22, 208]
	bl	dprint_vfmw
	ldr	w0, [x19, 212]
	str	w0, [x22, 212]
	mov	w0, 4
	ldr	x1, .LC155
	ldr	w2, [x22, 212]
	bl	dprint_vfmw
	ldr	w0, [x19, 216]
	str	w0, [x22, 216]
	mov	w0, 4
	ldr	x1, .LC157
	ldr	w2, [x22, 216]
	bl	dprint_vfmw
	ldr	w0, [x19, 220]
	str	w0, [x22, 220]
	mov	w0, 4
	ldr	x1, .LC159
	ldr	w2, [x22, 220]
	bl	dprint_vfmw
	ldr	w0, [x19, 224]
	str	w0, [x22, 224]
	mov	w0, 4
	ldr	x1, .LC161
	ldr	w2, [x22, 224]
	bl	dprint_vfmw
	ldr	w0, [x19, 228]
	str	w0, [x22, 228]
	mov	w0, 4
	ldr	x1, .LC163
	ldr	w2, [x22, 228]
	bl	dprint_vfmw
	ldr	w0, [x19, 232]
	str	w0, [x22, 232]
	mov	w0, 4
	ldr	x1, .LC165
	ldr	w2, [x22, 232]
	bl	dprint_vfmw
	ldr	w0, [x19, 236]
	str	w0, [x22, 236]
	mov	w0, 4
	ldr	x1, .LC167
	ldr	w2, [x22, 236]
	bl	dprint_vfmw
	ldr	w0, [x19, 240]
	str	w0, [x22, 240]
	mov	w0, 4
	ldr	x1, .LC169
	ldr	w2, [x22, 240]
	bl	dprint_vfmw
	ldr	w0, [x19, 244]
	str	w0, [x22, 244]
	mov	w0, 4
	ldr	x1, .LC171
	ldr	w2, [x22, 244]
	bl	dprint_vfmw
	ldr	w0, [x19, 248]
	str	w0, [x22, 248]
	mov	w0, 4
	ldr	x1, .LC173
	ldr	w2, [x22, 248]
	bl	dprint_vfmw
	ldr	w0, [x20, 76]
	str	w0, [x22, 252]
	mov	w0, 4
	ldr	x1, .LC175
	ldr	w2, [x22, 252]
	bl	dprint_vfmw
	ldr	w0, [x21, 2520]
	mov	x1, x27
	add	w0, w0, 255
	and	w0, w0, -256
	cmp	w0, wzr
	add	w2, w0, 3
	csel	w0, w2, w0, lt
	asr	w0, w0, 2
	lsl	w0, w0, 4
	str	w0, [x22, 256]
	mov	w0, 4
	ldr	w2, [x22, 256]
	bl	dprint_vfmw
	ldr	w0, [x21, 2468]
	ldr	w2, [x21, 2520]
	ldr	w5, [x21, 2532]
	cmp	w0, 1
	add	w0, w2, 255
	add	w6, w5, 63
	and	w0, w0, -256
	and	w1, w6, -64
	mul	w0, w0, w1
	lsl	w1, w0, 2
	sub	w0, w1, w0
	asr	w0, w0, 1
	beq	.L31
.L26:
	str	w0, [x22, 260]
	mov	x1, x26
	mov	w0, 4
	ldr	w2, [x22, 260]
	bl	dprint_vfmw
	ldr	w0, [x21, 2520]
	mov	x1, x25
	add	w0, w0, 255
	and	w2, w0, -256
	ldr	w0, [x21, 2532]
	add	w0, w0, 63
	and	w0, w0, -64
	mul	w0, w2, w0
	cmp	w0, wzr
	add	w2, w0, 3
	csel	w0, w2, w0, lt
	asr	w0, w0, 2
	str	w0, [x22, 264]
	mov	w0, 4
	ldr	w2, [x22, 264]
	bl	dprint_vfmw
	ldr	w0, [x21, 2524]
	mov	x1, x24
	add	w0, w0, 255
	and	w0, w0, -256
	cmp	w0, wzr
	add	w2, w0, 3
	csel	w0, w2, w0, lt
	asr	w0, w0, 2
	lsl	w0, w0, 4
	str	w0, [x22, 268]
	mov	w0, 4
	ldr	w2, [x22, 268]
	bl	dprint_vfmw
	ldr	w0, [x21, 2524]
	add	w0, w0, 255
	and	w1, w0, -256
	ldr	w0, [x21, 2536]
	add	w0, w0, 63
	and	w0, w0, -64
	mul	w0, w1, w0
	ldr	w1, [x21, 2468]
	cmp	w1, 1
	lsl	w1, w0, 2
	sub	w0, w1, w0
	asr	w0, w0, 1
	beq	.L32
.L27:
	str	w0, [x22, 272]
	mov	x1, x23
	mov	w0, 4
	ldr	w2, [x22, 272]
	bl	dprint_vfmw
	ldr	w2, [x21, 2524]
	ldr	w0, [x21, 2536]
	add	w2, w2, 255
	ldr	x1, .LC60
	add	w0, w0, 63
	and	w2, w2, -256
	and	w0, w0, -64
	mul	w0, w2, w0
	cmp	w0, wzr
	add	w2, w0, 3
	csel	w2, w2, w0, lt
	mov	w0, 4
	asr	w2, w2, 2
	str	w2, [x22, 276]
	ldr	w2, [x22, 276]
	bl	dprint_vfmw
	ldr	w2, [x21, 2528]
	mov	w0, 4
	ldr	x1, .LC62
	add	w2, w2, 255
	and	w2, w2, -256
	cmp	w2, wzr
	add	w5, w2, 3
	csel	w2, w5, w2, lt
	asr	w2, w2, 2
	lsl	w2, w2, 4
	str	w2, [x22, 280]
	ldr	w2, [x22, 280]
	bl	dprint_vfmw
	ldr	w1, [x21, 2528]
	ldr	w0, [x21, 2540]
	add	w1, w1, 255
	ldr	w2, [x21, 2468]
	add	w0, w0, 63
	and	w1, w1, -256
	and	w0, w0, -64
	cmp	w2, 1
	mul	w0, w1, w0
	lsl	w1, w0, 2
	sub	w0, w1, w0
	asr	w0, w0, 1
	beq	.L33
.L28:
	str	w0, [x22, 284]
	mov	w0, 4
	ldr	x1, .LC64
	ldr	w2, [x22, 284]
	bl	dprint_vfmw
	ldr	w5, [x21, 2528]
	mov	w0, 4
	ldr	w2, [x21, 2540]
	add	w5, w5, 255
	ldr	x1, .LC66
	add	w2, w2, 63
	and	w5, w5, -256
	and	w2, w2, -64
	mul	w2, w5, w2
	cmp	w2, wzr
	add	w5, w2, 3
	csel	w2, w5, w2, lt
	asr	w2, w2, 2
	str	w2, [x22, 288]
	ldr	w2, [x22, 288]
	bl	dprint_vfmw
	ldr	x0, [x29, 104]
	mov	w2, 4608
	ldr	w1, [x21, 2352]
	ldr	x3, [x28, 280]
	blr	x3
	mov	w0, 0
.L24:
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x25, x26, [sp, 64]
	ldp	x27, x28, [sp, 80]
	ldp	x29, x30, [sp], 112
	ret
	.p2align 3
.L31:
	adds	w1, w2, 2047
	add	w2, w2, 4094
	csel	w2, w2, w1, mi
	add	w5, w5, 126
	and	w2, w2, -2048
	cmp	w2, wzr
	add	w1, w2, 127
	csel	w2, w1, w2, lt
	cmp	w6, wzr
	csel	w5, w5, w6, lt
	asr	w1, w2, 7
	asr	w5, w5, 6
	lsl	w2, w5, 2
	sub	w2, w2, w5
	lsl	w2, w2, 5
	mul	w2, w1, w2
	add	w0, w0, w2, lsr 1
	b	.L26
	.p2align 3
.L33:
	ldr	w2, [x21, 2520]
	ldr	w5, [x21, 2532]
	adds	w1, w2, 2047
	add	w2, w2, 4094
	csel	w1, w2, w1, mi
	and	w1, w1, -2048
	cmp	w1, wzr
	add	w2, w1, 127
	csel	w1, w2, w1, lt
	add	w2, w5, 126
	adds	w5, w5, 63
	csel	w5, w2, w5, mi
	asr	w2, w1, 7
	asr	w1, w5, 6
	lsl	w5, w1, 2
	sub	w1, w5, w1
	lsl	w1, w1, 5
	mul	w1, w2, w1
	add	w0, w0, w1, lsr 1
	b	.L28
	.p2align 3
.L32:
	ldr	w2, [x21, 2520]
	ldr	w6, [x21, 2532]
	adds	w1, w2, 2047
	add	w2, w2, 4094
	csel	w1, w2, w1, mi
	add	w5, w6, 126
	and	w1, w1, -2048
	cmp	w1, wzr
	add	w2, w1, 127
	csel	w1, w2, w1, lt
	asr	w2, w1, 7
	adds	w1, w6, 63
	csel	w1, w5, w1, mi
	asr	w1, w1, 6
	lsl	w5, w1, 2
	sub	w1, w5, w1
	lsl	w1, w1, 5
	mul	w1, w2, w1
	add	w0, w0, w1, lsr 1
	b	.L27
.L29:
	ldr	x2, .LC46
	mov	w0, 0
	ldr	x3, .LC45
	ldr	x1, .LC48
	add	x2, x2, 24
	bl	dprint_vfmw
	mov	w0, -1
	b	.L24
.L30:
	ldr	x2, .LC46
	mov	w0, 0
	ldr	x1, .LC128
	add	x2, x2, 24
	bl	dprint_vfmw
	mov	w0, -1
	b	.L24
	.size	VP9HAL_V5R2C1_CfgFrameMsg, .-VP9HAL_V5R2C1_CfgFrameMsg
	.align	3
.LC45:
	.xword	.LC44
	.align	3
.LC46:
	.xword	.LANCHOR0
	.align	3
.LC48:
	.xword	.LC47
	.align	3
.LC50:
	.xword	.LC49
	.align	3
.LC52:
	.xword	.LC51
	.align	3
.LC54:
	.xword	.LC53
	.align	3
.LC56:
	.xword	.LC55
	.align	3
.LC58:
	.xword	.LC57
	.align	3
.LC60:
	.xword	.LC59
	.align	3
.LC62:
	.xword	.LC61
	.align	3
.LC64:
	.xword	.LC63
	.align	3
.LC66:
	.xword	.LC65
	.align	3
.LC68:
	.xword	.LC67
	.align	3
.LC70:
	.xword	.LC69
	.align	3
.LC72:
	.xword	.LC71
	.align	3
.LC74:
	.xword	.LC73
	.align	3
.LC76:
	.xword	.LC75
	.align	3
.LC78:
	.xword	.LC77
	.align	3
.LC80:
	.xword	.LC79
	.align	3
.LC82:
	.xword	.LC81
	.align	3
.LC84:
	.xword	.LC83
	.align	3
.LC86:
	.xword	.LC85
	.align	3
.LC88:
	.xword	.LC87
	.align	3
.LC90:
	.xword	.LC89
	.align	3
.LC92:
	.xword	.LC91
	.align	3
.LC94:
	.xword	.LC93
	.align	3
.LC96:
	.xword	.LC95
	.align	3
.LC98:
	.xword	.LC97
	.align	3
.LC100:
	.xword	.LC99
	.align	3
.LC102:
	.xword	.LC101
	.align	3
.LC104:
	.xword	.LC103
	.align	3
.LC106:
	.xword	.LC105
	.align	3
.LC108:
	.xword	.LC107
	.align	3
.LC110:
	.xword	.LC109
	.align	3
.LC112:
	.xword	.LC111
	.align	3
.LC114:
	.xword	.LC113
	.align	3
.LC116:
	.xword	.LC115
	.align	3
.LC118:
	.xword	.LC117
	.align	3
.LC120:
	.xword	.LC119
	.align	3
.LC122:
	.xword	.LC121
	.align	3
.LC124:
	.xword	.LC123
	.align	3
.LC126:
	.xword	.LC125
	.align	3
.LC128:
	.xword	.LC127
	.align	3
.LC129:
	.xword	vfmw_Osal_Func_Ptr_S
	.align	3
.LC131:
	.xword	.LC130
	.align	3
.LC133:
	.xword	.LC132
	.align	3
.LC135:
	.xword	.LC134
	.align	3
.LC137:
	.xword	.LC136
	.align	3
.LC139:
	.xword	.LC138
	.align	3
.LC141:
	.xword	.LC140
	.align	3
.LC143:
	.xword	.LC142
	.align	3
.LC145:
	.xword	.LC144
	.align	3
.LC147:
	.xword	.LC146
	.align	3
.LC149:
	.xword	.LC148
	.align	3
.LC151:
	.xword	.LC150
	.align	3
.LC153:
	.xword	.LC152
	.align	3
.LC155:
	.xword	.LC154
	.align	3
.LC157:
	.xword	.LC156
	.align	3
.LC159:
	.xword	.LC158
	.align	3
.LC161:
	.xword	.LC160
	.align	3
.LC163:
	.xword	.LC162
	.align	3
.LC165:
	.xword	.LC164
	.align	3
.LC167:
	.xword	.LC166
	.align	3
.LC169:
	.xword	.LC168
	.align	3
.LC171:
	.xword	.LC170
	.align	3
.LC173:
	.xword	.LC172
	.align	3
.LC175:
	.xword	.LC174
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	VP9HAL_V5R2C1_CfgTileMsg
	.type	VP9HAL_V5R2C1_CfgTileMsg, %function
VP9HAL_V5R2C1_CfgTileMsg:
	stp	x29, x30, [sp, -96]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	stp	x21, x22, [sp, 32]
	stp	x23, x24, [sp, 48]
	stp	x25, x26, [sp, 64]
	stp	x27, x28, [sp, 80]
	mov	x19, x1
	mov	x20, x0
	mov	x0, x30
	bl	_mcount
	ldr	w19, [x19, 76]
	mov	w0, w19
	bl	MEM_Phy2Vir
	mov	x22, x0
	cbz	x0, .L43
	add	x21, x20, 262144
	ldr	w2, [x21, 1024]
	sub	w0, w2, #1
	cmp	w0, 1023
	bhi	.L44
.L37:
	cbz	w2, .L40
	ldr	x28, .LC182
	mov	w24, w19
	ldr	x27, .LC184
	mov	w23, 0
	ldr	x26, .LC186
	.p2align 2
.L38:
	sxtw	x3, w23
	mov	x1, x28
	lsl	x2, x3, 8
	mov	w0, 4
	add	x5, x20, x3, lsl 8
	add	x19, x22, x2
	add	x25, x20, x2
	ldr	w5, [x5, 1024]
	str	w5, [x22, x2]
	ldr	w2, [x22, x2]
	bl	dprint_vfmw
	ldr	w0, [x25, 1028]
	mov	x1, x27
	str	w0, [x19, 4]
	mov	w0, 4
	ldr	w2, [x19, 4]
	bl	dprint_vfmw
	ldr	w0, [x25, 1032]
	mov	x1, x26
	str	w0, [x19, 8]
	mov	w0, 4
	ldr	w2, [x19, 8]
	bl	dprint_vfmw
	ldr	w0, [x25, 1036]
	str	w0, [x19, 12]
	mov	w0, 4
	ldr	x1, .LC188
	ldr	w2, [x19, 12]
	bl	dprint_vfmw
	ldr	w0, [x25, 1040]
	str	w0, [x19, 16]
	mov	w0, 4
	ldr	x1, .LC190
	ldr	w2, [x19, 16]
	bl	dprint_vfmw
	ldr	w0, [x25, 1044]
	str	w0, [x19, 20]
	mov	w0, 4
	ldr	x1, .LC192
	ldr	w2, [x19, 20]
	bl	dprint_vfmw
	ldr	w0, [x25, 1048]
	str	w0, [x19, 24]
	mov	w0, 4
	ldr	x1, .LC194
	ldr	w2, [x19, 24]
	bl	dprint_vfmw
	ldr	w0, [x25, 1052]
	str	w0, [x19, 28]
	mov	w0, 4
	ldr	x1, .LC196
	ldr	w2, [x19, 28]
	bl	dprint_vfmw
	ldr	w0, [x25, 1056]
	str	w0, [x19, 32]
	mov	w0, 4
	ldr	x1, .LC198
	ldr	w2, [x19, 32]
	bl	dprint_vfmw
	ldr	w0, [x25, 1060]
	str	w0, [x19, 36]
	mov	w0, 4
	ldr	x1, .LC200
	ldr	w2, [x19, 36]
	bl	dprint_vfmw
	ldr	w0, [x25, 1064]
	str	w0, [x19, 40]
	mov	w0, 4
	ldr	x1, .LC202
	ldr	w2, [x19, 40]
	bl	dprint_vfmw
	ldr	w0, [x25, 1068]
	str	w0, [x19, 44]
	mov	w0, 4
	ldr	x1, .LC204
	ldr	w2, [x19, 44]
	bl	dprint_vfmw
	ldr	w0, [x25, 1276]
	str	w0, [x19, 252]
	mov	w0, 4
	ldr	x1, .LC206
	ldr	w2, [x19, 252]
	bl	dprint_vfmw
	cmp	w23, wzr
	add	w23, w23, 1
	ble	.L39
	str	w24, [x19, -4]
.L39:
	ldr	w0, [x21, 1024]
	add	w24, w24, 256
	cmp	w0, w23
	bhi	.L38
	cmp	w0, 1
	bls	.L40
	ubfiz	x1, x0, 8, 26
	mov	w0, 0
	add	x6, x22, x1
	str	wzr, [x6, -4]
.L36:
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x25, x26, [sp, 64]
	ldp	x27, x28, [sp, 80]
	ldp	x29, x30, [sp], 96
	ret
	.p2align 3
.L44:
	ldr	x1, .LC180
	mov	w0, 0
	bl	dprint_vfmw
	ldr	w2, [x21, 1024]
	b	.L37
	.p2align 3
.L40:
	mov	w0, 0
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x25, x26, [sp, 64]
	ldp	x27, x28, [sp, 80]
	ldp	x29, x30, [sp], 96
	ret
.L43:
	ldr	x2, .LC177
	mov	w0, 0
	ldr	x3, .LC176
	ldr	x1, .LC178
	add	x2, x2, 56
	bl	dprint_vfmw
	mov	w0, -1
	b	.L36
	.size	VP9HAL_V5R2C1_CfgTileMsg, .-VP9HAL_V5R2C1_CfgTileMsg
	.align	3
.LC176:
	.xword	.LC44
	.align	3
.LC177:
	.xword	.LANCHOR0
	.align	3
.LC178:
	.xword	.LC47
	.align	3
.LC180:
	.xword	.LC179
	.align	3
.LC182:
	.xword	.LC181
	.align	3
.LC184:
	.xword	.LC183
	.align	3
.LC186:
	.xword	.LC185
	.align	3
.LC188:
	.xword	.LC187
	.align	3
.LC190:
	.xword	.LC189
	.align	3
.LC192:
	.xword	.LC191
	.align	3
.LC194:
	.xword	.LC193
	.align	3
.LC196:
	.xword	.LC195
	.align	3
.LC198:
	.xword	.LC197
	.align	3
.LC200:
	.xword	.LC199
	.align	3
.LC202:
	.xword	.LC201
	.align	3
.LC204:
	.xword	.LC203
	.align	3
.LC206:
	.xword	.LC205
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	VP9HAL_V5R2C1_CalcSize
	.type	VP9HAL_V5R2C1_CalcSize, %function
VP9HAL_V5R2C1_CalcSize:
	stp	x29, x30, [sp, -64]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	stp	x21, x22, [sp, 32]
	stp	x23, x24, [sp, 48]
	mov	x19, x0
	mov	x0, x30
	add	x19, x19, 270336
	bl	_mcount
	ldr	w23, [x19, 2472]
	ldr	w1, [x19, 2480]
	mov	w0, w23
	ldr	w21, [x19, 2088]
	ldr	w20, [x19, 2092]
	ldr	w24, [x19, 2468]
	bl	GetCompressRatio
	ldr	w1, [x19, 2484]
	mov	w22, w0
	mov	w0, w23
	lsl	w21, w21, 6
	lsl	w20, w20, 6
	bl	GetCompressRatio
	add	w1, w21, 255
	and	w3, w1, -256
	lsl	w2, w3, 4
	mul	w1, w22, w2
	asr	w2, w2, 1
	cmp	w1, wzr
	mul	w0, w2, w0
	add	w2, w1, 7
	csel	w1, w2, w1, lt
	add	w4, w0, 7
	cmp	w0, wzr
	asr	w1, w1, 3
	csel	w0, w4, w0, lt
	add	w2, w20, 63
	asr	w4, w0, 3
	and	w5, w2, -64
	lsr	w0, w1, 4
	cmp	w24, 1
	ccmp	w23, wzr, 0, eq
	str	w1, [x19, 2096]
	mul	w0, w0, w5
	str	w4, [x19, 2104]
	str	w0, [x19, 2108]
	beq	.L48
	str	wzr, [x19, 2500]
	str	wzr, [x19, 2504]
.L47:
	add	w2, w3, 3
	cmp	w3, wzr
	csel	w1, w2, w3, lt
	lsl	w2, w0, 2
	asr	w1, w1, 2
	sub	w0, w2, w0
	lsl	w1, w1, 4
	lsr	w0, w0, 1
	lsr	w2, w1, 4
	str	w0, [x19, 2512]
	str	w1, [x19, 2508]
	mul	w0, w2, w5
	str	w0, [x19, 2516]
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x29, x30, [sp], 64
	ret
	.p2align 3
.L48:
	adds	w1, w21, 2047
	add	w21, w21, 4094
	csel	w21, w21, w1, mi
	add	w20, w20, 126
	and	w21, w21, -2048
	cmp	w21, wzr
	add	w1, w21, 127
	csel	w21, w1, w21, lt
	cmp	w2, wzr
	csel	w2, w20, w2, lt
	asr	w21, w21, 7
	asr	w2, w2, 6
	str	w21, [x19, 2500]
	lsl	w2, w2, 5
	mul	w2, w2, w21
	str	w2, [x19, 2504]
	add	w0, w0, w2
	str	w0, [x19, 2108]
	b	.L47
	.size	VP9HAL_V5R2C1_CalcSize, .-VP9HAL_V5R2C1_CalcSize
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	VP9HAL_V5R2C1_StartDec
	.type	VP9HAL_V5R2C1_StartDec, %function
VP9HAL_V5R2C1_StartDec:
	stp	x29, x30, [sp, -64]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	stp	x21, x22, [sp, 32]
	stp	x23, x24, [sp, 48]
	mov	x21, x0
	mov	x0, x30
	mov	w20, w1
	mov	x23, x2
	bl	_mcount
	ldr	x24, .LC207
	sxtw	x0, w20
	cmp	w20, wzr
	lsl	x19, x0, 6
	sub	x19, x19, x0
	lsl	x19, x19, 2
	sub	x0, x19, x0
	add	x19, x19, x0, lsl 2
	add	x22, x19, x24
	bgt	.L56
	add	x0, x21, 270336
	ldr	w1, [x0, 2088]
	cmp	w1, 512
	bhi	.L53
	ldr	w0, [x0, 2092]
	cmp	w0, 512
	bhi	.L53
	ldr	x0, [x19, x24]
	cbz	x0, .L57
.L54:
	mov	x0, x21
	bl	VP9HAL_V5R2C1_CalcSize
	mov	x3, x23
	mov	w2, w20
	mov	x1, x22
	mov	x0, x21
	bl	VP9HAL_V5R2C1_CfgReg
	mov	w2, w20
	mov	x1, x22
	mov	x0, x21
	bl	VP9HAL_V5R2C1_CfgFrameMsg
	mov	w2, w20
	mov	x1, x22
	mov	x0, x21
	bl	VP9HAL_V5R2C1_CfgTileMsg
	mov	w0, 0
.L51:
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x29, x30, [sp], 64
	ret
	.p2align 3
.L57:
	mov	w0, -121438208
	bl	MEM_Phy2Vir
	cbz	x0, .L55
	str	x0, [x19, x24]
	b	.L54
	.p2align 3
.L56:
	ldr	x2, .LC208
	mov	w4, 0
	ldr	x1, .LC209
	mov	w3, w20
	add	x2, x2, 88
	mov	w0, 0
	bl	dprint_vfmw
	mov	w0, -1
	b	.L51
	.p2align 3
.L53:
	ldr	x2, .LC208
	mov	w0, 0
	ldr	x3, .LC211
	ldr	x1, .LC212
	add	x2, x2, 88
	bl	dprint_vfmw
	mov	w0, -1
	b	.L51
.L55:
	ldr	x1, .LC213
	mov	w0, 0
	bl	dprint_vfmw
	mov	w0, -1
	b	.L51
	.size	VP9HAL_V5R2C1_StartDec, .-VP9HAL_V5R2C1_StartDec
	.align	3
.LC207:
	.xword	g_HwMem
	.align	3
.LC208:
	.xword	.LANCHOR0
	.align	3
.LC209:
	.xword	.LC6
	.align	3
.LC211:
	.xword	.LC210
	.align	3
.LC212:
	.xword	.LC47
	.align	3
.LC213:
	.xword	.LC8
	.section	.rodata
	.align	3
.LANCHOR0 = . + 0
	.type	__func__.11340, %object
	.size	__func__.11340, 21
__func__.11340:
	.string	"VP9HAL_V5R2C1_CfgReg"
	.zero	3
	.type	__func__.11353, %object
	.size	__func__.11353, 26
__func__.11353:
	.string	"VP9HAL_V5R2C1_CfgFrameMsg"
	.zero	6
	.type	__func__.11364, %object
	.size	__func__.11364, 25
__func__.11364:
	.string	"VP9HAL_V5R2C1_CfgTileMsg"
	.zero	7
	.type	__func__.11385, %object
	.size	__func__.11385, 23
__func__.11385:
	.string	"VP9HAL_V5R2C1_StartDec"
	.section	.rodata.str1.8,"aMS",%progbits,1
	.align	3
.LC3:
	ASCII(.string	"%s: pMfdeTask(%p) = NULL\n" )
	.zero	6
.LC6:
	ASCII(.string	"%s: VdhId(%d) > %d\n" )
	.zero	4
.LC8:
	ASCII(.string	"vdm register virtual address not mapped, reset failed!\n" )
.LC10:
	ASCII(.string	"BASIC_CFG0 = 0x%x\n" )
	.zero	5
.LC12:
	ASCII(.string	"BASIC_CFG1 = 0x%x\n" )
	.zero	5
.LC14:
	ASCII(.string	"AVM_ADDR = 0x%x\n" )
	.zero	7
.LC16:
	ASCII(.string	"VAM_ADDR = 0x%x\n" )
	.zero	7
.LC18:
	ASCII(.string	"STREAM_BASE_ADDR = 0x%x\n" )
	.zero	7
.LC20:
	ASCII(.string	"PPFD_BUF_ADDR = 0x%x\n" )
	.zero	2
.LC22:
	ASCII(.string	"PPFD_BUF_LEN = 0x%x\n" )
	.zero	3
.LC24:
	ASCII(.string	"FF_APT_EN = 0x%x\n" )
	.zero	6
.LC26:
	ASCII(.string	"DEC_OVER_INT_LEVEL=0x%x\n" )
	.zero	7
.LC28:
	ASCII(.string	"YSTADDR_1D = 0x%x\n" )
	.zero	5
.LC30:
	ASCII(.string	"YSTRIDE_1D = 0x%x\n" )
	.zero	5
.LC32:
	ASCII(.string	"UVOFFSET_1D = 0x%x\n" )
	.zero	4
.LC34:
	ASCII(.string	"HEAD_INF_OFFSET = 0x%x\n" )
.LC36:
	ASCII(.string	"HEVC_VFMW_YSTRIDE_2BIT = 0x%x\n" )
	.zero	1
.LC38:
	ASCII(.string	"HEVC_VFMW_YOFFSET_2BIT = 0x%x\n" )
	.zero	1
.LC40:
	ASCII(.string	"HEVC_VFMW_UVOFFSET_2BIT = 0x%x\n" )
.LC42:
	ASCII(.string	"VREG_LINE_NUM_STADDR = 0x%x\n" )
	.zero	3
.LC44:
	ASCII(.string	"can not map down msg virtual address!\n" )
	.zero	1
.LC47:
	ASCII(.string	"%s: %s\n" )
.LC49:
	ASCII(.string	"PicMsg D[0] = 0x%x\n" )
	.zero	4
.LC51:
	ASCII(.string	"PicMsg D[1] = 0x%x\n" )
	.zero	4
.LC53:
	ASCII(.string	"PicMsg D[2] = 0x%x\n" )
	.zero	4
.LC55:
	ASCII(.string	"PicMsg D[3] = 0x%x\n" )
	.zero	4
.LC57:
	ASCII(.string	"PicMsg D[4] = 0x%x\n" )
	.zero	4
.LC59:
	ASCII(.string	"PicMsg D[5] = 0x%x\n" )
	.zero	4
.LC61:
	ASCII(.string	"PicMsg D[6] = 0x%x\n" )
	.zero	4
.LC63:
	ASCII(.string	"PicMsg D[7] = 0x%x\n" )
	.zero	4
.LC65:
	ASCII(.string	"PicMsg D[8] = 0x%x\n" )
	.zero	4
.LC67:
	ASCII(.string	"PicMsg D[9] = 0x%x\n" )
	.zero	4
.LC69:
	ASCII(.string	"PicMsg D[10] = 0x%x\n" )
	.zero	3
.LC71:
	ASCII(.string	"PicMsg D[11] = 0x%x\n" )
	.zero	3
.LC73:
	ASCII(.string	"PicMsg D[12] = 0x%x\n" )
	.zero	3
.LC75:
	ASCII(.string	"PicMsg D[13] = 0x%x\n" )
	.zero	3
.LC77:
	ASCII(.string	"PicMsg D[14] = 0x%x\n" )
	.zero	3
.LC79:
	ASCII(.string	"PicMsg D[15] = 0x%x\n" )
	.zero	3
.LC81:
	ASCII(.string	"PicMsg D[16] = 0x%x\n" )
	.zero	3
.LC83:
	ASCII(.string	"PicMsg D[17] = 0x%x\n" )
	.zero	3
.LC85:
	ASCII(.string	"PicMsg D[18] = 0x%x\n" )
	.zero	3
.LC87:
	ASCII(.string	"PicMsg D[19] = 0x%x\n" )
	.zero	3
.LC89:
	ASCII(.string	"PicMsg D[20] = 0x%x\n" )
	.zero	3
.LC91:
	ASCII(.string	"PicMsg D[21] = 0x%x\n" )
	.zero	3
.LC93:
	ASCII(.string	"PicMsg D[22] = 0x%x\n" )
	.zero	3
.LC95:
	ASCII(.string	"PicMsg D[23] = 0x%x\n" )
	.zero	3
.LC97:
	ASCII(.string	"PicMsg D[24] = 0x%x\n" )
	.zero	3
.LC99:
	ASCII(.string	"PicMsg D[25] = 0x%x\n" )
	.zero	3
.LC101:
	ASCII(.string	"PicMsg D[26] = 0x%x\n" )
	.zero	3
.LC103:
	ASCII(.string	"PicMsg D[27] = 0x%x\n" )
	.zero	3
.LC105:
	ASCII(.string	"PicMsg D[28] = 0x%x\n" )
	.zero	3
.LC107:
	ASCII(.string	"PicMsg D[29] = 0x%x\n" )
	.zero	3
.LC109:
	ASCII(.string	"PicMsg D[30] = 0x%x\n" )
	.zero	3
.LC111:
	ASCII(.string	"PicMsg D[32] = 0x%x\n" )
	.zero	3
.LC113:
	ASCII(.string	"PicMsg D[33] = 0x%x\n" )
	.zero	3
.LC115:
	ASCII(.string	"PicMsg D[34] = 0x%x\n" )
	.zero	3
.LC117:
	ASCII(.string	"PicMsg D[35] = 0x%x\n" )
	.zero	3
.LC119:
	ASCII(.string	"PicMsg D[36] = 0x%x\n" )
	.zero	3
.LC121:
	ASCII(.string	"PicMsg D[37] = 0x%x\n" )
	.zero	3
.LC123:
	ASCII(.string	"PicMsg D[38] = 0x%x\n" )
	.zero	3
.LC125:
	ASCII(.string	"PicMsg D[39] = 0x%x\n" )
	.zero	3
.LC127:
	ASCII(.string	"%s: pu8Vir = NULL\n" )
	.zero	5
.LC130:
	ASCII(.string	"PicMsg D[40] = 0x%x\n" )
	.zero	3
.LC132:
	ASCII(.string	"PicMsg D[41] = 0x%x\n" )
	.zero	3
.LC134:
	ASCII(.string	"PicMsg D[42] = 0x%x\n" )
	.zero	3
.LC136:
	ASCII(.string	"PicMsg D[43] = 0x%x\n" )
	.zero	3
.LC138:
	ASCII(.string	"PicMsg D[45] = 0x%x\n" )
	.zero	3
.LC140:
	ASCII(.string	"PicMsg D[46] = 0x%x\n" )
	.zero	3
.LC142:
	ASCII(.string	"PicMsg D[47] = 0x%x\n" )
	.zero	3
.LC144:
	ASCII(.string	"PicMsg D[48] = 0x%x\n" )
	.zero	3
.LC146:
	ASCII(.string	"PicMsg D[49] = 0x%x\n" )
	.zero	3
.LC148:
	ASCII(.string	"PicMsg D[50] = 0x%x\n" )
	.zero	3
.LC150:
	ASCII(.string	"PicMsg D[51] = 0x%x\n" )
	.zero	3
.LC152:
	ASCII(.string	"PicMsg D[52] = 0x%x\n" )
	.zero	3
.LC154:
	ASCII(.string	"PicMsg D[53] = 0x%x\n" )
	.zero	3
.LC156:
	ASCII(.string	"PicMsg D[54] = 0x%x\n" )
	.zero	3
.LC158:
	ASCII(.string	"PicMsg D[55] = 0x%x\n" )
	.zero	3
.LC160:
	ASCII(.string	"PicMsg D[56] = 0x%x\n" )
	.zero	3
.LC162:
	ASCII(.string	"PicMsg D[57] = 0x%x\n" )
	.zero	3
.LC164:
	ASCII(.string	"PicMsg D[58] = 0x%x\n" )
	.zero	3
.LC166:
	ASCII(.string	"PicMsg D[59] = 0x%x\n" )
	.zero	3
.LC168:
	ASCII(.string	"PicMsg D[60] = 0x%x\n" )
	.zero	3
.LC170:
	ASCII(.string	"PicMsg D[61] = 0x%x\n" )
	.zero	3
.LC172:
	ASCII(.string	"PicMsg D[62] = 0x%x\n" )
	.zero	3
.LC174:
	ASCII(.string	"PicMsg D[63] = 0x%x\n" )
	.zero	3
.LC179:
	ASCII(.string	"ERROR: pVp9DecParam->TotalTileNum(%d) out of [0-1024]\n" )
	.zero	1
.LC181:
	ASCII(.string	"TileMsg D[0] = 0x%x\n" )
	.zero	3
.LC183:
	ASCII(.string	"TileMsg D[1] = 0x%x\n" )
	.zero	3
.LC185:
	ASCII(.string	"TileMsg D[2] = 0x%x\n" )
	.zero	3
.LC187:
	ASCII(.string	"TileMsg D[3] = 0x%x\n" )
	.zero	3
.LC189:
	ASCII(.string	"TileMsg D[4] = 0x%x\n" )
	.zero	3
.LC191:
	ASCII(.string	"TileMsg D[5] = 0x%x\n" )
	.zero	3
.LC193:
	ASCII(.string	"TileMsg D[6] = 0x%x\n" )
	.zero	3
.LC195:
	ASCII(.string	"TileMsg D[7] = 0x%x\n" )
	.zero	3
.LC197:
	ASCII(.string	"TileMsg D[8] = 0x%x\n" )
	.zero	3
.LC199:
	ASCII(.string	"TileMsg D[9] = 0x%x\n" )
	.zero	3
.LC201:
	ASCII(.string	"TileMsg D[10] = 0x%x\n" )
	.zero	2
.LC203:
	ASCII(.string	"TileMsg D[11] = 0x%x\n" )
	.zero	2
.LC205:
	ASCII(.string	"TileMsg D[63] = 0x%x\n" )
	.zero	2
.LC210:
	ASCII(.string	"picture width out of range" )
	.ident	"GCC: (gcc-linaro-5.1-2015.08 + glibc-2.22 (Build by czyong Wed Mar  9 18:57:48 CST 2016)) 5.1.1 20150608"
	.section	.note.GNU-stack,"",%progbits
