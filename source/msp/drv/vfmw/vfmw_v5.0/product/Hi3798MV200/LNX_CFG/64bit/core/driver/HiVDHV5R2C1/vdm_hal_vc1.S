#include "hi_asm_define.h"
	.arch armv8-a+fp+simd
	.file	"vdm_hal_vc1.c"
	.global	_mcount
	.text
	.align	2
	.p2align 3,,7
	.global	VC1HAL_V5R2C1_InitHal
	.type	VC1HAL_V5R2C1_InitHal, %function
VC1HAL_V5R2C1_InitHal:
	stp	x29, x30, [sp, -16]!
	add	x29, sp, 0
	mov	x0, x30
	bl	_mcount
	mov	w0, 0
	ldp	x29, x30, [sp], 16
	ret
	.size	VC1HAL_V5R2C1_InitHal, .-VC1HAL_V5R2C1_InitHal
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	VC1HAL_V5R2C1_CfgSliceMsg
	.type	VC1HAL_V5R2C1_CfgSliceMsg, %function
VC1HAL_V5R2C1_CfgSliceMsg:
	stp	x29, x30, [sp, -128]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	stp	x21, x22, [sp, 32]
	stp	x23, x24, [sp, 48]
	stp	x25, x26, [sp, 64]
	stp	x27, x28, [sp, 80]
	mov	x19, x1
	mov	x21, x0
	mov	x0, x30
	bl	_mcount
	ldr	w23, [x19, 76]
	mov	w0, w23
	bl	MEM_Phy2Vir
	mov	x19, x0
	cbz	x0, .L61
	ldrb	w0, [x21, 4]
	cmp	w0, 2
	beq	.L62
	ldr	w5, [x21, 108]
	add	x20, x21, 88
	ldrb	w4, [x21, 74]
	and	w11, w5, -16
	str	w11, [x21, 14512]
	cbz	w4, .L2
	mov	w10, 0
	mov	w8, 0
	mov	w3, 0
	mov	x7, 0
	cbnz	w10, .L26
	.p2align 2
.L63:
	cmp	w4, 1
	ldr	w8, [x20, 32]
	beq	.L59
	ble	.L28
	ldr	w0, [x21, 176]
	add	x1, x21, 232
	mov	w3, 1
	cmp	w8, w0
	bge	.L31
	b	.L28
	.p2align 3
.L32:
	ldr	w2, [x1], 56
	cmp	w8, w2
	blt	.L30
.L31:
	add	w3, w3, 1
	cmp	w3, w4
	bne	.L32
.L59:
	mov	w12, 0
	mov	w4, 0
.L27:
	lsl	x2, x7, 3
	sub	w0, w5, w11
	sub	x2, x2, x7
	lsl	x1, x7, 8
	and	w14, w0, -16
	add	x13, x1, 4
	add	x2, x21, x2, lsl 3
	add	x11, x1, 8
	add	x9, x1, 12
	add	x7, x1, 16
	add	x5, x1, 252
	add	w4, w4, w8, lsl 16
	ldp	w15, w2, [x2, 112]
	add	w10, w10, 1
	add	w0, w15, w0, lsl 3
	add	w0, w2, w0, lsl 25
	str	w0, [x19, x1]
	str	w14, [x19, x13]
	str	wzr, [x19, x11]
	str	wzr, [x19, x9]
	str	w4, [x19, x7]
	str	w12, [x19, x5]
	ldrb	w4, [x21, 74]
	cmp	w4, w10
	ble	.L2
	sxtw	x7, w10
	ldr	w11, [x21, 14512]
	lsl	x1, x7, 3
	sub	x1, x1, x7
	add	x1, x21, x1, lsl 3
	ldr	w5, [x1, 108]
	cbz	w10, .L63
.L26:
	sxtw	x0, w3
	add	w1, w3, 1
	lsl	x2, x0, 3
	cmp	w1, w4
	sub	x2, x2, x0
	add	x2, x20, x2, lsl 3
	ldr	w9, [x2, 32]
	bge	.L33
	ldr	w0, [x2, 88]
	cmp	w9, w0
	bge	.L35
	b	.L33
	.p2align 3
.L36:
	sub	x0, x0, x2
	add	x0, x20, x0, lsl 3
	ldr	w0, [x0, 32]
	cmp	w9, w0
	blt	.L33
.L35:
	add	w1, w1, 1
	cmp	w1, w4
	sxtw	x2, w1
	lsl	x0, x2, 3
	blt	.L36
.L33:
	cmp	w4, w1
	beq	.L47
	add	w12, w23, w1, lsl 8
	mov	w3, w1
.L37:
	add	w4, w8, 1
	mov	w8, w9
	b	.L27
.L28:
	cmp	w4, 1
	beq	.L46
	mov	w3, 1
	.p2align 2
.L30:
	add	w12, w23, w3, lsl 8
	mov	w4, 0
	b	.L27
	.p2align 3
.L47:
	mov	w12, 0
	b	.L37
.L61:
	ldr	x2, .LC3
	mov	w0, 0
	ldr	x1, .LC5
	bl	dprint_vfmw
.L2:
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x25, x26, [sp, 64]
	ldp	x27, x28, [sp, 80]
	ldp	x29, x30, [sp], 128
	ret
.L62:
	ldr	w3, [x21, 108]
	add	x20, x21, 88
	ldrb	w2, [x21, 74]
	str	w3, [x21, 14512]
	cbz	w2, .L6
	sub	w1, w2, #1
	mov	w5, 56
	mov	x4, 152
	add	x0, x21, 96
	umaddl	x4, w1, w5, x4
	add	x4, x21, x4
	.p2align 2
.L9:
	ldr	x1, [x0]
	cbz	x1, .L7
	ldr	w1, [x0, 28]
	cmp	w1, w3
	bcc	.L56
.L7:
	ldr	w1, [x0, 12]
	cmp	w1, w3
	bcs	.L8
.L56:
	mov	w3, w1
	str	w1, [x21, 14512]
.L8:
	add	x0, x0, 56
	cmp	x0, x4
	bne	.L9
.L6:
	ldr	x1, .LC7
	and	w3, w3, -16
	mov	w0, 4
	str	w3, [x21, 14512]
	bl	dprint_vfmw
	ldrb	w14, [x21, 74]
	cbz	w14, .L2
	mov	w26, 0
	mov	w25, 0
	mov	w24, 0
	.p2align 2
.L24:
	sxtw	x22, w24
	ldr	w1, [x21, 14512]
	lsl	x0, x22, 3
	sub	x0, x0, x22
	add	x0, x21, x0, lsl 3
	ldp	w5, w2, [x0, 108]
	ldr	w16, [x0, 116]
	sub	w5, w5, w1
	ubfiz	w3, w5, 3, 4
	and	w27, w5, -16
	add	w2, w3, w2
	ldr	x3, [x0, 96]
	cbz	x3, .L40
	ldp	w9, w8, [x0, 124]
	sub	w28, w9, w1
	ldr	w1, [x0, 132]
	mov	w12, w28
	add	w0, w8, w28, lsl 3
	add	w8, w1, w0, lsl 25
	mov	w11, w8
.L11:
	cbnz	w24, .L12
	cmp	w14, 1
	ldr	w26, [x20, 32]
	beq	.L58
	ble	.L14
	ldr	w0, [x21, 176]
	cmp	w26, w0
	blt	.L57
	add	x0, x21, 232
	mov	w25, 1
	b	.L17
	.p2align 3
.L18:
	ldr	w1, [x0], 56
	cmp	w26, w1
	blt	.L64
.L17:
	add	w25, w25, 1
	cmp	w25, w14
	bne	.L18
.L58:
	mov	w15, 0
	mov	w3, 0
	mov	w14, 0
.L13:
	lsl	x22, x22, 8
	ldr	x1, .LC9
	add	w2, w16, w2, lsl 25
	mov	w0, 4
	stp	w15, w12, [x29, 104]
	str	w2, [x19, x22]
	add	w24, w24, 1
	stp	w14, w3, [x29, 120]
	stp	w11, w8, [x29, 112]
	bl	dprint_vfmw
	add	x0, x22, 4
	ldr	x1, .LC11
	mov	w2, w27
	str	w27, [x19, x0]
	mov	w0, 4
	bl	dprint_vfmw
	add	x0, x22, 8
	ldr	x1, .LC13
	ldp	w11, w8, [x29, 112]
	str	w11, [x19, x0]
	mov	w2, w8
	mov	w0, 4
	bl	dprint_vfmw
	add	x0, x22, 12
	ldr	w12, [x29, 108]
	ldr	x1, .LC15
	mov	w2, w28
	str	w12, [x19, x0]
	mov	w0, 4
	bl	dprint_vfmw
	add	x0, x22, 16
	ldr	w3, [x29, 124]
	ldr	x1, .LC17
	add	x22, x22, 252
	add	w3, w3, w26, lsl 16
	mov	w2, w3
	str	w3, [x19, x0]
	mov	w0, 4
	bl	dprint_vfmw
	ldr	w14, [x29, 120]
	mov	w0, 4
	ldr	w15, [x29, 104]
	ldr	x1, .LC19
	mov	w2, w14
	str	w15, [x19, x22]
	bl	dprint_vfmw
	ldrb	w14, [x21, 74]
	cmp	w14, w24
	bgt	.L24
	b	.L2
	.p2align 3
.L12:
	sxtw	x3, w25
	add	w1, w25, 1
	lsl	x0, x3, 3
	cmp	w1, w14
	sub	x0, x0, x3
	add	x0, x20, x0, lsl 3
	ldr	w13, [x0, 32]
	bge	.L19
	ldr	w0, [x0, 88]
	cmp	w13, w0
	bge	.L21
	b	.L19
	.p2align 3
.L22:
	sub	x0, x0, x3
	add	x0, x20, x0, lsl 3
	ldr	w0, [x0, 32]
	cmp	w13, w0
	blt	.L19
.L21:
	add	w1, w1, 1
	cmp	w1, w14
	sxtw	x3, w1
	lsl	x0, x3, 3
	blt	.L22
.L19:
	cmp	w14, w1
	beq	.L44
	add	w14, w23, w1, lsl 8
	mov	w25, w1
	mov	w15, w14
.L23:
	add	w3, w26, 1
	mov	w26, w13
	b	.L13
.L64:
	lsl	w14, w25, 8
.L39:
	add	w14, w23, w14
	mov	w3, 0
	mov	w15, w14
	b	.L13
.L40:
	mov	w12, 0
	mov	w11, 0
	mov	w8, 0
	mov	w28, 0
	b	.L11
.L44:
	mov	w15, 0
	mov	w14, 0
	b	.L23
.L57:
	mov	w14, 256
	mov	w25, 1
	b	.L39
.L14:
	bne	.L57
	mov	w25, w14
	b	.L58
.L46:
	mov	w3, w4
	b	.L59
	.size	VC1HAL_V5R2C1_CfgSliceMsg, .-VC1HAL_V5R2C1_CfgSliceMsg
	.align	3
.LC3:
	.xword	.LANCHOR0
	.align	3
.LC5:
	.xword	.LC4
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
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	VC1HAL_V5R2C1_CfgReg
	.type	VC1HAL_V5R2C1_CfgReg, %function
VC1HAL_V5R2C1_CfgReg:
	stp	x29, x30, [sp, -64]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	stp	x21, x22, [sp, 32]
	mov	x21, x0
	mov	x0, x30
	mov	w19, w2
	mov	x22, x1
	mov	x20, x3
	bl	_mcount
	cmp	w19, wzr
	str	wzr, [x29, 60]
	bgt	.L72
	ldr	w1, [x21, 14504]
	mov	w4, 1090519040
	mov	x3, x20
	mov	w2, w19
	and	w1, w1, 1048575
	mov	w0, 8
	orr	w1, w1, w4
	bl	MFDE_ConfigReg
	ldrh	w0, [x29, 62]
	mov	w2, 1
	ldr	w4, [x21, 14604]
	ldrb	w1, [x29, 61]
	bfi	w0, w2, 0, 12
	ldrb	w3, [x29, 60]
	bfi	w1, w4, 4, 1
	ldrh	w4, [x21, 82]
	strh	w0, [x29, 62]
	and	w1, w1, -33
	lsr	x0, x0, 8
	bfi	w3, w2, 0, 4
	and	w0, w0, -17
	orr	w1, w1, -64
	strb	w3, [x29, 60]
	cmp	w4, 120
	strb	w1, [x29, 61]
	strb	w0, [x29, 63]
	ble	.L73
	ldr	w5, [x21, 14600]
	mov	w4, 0
	strb	wzr, [x21, 75]
	and	w5, w5, 1
.L69:
	ldrb	w1, [x29, 63]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 12
	bfi	w1, w4, 5, 1
	bfi	w1, w5, 6, 1
	and	w1, w1, 127
	strb	w1, [x29, 63]
	ldr	w1, [x29, 60]
	str	w1, [x21, 14508]
	bl	MFDE_ConfigReg
	ldr	w1, [x22, 72]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 16
	bl	MFDE_ConfigReg
	ldr	w1, [x22, 56]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 20
	bl	MFDE_ConfigReg
	ldr	w4, [x21, 14512]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 24
	mov	w1, w4
	str	w4, [x29, 60]
	bl	MFDE_ConfigReg
	ldrh	w1, [x21, 82]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 4
	cmp	w1, 256
	cset	w1, ls
	bl	SCD_ConfigReg
	mov	w1, 3075
	mov	x3, x20
	mov	w2, w19
	mov	w0, 60
	movk	w1, 0x30, lsl 16
	bl	MFDE_ConfigReg
	mov	w1, 3075
	mov	x3, x20
	mov	w2, w19
	mov	w0, 64
	movk	w1, 0x30, lsl 16
	bl	MFDE_ConfigReg
	mov	w1, 3075
	mov	x3, x20
	mov	w2, w19
	mov	w0, 68
	movk	w1, 0x30, lsl 16
	bl	MFDE_ConfigReg
	mov	w1, 3075
	mov	x3, x20
	mov	w2, w19
	mov	w0, 72
	movk	w1, 0x30, lsl 16
	bl	MFDE_ConfigReg
	mov	w1, 3075
	mov	x3, x20
	mov	w2, w19
	mov	w0, 76
	movk	w1, 0x30, lsl 16
	bl	MFDE_ConfigReg
	mov	w1, 3075
	mov	x3, x20
	mov	w2, w19
	mov	w0, 80
	movk	w1, 0x30, lsl 16
	bl	MFDE_ConfigReg
	mov	w1, 3075
	mov	x3, x20
	mov	w2, w19
	mov	w0, 84
	movk	w1, 0x30, lsl 16
	bl	MFDE_ConfigReg
	ldr	w1, [x21, 14568]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 96
	bl	MFDE_ConfigReg
	ldr	w4, [x21, 14516]
	mov	x3, x20
	str	w4, [x21, 14572]
	mov	w2, w19
	mov	w1, w4
	mov	w0, 100
	bl	MFDE_ConfigReg
	ldr	w1, [x21, 14524]
	mov	x3, x20
	mov	w2, w19
	str	w1, [x21, 14576]
	mov	w0, 104
	bl	MFDE_ConfigReg
	ldrb	w1, [x21, 73]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 152
	bl	MFDE_ConfigReg
	ldrb	w1, [x21, 72]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 148
	bl	MFDE_ConfigReg
	ldr	w1, [x21, 14532]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 108
	bl	MFDE_ConfigReg
	mov	x3, x20
	mov	w2, w19
	mov	w1, -1
	mov	w0, 32
	bl	MFDE_ConfigReg
	mov	w0, 0
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x29, x30, [sp], 64
	ret
	.p2align 3
.L73:
	strb	w2, [x21, 75]
	mov	w5, 0
	mov	w4, w2
	str	wzr, [x21, 14600]
	b	.L69
	.p2align 3
.L72:
	ldr	x2, .LC20
	mov	w3, w19
	ldr	x1, .LC22
	mov	w4, 0
	add	x2, x2, 32
	mov	w0, 0
	bl	dprint_vfmw
	mov	w0, -1
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x29, x30, [sp], 64
	ret
	.size	VC1HAL_V5R2C1_CfgReg, .-VC1HAL_V5R2C1_CfgReg
	.align	3
.LC20:
	.xword	.LANCHOR0
	.align	3
.LC22:
	.xword	.LC21
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	VC1HAL_V5R2C1_CfgDnMsg
	.type	VC1HAL_V5R2C1_CfgDnMsg, %function
VC1HAL_V5R2C1_CfgDnMsg:
	stp	x29, x30, [sp, -48]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	mov	x20, x1
	mov	x19, x0
	mov	x0, x30
	bl	_mcount
	ldr	w0, [x20, 72]
	bl	MEM_Phy2Vir
	cbz	x0, .L78
	ldrb	w2, [x19, 4]
	mov	w1, 0
	ldrb	w4, [x19, 5]
	mov	w8, 0
	ldrb	w3, [x19, 3]
	bfi	w1, w2, 4, 2
	str	wzr, [x29, 44]
	mov	w2, 0
	bfi	w2, w4, 6, 2
	bfi	w1, w3, 0, 2
	strb	w2, [x29, 45]
	mov	w2, 0
	strb	w1, [x29, 44]
	mov	w3, 0
	mov	w6, 0
	mov	w5, 0
	ldr	w1, [x29, 44]
	mov	w12, 0
	str	w1, [x0]
	mov	w11, 0
	str	wzr, [x29, 44]
	mov	w10, 0
	ldrh	w1, [x19, 84]
	mov	w9, 0
	ldrh	w4, [x19, 82]
	strb	w4, [x29, 44]
	mov	w4, 0
	strb	w1, [x29, 46]
	ldr	w1, [x29, 44]
	str	w1, [x0, 4]
	mov	w1, 0
	str	wzr, [x29, 44]
	ldrb	w7, [x19, 8]
	bfi	w2, w7, 2, 1
	ldrb	w7, [x19, 6]
	bfi	w2, w7, 0, 1
	ldrb	w7, [x19, 9]
	bfi	w2, w7, 3, 1
	ldrb	w7, [x19, 7]
	bfi	w2, w7, 1, 1
	ldrb	w7, [x19, 10]
	bfi	w2, w7, 4, 2
	ldrb	w7, [x19, 11]
	bfi	w2, w7, 6, 2
	strb	w2, [x29, 44]
	ldr	w2, [x29, 44]
	str	w2, [x0, 8]
	str	wzr, [x29, 44]
	ldrb	w2, [x19, 15]
	ldrb	w7, [x19, 13]
	bfi	w3, w2, 4, 2
	mov	w2, w3
	ldrb	w3, [x19, 14]
	bfi	w2, w7, 1, 1
	mov	w7, 0
	bfi	w2, w3, 2, 1
	ldrb	w3, [x19, 12]
	bfi	w2, w3, 0, 1
	strb	w2, [x29, 44]
	mov	w3, 0
	ldr	w2, [x29, 44]
	str	w2, [x0, 12]
	ldrb	w2, [x19, 18]
	bfi	w8, w2, 0, 5
	ldrb	w2, [x19, 19]
	strb	w8, [x29, 46]
	bfi	w6, w2, 0, 1
	ldrb	w2, [x19, 17]
	strb	w6, [x29, 47]
	mov	w6, 0
	bfi	w5, w2, 0, 5
	ldrb	w2, [x19, 16]
	strb	w5, [x29, 45]
	mov	w5, 0
	bfi	w1, w2, 0, 5
	strb	w1, [x29, 44]
	mov	w1, 0
	ldr	w2, [x29, 44]
	str	w2, [x0, 16]
	str	wzr, [x29, 44]
	ldrb	w2, [x19, 20]
	ldrb	w8, [x19, 24]
	bfi	w4, w2, 0, 1
	mov	w2, w4
	ldrb	w4, [x19, 23]
	bfi	w3, w8, 4, 1
	mov	w8, 0
	bfi	w3, w4, 0, 2
	ldrb	w4, [x19, 22]
	bfi	w2, w4, 2, 2
	ldrb	w4, [x19, 25]
	bfi	w3, w4, 6, 1
	ldrb	w4, [x19, 26]
	strb	w3, [x29, 45]
	mov	w3, 0
	bfi	w7, w4, 0, 4
	ldrb	w4, [x19, 21]
	strb	w7, [x29, 46]
	bfi	w2, w4, 1, 1
	strb	w2, [x29, 44]
	mov	w2, 0
	ldr	w4, [x29, 44]
	str	w4, [x0, 20]
	str	wzr, [x29, 44]
	ldrb	w4, [x19, 27]
	ldrb	w7, [x19, 28]
	bfi	w6, w4, 0, 3
	mov	w4, w6
	mov	w6, 0
	bfi	w4, w7, 4, 2
	strb	w4, [x29, 44]
	mov	w7, 0
	ldr	w4, [x29, 44]
	str	w4, [x0, 24]
	str	wzr, [x29, 44]
	ldrb	w4, [x19, 34]
	bfi	w5, w4, 6, 1
	mov	w4, w5
	ldrb	w5, [x19, 33]
	bfi	w4, w5, 4, 2
	strb	w4, [x29, 45]
	ldrb	w4, [x19, 30]
	mov	w5, 0
	bfi	w1, w4, 1, 1
	ldrb	w4, [x19, 29]
	bfi	w1, w4, 0, 1
	ldrb	w4, [x19, 31]
	bfi	w1, w4, 2, 2
	strb	w1, [x29, 44]
	ldrb	w4, [x19, 32]
	ldrh	w1, [x29, 44]
	bfi	w1, w4, 4, 5
	strh	w1, [x29, 44]
	mov	w4, 0
	ldr	w1, [x29, 44]
	str	w1, [x0, 28]
	mov	w1, 0
	str	wzr, [x29, 44]
	ldrb	w13, [x19, 35]
	bfi	w3, w13, 0, 1
	ldrb	w13, [x19, 36]
	bfi	w3, w13, 1, 1
	ldrb	w13, [x19, 37]
	bfi	w3, w13, 2, 1
	ldrb	w13, [x19, 38]
	bfi	w3, w13, 4, 2
	ldrb	w13, [x19, 39]
	bfi	w3, w13, 6, 2
	strb	w3, [x29, 44]
	ldrb	w3, [x19, 40]
	bfi	w12, w3, 0, 2
	strb	w12, [x29, 45]
	ldr	w3, [x29, 44]
	str	w3, [x0, 32]
	str	wzr, [x29, 44]
	ldrb	w3, [x19, 46]
	bfi	w2, w3, 5, 1
	ldrb	w3, [x19, 42]
	bfi	w2, w3, 1, 1
	ldrb	w3, [x19, 44]
	bfi	w2, w3, 3, 1
	ldrb	w3, [x19, 41]
	bfi	w2, w3, 0, 1
	ldrb	w3, [x19, 43]
	bfi	w2, w3, 2, 1
	ldrb	w3, [x19, 47]
	bfi	w2, w3, 6, 1
	ldrb	w3, [x19, 45]
	bfi	w2, w3, 4, 1
	strb	w2, [x29, 44]
	ldr	w2, [x29, 44]
	str	w2, [x0, 36]
	str	wzr, [x29, 44]
	ldrb	w2, [x19, 50]
	bfi	w11, w2, 0, 7
	ldrb	w2, [x19, 49]
	strb	w11, [x29, 46]
	bfi	w10, w2, 0, 3
	ldrb	w2, [x19, 48]
	strb	w10, [x29, 45]
	bfi	w9, w2, 0, 3
	strb	w9, [x29, 44]
	ldr	w2, [x29, 44]
	str	w2, [x0, 40]
	str	wzr, [x29, 44]
	ldrb	w2, [x19, 53]
	ldrb	w3, [x19, 54]
	bfi	w8, w2, 0, 2
	mov	w2, w8
	bfi	w2, w3, 4, 1
	ldrb	w3, [x19, 51]
	strb	w2, [x29, 45]
	bfi	w7, w3, 0, 3
	ldrb	w3, [x19, 52]
	mov	w2, w7
	bfi	w2, w3, 4, 2
	strb	w2, [x29, 44]
	ldr	w2, [x29, 44]
	str	w2, [x0, 44]
	ldr	w2, [x19, 14424]
	str	w2, [x0, 48]
	ldr	w2, [x19, 14428]
	str	w2, [x0, 52]
	ldr	w2, [x19, 14432]
	str	w2, [x0, 56]
	ldrb	w3, [x19, 55]
	ldrb	w2, [x19, 57]
	ldrb	w8, [x19, 56]
	bfi	w6, w3, 4, 1
	ldrb	w7, [x19, 58]
	bfi	w5, w2, 0, 1
	mov	w3, w6
	mov	w2, w5
	ldrh	w5, [x19, 76]
	bfi	w3, w8, 5, 3
	strh	w5, [x29, 44]
	bfi	w2, w7, 1, 3
	strb	w3, [x29, 46]
	strb	w2, [x29, 47]
	ldr	w2, [x29, 44]
	str	w2, [x0, 60]
	ldr	w2, [x19, 14436]
	str	w2, [x0, 64]
	ldr	w2, [x19, 14440]
	str	w2, [x0, 68]
	ldr	w2, [x19, 14444]
	str	w2, [x0, 72]
	ldr	w2, [x19, 14448]
	str	w2, [x0, 76]
	ldr	w2, [x19, 14452]
	str	w2, [x0, 80]
	ldr	w2, [x20, 1160]
	str	w2, [x0, 84]
	ldr	w2, [x20, 1164]
	str	w2, [x0, 88]
	ldr	w2, [x20, 1172]
	str	w2, [x0, 92]
	ldr	w2, [x20, 1176]
	str	w2, [x0, 96]
	ldr	w2, [x20, 1192]
	str	w2, [x0, 104]
	ldrh	w2, [x19, 78]
	ldrh	w3, [x19, 80]
	strh	w3, [x29, 46]
	strh	w2, [x29, 44]
	ldr	w2, [x29, 44]
	str	w2, [x0, 108]
	str	wzr, [x29, 44]
	ldrb	w6, [x19, 59]
	ldrb	w2, [x19, 60]
	ldrb	w3, [x19, 61]
	bfi	w1, w6, 4, 1
	ldrb	w5, [x19, 63]
	bfi	w1, w2, 5, 1
	bfi	w1, w3, 6, 1
	strb	w1, [x29, 46]
	bfi	w4, w5, 1, 3
	ldrb	w1, [x19, 62]
	mov	w2, w4
	bfi	w2, w1, 0, 1
	strb	w2, [x29, 47]
	ldr	w1, [x29, 44]
	str	w1, [x0, 112]
	ldr	w1, [x19, 14456]
	str	w1, [x0, 116]
	ldr	w1, [x19, 14460]
	str	w1, [x0, 120]
	ldr	w1, [x19, 14464]
	str	w1, [x0, 124]
	ldr	w1, [x19, 14468]
	str	w1, [x0, 128]
	ldr	w1, [x19, 14472]
	str	w1, [x0, 132]
	ldr	w1, [x19, 14476]
	str	w1, [x0, 136]
	ldr	w1, [x19, 14480]
	str	w1, [x0, 140]
	ldr	w1, [x19, 14484]
	str	w1, [x0, 144]
	ldr	w1, [x20, 76]
	str	w1, [x0, 252]
	str	w1, [x29, 44]
	ldr	w0, [x20, 1192]
	bl	MEM_Phy2Vir
	cbz	x0, .L79
	ldr	x3, .LC27
	mov	x2, 3072
	ldr	x1, [x19, 64]
	ldr	x3, [x3, 104]
	blr	x3
	mov	w0, 0
.L76:
	ldp	x19, x20, [sp, 16]
	ldp	x29, x30, [sp], 48
	ret
.L78:
	ldr	x2, .LC23
	ldr	x1, .LC24
	add	x2, x2, 56
	bl	dprint_vfmw
	mov	w0, -1
	b	.L76
.L79:
	ldr	x2, .LC23
	ldr	x1, .LC26
	add	x2, x2, 56
	bl	dprint_vfmw
	mov	w0, -1
	b	.L76
	.size	VC1HAL_V5R2C1_CfgDnMsg, .-VC1HAL_V5R2C1_CfgDnMsg
	.align	3
.LC23:
	.xword	.LANCHOR0
	.align	3
.LC24:
	.xword	.LC4
	.align	3
.LC26:
	.xword	.LC25
	.align	3
.LC27:
	.xword	vfmw_Osal_Func_Ptr_S
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	VC1HAL_V5R2C1_StartDec
	.type	VC1HAL_V5R2C1_StartDec, %function
VC1HAL_V5R2C1_StartDec:
	stp	x29, x30, [sp, -64]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	stp	x21, x22, [sp, 32]
	stp	x23, x24, [sp, 48]
	mov	x20, x0
	mov	x0, x30
	mov	w22, w1
	mov	x23, x2
	bl	_mcount
	ldr	x24, .LC28
	sxtw	x0, w22
	cmp	w22, wzr
	lsl	x19, x0, 6
	sub	x19, x19, x0
	lsl	x19, x19, 2
	sub	x0, x19, x0
	add	x19, x19, x0, lsl 2
	add	x21, x19, x24
	bgt	.L90
	cbz	x20, .L91
	ldrh	w0, [x20, 82]
	cmp	w0, 512
	bhi	.L92
	ldrh	w0, [x20, 84]
	cmp	w0, 512
	bhi	.L93
	ldr	w0, [x21, 72]
	bl	MEM_Phy2Vir
	cbz	x0, .L94
	ldr	x0, [x19, x24]
	cbz	x0, .L95
.L87:
	mov	x1, x21
	mov	x0, x20
	bl	VC1HAL_V5R2C1_CfgSliceMsg
	mov	x3, x23
	mov	w2, w22
	mov	x1, x21
	mov	x0, x20
	bl	VC1HAL_V5R2C1_CfgReg
	mov	x1, x21
	mov	x0, x20
	bl	VC1HAL_V5R2C1_CfgDnMsg
	mov	w0, 0
.L82:
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x29, x30, [sp], 64
	ret
	.p2align 3
.L95:
	mov	w0, -121438208
	bl	MEM_Phy2Vir
	cbz	x0, .L88
	str	x0, [x19, x24]
	b	.L87
	.p2align 3
.L90:
	ldr	x1, .LC30
	mov	w0, 0
	bl	dprint_vfmw
	mov	w0, -1
	b	.L82
	.p2align 3
.L93:
	ldr	x2, .LC33
	ldr	x3, .LC39
.L89:
	ldr	x1, .LC35
	mov	w0, 0
	add	x2, x2, 80
	bl	dprint_vfmw
	mov	w0, -1
	b	.L82
	.p2align 3
.L92:
	ldr	x2, .LC33
	ldr	x3, .LC37
	b	.L89
.L91:
	ldr	x2, .LC33
	ldr	x3, .LC32
	b	.L89
.L94:
	ldr	x2, .LC33
	ldr	x3, .LC41
	ldr	x1, .LC35
	add	x2, x2, 80
	bl	dprint_vfmw
	mov	w0, -1
	b	.L82
.L88:
	ldr	x1, .LC43
	mov	w0, 0
	bl	dprint_vfmw
	mov	w0, -1
	b	.L82
	.size	VC1HAL_V5R2C1_StartDec, .-VC1HAL_V5R2C1_StartDec
	.align	3
.LC28:
	.xword	g_HwMem
	.align	3
.LC30:
	.xword	.LC29
	.align	3
.LC32:
	.xword	.LC31
	.align	3
.LC33:
	.xword	.LANCHOR0
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
	.section	.rodata
	.align	3
.LANCHOR0 = . + 0
	.type	__func__.11793, %object
	.size	__func__.11793, 26
__func__.11793:
	.string	"VC1HAL_V5R2C1_CfgSliceMsg"
	.zero	6
	.type	__func__.11801, %object
	.size	__func__.11801, 21
__func__.11801:
	.string	"VC1HAL_V5R2C1_CfgReg"
	.zero	3
	.type	__func__.11809, %object
	.size	__func__.11809, 23
__func__.11809:
	.string	"VC1HAL_V5R2C1_CfgDnMsg"
	.zero	1
	.type	__func__.11724, %object
	.size	__func__.11724, 23
__func__.11724:
	.string	"VC1HAL_V5R2C1_StartDec"
	.section	.rodata.str1.8,"aMS",%progbits,1
	.align	3
.LC4:
	ASCII(.string	"%s: pMsgBase = NULL\n" )
	.zero	3
.LC6:
	ASCII(.string	"pVc1DecParam->SlcNum = %d\n" )
	.zero	5
.LC8:
	ASCII(.string	"D0 = 0x%08x\n" )
	.zero	3
.LC10:
	ASCII(.string	"D1 = 0x%08x\n" )
	.zero	3
.LC12:
	ASCII(.string	"D2 = 0x%08x\n" )
	.zero	3
.LC14:
	ASCII(.string	"D3 = 0x%08x\n" )
	.zero	3
.LC16:
	ASCII(.string	"D4 = 0x%08x\n" )
	.zero	3
.LC18:
	ASCII(.string	"D63 = 0x%08x\n" )
	.zero	2
.LC21:
	ASCII(.string	"%s: VdhId(%d) > %d\n" )
	.zero	4
.LC25:
	ASCII(.string	"%s: u8Tmp = NULL\n" )
	.zero	6
.LC29:
	ASCII(.string	"VdhId is wrong! VC1HAL_V200R003_StartDec\n" )
	.zero	6
.LC31:
	ASCII(.string	"point of picture para null\n" )
	.zero	4
.LC34:
	ASCII(.string	"%s: %s\n" )
.LC36:
	ASCII(.string	"picture width out of range" )
	.zero	5
.LC38:
	ASCII(.string	"picture height out of range" )
	.zero	4
.LC40:
	ASCII(.string	"can not map down msg virtual address!" )
	.zero	2
.LC42:
	ASCII(.string	"vdm register virtual address not mapped, reset failed!\n" )
	.ident	"GCC: (gcc-linaro-5.1-2015.08 + glibc-2.22 (Build by czyong Wed Mar  9 18:57:48 CST 2016)) 5.1.1 20150608"
	.section	.note.GNU-stack,"",%progbits
