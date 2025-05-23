#include "hi_asm_define.h"
	.arch armv8-a+fp+simd
	.file	"vdm_hal_mpeg2.c"
	.global	_mcount
	.text
	.align	2
	.p2align 3,,7
	.global	MP2HAL_V5R6C1_WriteSliceMsg
	.type	MP2HAL_V5R6C1_WriteSliceMsg, %function
MP2HAL_V5R6C1_WriteSliceMsg:
	stp	x29, x30, [sp, -128]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	stp	x21, x22, [sp, 32]
	stp	x23, x24, [sp, 48]
	stp	x25, x26, [sp, 64]
	stp	x27, x28, [sp, 80]
	mov	x21, x0
	mov	x0, x30
	add	x26, x21, 236
	mov	x20, x1
	mov	w19, w2
	mov	w22, w3
	str	x21, [x29, 96]
	bl	_mcount
	add	x1, x21, 45056
	ldr	w0, [x26, 32]
	mov	w23, 0
	ldr	w25, [x1, 236]
	cbnz	w0, .L25
.L2:
	cmp	w25, wzr
	ble	.L22
	ldr	x28, .LC15
	add	w0, w19, w23, lsl 5
	mov	w24, 0
	str	w0, [x29, 108]
	.p2align 2
.L17:
	cmp	w24, wzr
	mov	w21, 44
	ble	.L26
	smaddl	x21, w24, w21, x26
	sxtw	x19, w24
	ldr	w0, [x21, -12]
	ldr	w1, [x21, 32]
	cmp	w1, w0
	bls	.L8
.L7:
	ldr	w27, [x21]
	mov	w2, 0
	ldr	w7, [x21, 8]
	mov	w1, 0
	ldr	w0, [x21, 16]
	ubfiz	w8, w27, 3, 4
	bfi	w2, w7, 0, 24
	str	w2, [x29, 124]
	add	w0, w8, w0
	add	x19, x19, x23, sxtw
	bfi	w1, w0, 0, 7
	strb	w1, [x29, 127]
	lsl	x19, x19, 5
	ldr	x1, .LC1
	ldr	w7, [x29, 124]
	mov	w0, 4
	mov	w2, w7
	str	w7, [x20, x19]
	bl	dprint_vfmw
	add	x8, x19, 4
	and	w6, w27, -16
	sub	w6, w6, w22
	mov	w7, 0
	bfi	w7, w6, 0, 24
	ldr	x1, .LC3
	str	w7, [x20, x8]
	mov	w2, w7
	mov	w0, 4
	str	w7, [x29, 124]
	bl	dprint_vfmw
	ldr	w27, [x21, 4]
	ldr	w1, [x21, 12]
	mov	w2, 0
	ldr	w0, [x21, 20]
	ubfiz	w7, w27, 3, 4
	bfi	w2, w1, 0, 24
	mov	w1, 0
	str	w2, [x29, 124]
	add	w0, w7, w0
	bfi	w1, w0, 0, 7
	add	x7, x19, 8
	strb	w1, [x29, 127]
	mov	w0, 4
	ldr	x1, .LC5
	ldr	w2, [x29, 124]
	str	w2, [x20, x7]
	bl	dprint_vfmw
	ldr	w0, [x21, 4]
	cbz	w0, .L9
	and	w6, w27, -16
	mov	w0, 0
	sub	w6, w6, w22
	bfi	w0, w6, 0, 24
	str	w0, [x29, 124]
.L10:
	add	x6, x19, 12
	ldr	w7, [x29, 124]
	ldr	x1, .LC7
	mov	w0, 4
	mov	w2, w7
	add	w24, w24, 1
	str	w7, [x20, x6]
	bl	dprint_vfmw
	str	wzr, [x29, 124]
	ldp	w1, w2, [x21, 36]
	mov	w0, 0
	add	x6, x19, 16
	bfi	w0, w2, 0, 6
	bfi	w0, w1, 6, 1
	strb	w0, [x29, 124]
	ldr	x1, .LC9
	mov	w0, 4
	ldr	w2, [x29, 124]
	str	w2, [x20, x6]
	bl	dprint_vfmw
	ldr	w0, [x21, 32]
	add	x7, x19, 20
	mov	w6, 0
	ldr	x1, .LC11
	bfi	w6, w0, 0, 20
	mov	w0, 4
	str	w6, [x20, x7]
	mov	w2, w6
	str	w6, [x29, 124]
	bl	dprint_vfmw
	cmp	w25, w24
	ble	.L11
	mov	w1, 44
	ldr	w2, [x21, 32]
	smaddl	x0, w24, w1, x26
	ldr	w0, [x0, 32]
	cmp	w2, w0
	bcs	.L13
	b	.L11
	.p2align 3
.L14:
	ldr	w0, [x0, 32]
	cmp	w0, w2
	bhi	.L11
.L13:
	add	w24, w24, 1
	cmp	w25, w24
	smaddl	x0, w24, w1, x26
	bgt	.L14
.L11:
	cmp	w25, w24
	beq	.L27
	mov	w0, 44
	ldr	w1, [x29, 108]
	smaddl	x0, w24, w0, x26
	add	w27, w1, w24, lsl 5
	mov	w21, w27
	ldr	w0, [x0, 32]
	sub	w0, w0, #1
.L16:
	add	x8, x19, 24
	mov	w6, 0
	bfi	w6, w0, 0, 20
	ldr	x1, .LC13
	mov	w2, w6
	mov	w0, 4
	str	w6, [x20, x8]
	add	x19, x19, 28
	str	w6, [x29, 124]
	sub	w24, w24, #1
	bl	dprint_vfmw
	str	w27, [x29, 124]
	mov	w2, w27
	mov	x1, x28
	mov	w0, 4
	str	w21, [x20, x19]
	bl	dprint_vfmw
.L8:
	add	w24, w24, 1
	cmp	w25, w24
	bgt	.L17
.L22:
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x25, x26, [sp, 64]
	ldp	x27, x28, [sp, 80]
	mov	w0, 0
	ldp	x29, x30, [sp], 128
	ret
	.p2align 3
.L9:
	str	wzr, [x29, 124]
	b	.L10
	.p2align 3
.L27:
	ldr	x1, [x29, 96]
	mov	w21, 0
	mov	w27, 0
	ldrh	w0, [x1, 150]
	ldrh	w1, [x1, 146]
	mul	w0, w0, w1
	sub	w0, w0, #1
	b	.L16
	.p2align 3
.L26:
	smaddl	x21, w24, w21, x26
	sxtw	x19, w24
	b	.L7
.L25:
	ldr	x0, [x29, 96]
	mov	w3, 1
	mov	w1, 0
	ldr	w21, [x0, 236]
	ldr	w0, [x26, 16]
	ubfiz	w2, w21, 3, 4
	str	w3, [x29, 124]
	add	w0, w2, w0
	bfi	w1, w0, 0, 7
	strb	w1, [x29, 127]
	ldr	x1, .LC1
	mov	w0, 4
	ldr	w2, [x29, 124]
	str	w2, [x20]
	bl	dprint_vfmw
	and	w0, w21, -16
	mov	w3, 0
	sub	w0, w0, w22
	ldr	x1, .LC3
	bfi	w3, w0, 0, 24
	mov	w0, 4
	mov	w2, w3
	str	w3, [x20, 4]
	str	w3, [x29, 124]
	bl	dprint_vfmw
	ldr	w21, [x26, 4]
	ldr	w0, [x26, 20]
	mov	w1, 0
	ubfiz	w2, w21, 3, 4
	str	wzr, [x29, 124]
	add	w0, w2, w0
	bfi	w1, w0, 0, 7
	strb	w1, [x29, 127]
	ldr	x1, .LC5
	mov	w0, 4
	ldr	w2, [x29, 124]
	str	w2, [x20, 8]
	bl	dprint_vfmw
	ldr	w0, [x26, 4]
	cbnz	w0, .L28
	str	wzr, [x29, 124]
.L4:
	ldr	w2, [x29, 124]
	mov	w0, 4
	ldr	x1, .LC7
	mov	w23, 1
	str	w2, [x20, 12]
	bl	dprint_vfmw
	str	wzr, [x29, 124]
	ldp	w2, w1, [x26, 36]
	mov	w0, 0
	bfi	w0, w1, 0, 6
	ldr	x1, .LC9
	bfi	w0, w2, 6, 1
	strb	w0, [x29, 124]
	mov	w0, 4
	ldr	w2, [x29, 124]
	str	w2, [x20, 16]
	bl	dprint_vfmw
	str	wzr, [x20, 20]
	ldr	x1, .LC11
	mov	w2, 0
	mov	w0, 4
	str	wzr, [x29, 124]
	bl	dprint_vfmw
	ldr	w2, [x26, 32]
	mov	w3, 0
	ldr	x1, .LC13
	mov	w0, 4
	sub	w2, w2, #1
	bfi	w3, w2, 0, 20
	str	w3, [x20, 24]
	mov	w2, w3
	str	w3, [x29, 124]
	bl	dprint_vfmw
	add	w0, w19, 32
	str	w0, [x20, 28]
	b	.L2
.L28:
	and	w0, w21, -16
	mov	w1, 0
	sub	w0, w0, w22
	bfi	w1, w0, 0, 24
	str	w1, [x29, 124]
	b	.L4
	.size	MP2HAL_V5R6C1_WriteSliceMsg, .-MP2HAL_V5R6C1_WriteSliceMsg
	.align	3
.LC1:
	.xword	.LC0
	.align	3
.LC3:
	.xword	.LC2
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
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	MP2HAL_V5R6C1_MakeReg
	.type	MP2HAL_V5R6C1_MakeReg, %function
MP2HAL_V5R6C1_MakeReg:
	stp	x29, x30, [sp, -48]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	str	x21, [sp, 32]
	mov	x19, x0
	mov	x20, x2
	mov	x0, x30
	mov	x21, x1
	bl	_mcount
	ldrh	w2, [x20, 146]
	mov	w3, 3
	ldrh	w0, [x20, 150]
	ldr	x1, [x19, 16]
	mul	w0, w0, w2
	ldr	w2, [x1]
	sub	w0, w0, #1
	bfi	w2, w0, 0, 20
	str	w2, [x1]
	mov	w2, 1
	ldr	x1, [x19, 16]
	ldrb	w0, [x1, 3]
	orr	w0, w0, 64
	strb	w0, [x1, 3]
	ldr	x1, [x19, 16]
	ldrb	w0, [x1, 3]
	and	w0, w0, 127
	strb	w0, [x1, 3]
	ldr	x0, [x19, 24]
	ldrb	w1, [x0]
	bfi	w1, w3, 0, 4
	strb	w1, [x0]
	ldr	x1, [x19, 24]
	ldrb	w0, [x1, 1]
	orr	w0, w0, 64
	strb	w0, [x1, 1]
	ldr	x1, [x19, 24]
	ldrb	w0, [x1, 1]
	and	w0, w0, 127
	strb	w0, [x1, 1]
	ldr	x0, [x19, 24]
	ldrh	w1, [x0, 2]
	bfi	w1, w2, 0, 12
	strh	w1, [x0, 2]
	ldr	x0, [x19, 24]
	ldrh	w1, [x20, 150]
	cmp	w1, 120
	ldrb	w1, [x0, 3]
	cset	w2, le
	bfi	w1, w2, 5, 1
	strb	w1, [x0, 3]
	mov	w2, 2
	ldr	x1, [x19, 24]
	ldrb	w0, [x1, 3]
	and	w0, w0, 127
	strb	w0, [x1, 3]
	ldr	x1, [x19, 24]
	ldrb	w0, [x1, 3]
	and	w0, w0, -17
	strb	w0, [x1, 3]
	ldr	x1, [x19, 24]
	ldrb	w0, [x1, 3]
	and	w0, w0, -65
	strb	w0, [x1, 3]
	ldr	x1, [x19, 120]
	ldrb	w0, [x1]
	and	w0, w0, -2
	strb	w0, [x1]
	ldr	x0, [x19, 112]
	str	wzr, [x0]
	ldr	x0, [x19, 112]
	ldr	w3, [x20, 196]
	ldrb	w1, [x0]
	bfi	w1, w3, 0, 2
	strb	w1, [x0]
	ldr	x0, [x19, 112]
	ldr	w3, [x20, 192]
	ldrb	w1, [x0]
	bfi	w1, w3, 2, 2
	strb	w1, [x0]
	ldr	x1, [x19, 32]
	ldr	w0, [x21, 72]
	and	w0, w0, -16
	str	w0, [x1]
	ldr	x1, [x19, 40]
	ldr	w0, [x21, 56]
	and	w0, w0, -16
	str	w0, [x1]
	ldr	x1, [x19, 56]
	ldr	w0, [x20, 188]
	and	w0, w0, -256
	str	w0, [x1]
	ldrb	w1, [x20, 3]
	ldr	x3, [x19, 64]
	sub	w1, w1, #1
	ldrh	w0, [x20, 146]
	ldrh	w4, [x20, 150]
	uxtb	w1, w1
	str	w4, [x3]
	cmp	w1, w2
	csinc	w1, w2, wzr, cc
	ldrh	w3, [x20, 150]
	ldr	x2, [x19, 72]
	mul	w0, w1, w0
	mul	w0, w0, w3
	lsl	w0, w0, 8
	str	w0, [x2]
	ldr	w0, [x20, 172]
	cbz	w0, .L34
	ldr	w0, [x20, 164]
	ldr	w2, [x20, 156]
	ldr	x1, [x19, 48]
	add	w0, w2, w0, lsr 3
	and	w0, w0, -16
	str	w0, [x1]
	mov	w0, 0
	ldp	x19, x20, [sp, 16]
	ldr	x21, [sp, 32]
	ldp	x29, x30, [sp], 48
	ret
	.p2align 3
.L34:
	ldr	w0, [x20, 160]
	ldr	w2, [x20, 152]
	ldr	x1, [x19, 48]
	add	w0, w2, w0, lsr 3
	and	w0, w0, -16
	str	w0, [x1]
	mov	w0, 0
	ldp	x19, x20, [sp, 16]
	ldr	x21, [sp, 32]
	ldp	x29, x30, [sp], 48
	ret
	.size	MP2HAL_V5R6C1_MakeReg, .-MP2HAL_V5R6C1_MakeReg
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	MP2HAL_V5R6C1_MakeDnMsg
	.type	MP2HAL_V5R6C1_MakeDnMsg, %function
MP2HAL_V5R6C1_MakeDnMsg:
	sub	sp, sp, #80
	stp	x29, x30, [sp, 16]
	add	x29, sp, 16
	stp	x19, x20, [sp, 32]
	stp	x21, x22, [sp, 48]
	stp	x23, x24, [sp, 64]
	mov	x19, x2
	mov	x21, x0
	mov	x0, x30
	mov	x20, x1
	bl	_mcount
	ldrh	w0, [x19, 150]
	cmp	w0, 512
	bhi	.L57
	ldrh	w1, [x19, 146]
	cmp	w1, 512
	bhi	.L58
	ldr	x1, [x21]
	sub	w0, w0, #1
	ldrh	w2, [x1]
	bfi	w2, w0, 0, 9
	strh	w2, [x1]
	ldr	x1, [x21]
	ldrh	w0, [x19, 146]
	ldrh	w2, [x1, 2]
	sub	w0, w0, #1
	bfi	w2, w0, 0, 9
	strh	w2, [x1, 2]
	ldr	x0, [x21]
	ldr	w2, [x19, 176]
	ldrb	w1, [x0, 3]
	bfi	w1, w2, 1, 1
	strb	w1, [x0, 3]
	ldr	x0, [x21, 8]
	ldrb	w2, [x19, 5]
	ldrb	w1, [x0]
	bfi	w1, w2, 0, 1
	strb	w1, [x0]
	ldr	x0, [x21, 8]
	ldrb	w2, [x19, 3]
	ldrb	w1, [x0, 1]
	bfi	w1, w2, 0, 2
	strb	w1, [x0, 1]
	ldr	x0, [x21, 8]
	ldrb	w2, [x19, 4]
	ldrb	w1, [x0, 1]
	bfi	w1, w2, 2, 1
	strb	w1, [x0, 1]
	ldr	x0, [x21, 8]
	ldrb	w2, [x19, 7]
	ldrb	w1, [x0, 2]
	bfi	w1, w2, 0, 1
	strb	w1, [x0, 2]
	ldr	x0, [x21, 8]
	ldrb	w2, [x19]
	ldrb	w1, [x0, 3]
	bfi	w1, w2, 0, 3
	strb	w1, [x0, 3]
	ldr	x0, [x21, 8]
	ldrb	w1, [x0, 3]
	ldrb	w2, [x19, 2]
	bfi	w1, w2, 3, 1
	strb	w1, [x0, 3]
	ldr	x0, [x21, 8]
	ldrb	w2, [x19, 1]
	ldrb	w1, [x0, 3]
	bfi	w1, w2, 4, 1
	strb	w1, [x0, 3]
	ldr	x0, [x21, 16]
	ldrb	w2, [x19, 15]
	ldrb	w1, [x0]
	bfi	w1, w2, 0, 4
	strb	w1, [x0]
	ldr	x0, [x21, 16]
	ldrb	w2, [x19, 14]
	ldrb	w1, [x0, 1]
	bfi	w1, w2, 0, 4
	strb	w1, [x0, 1]
	ldr	x0, [x21, 16]
	ldrb	w2, [x19, 13]
	ldrb	w1, [x0, 2]
	bfi	w1, w2, 0, 4
	strb	w1, [x0, 2]
	ldr	x0, [x21, 16]
	ldrb	w2, [x19, 12]
	ldrb	w1, [x0, 3]
	bfi	w1, w2, 0, 4
	strb	w1, [x0, 3]
	ldr	x0, [x21, 16]
	ldrb	w2, [x19, 6]
	ldrb	w1, [x0, 3]
	bfi	w1, w2, 7, 1
	strb	w1, [x0, 3]
	ldr	x0, [x21, 24]
	ldrb	w2, [x19, 11]
	ldrb	w1, [x0]
	bfi	w1, w2, 0, 2
	strb	w1, [x0]
	ldr	x0, [x21, 24]
	ldrb	w1, [x0, 1]
	ldrb	w2, [x19, 10]
	bfi	w1, w2, 0, 1
	strb	w1, [x0, 1]
	ldr	x0, [x21, 24]
	ldrb	w2, [x19, 9]
	ldrb	w1, [x0, 2]
	bfi	w1, w2, 0, 1
	strb	w1, [x0, 2]
	ldr	x0, [x21, 24]
	ldrb	w2, [x19, 8]
	ldrb	w1, [x0, 3]
	bfi	w1, w2, 0, 1
	strb	w1, [x0, 3]
	ldr	x1, [x21, 32]
	ldr	w0, [x19, 180]
	and	w0, w0, -16
	str	w0, [x1]
	ldr	x1, [x21, 40]
	ldr	w0, [x19, 184]
	and	w0, w0, -16
	str	w0, [x1]
	ldr	x1, [x21, 48]
	ldr	w0, [x19, 200]
	and	w0, w0, -16
	str	w0, [x1]
	ldr	x1, [x21, 56]
	ldr	w0, [x19, 224]
	and	w0, w0, -16
	str	w0, [x1]
	ldr	w0, [x19, 152]
	bl	MEM_Phy2Vir
	mov	x22, x0
	ldr	w0, [x19, 156]
	bl	MEM_Phy2Vir
	mov	x24, x0
	ldr	w0, [x19, 172]
	cbz	w0, .L59
	ldp	w0, w23, [x19, 160]
	ldp	w3, w1, [x19, 152]
	ldr	x2, [x21, 64]
	add	w0, w3, w0, lsr 3
	add	w23, w1, w23, lsr 3
	and	w3, w23, -16
	and	w1, w0, -16
	sub	w1, w1, w3
	ldr	w3, [x2]
	and	w0, w0, 15
	bfi	w3, w1, 0, 24
	str	w3, [x2]
	ldr	x1, [x21, 72]
	ldr	w3, [x19, 168]
	ldr	w2, [x1]
	bfi	w2, w3, 0, 24
	str	w2, [x1]
	ldr	x2, [x21, 72]
	ldr	w1, [x19, 160]
	ldrb	w3, [x2, 3]
	and	w1, w1, 7
	add	w0, w1, w0, lsl 3
	bfi	w3, w0, 0, 7
	strb	w3, [x2, 3]
	cbz	x22, .L42
	ldr	w1, [x19, 160]
	ubfx	x1, x1, 3, 29
	add	x0, x22, x1
	ldrb	w2, [x22, x1]
	ldrb	w1, [x0, 7]
	ldrb	w7, [x0, 5]
	ldrb	w6, [x0, 4]
	ldrb	w5, [x0, 3]
	ldrb	w4, [x0, 2]
	ldrb	w3, [x0, 1]
	str	w1, [sp, 8]
	ldr	x1, .LC28
	ldrb	w0, [x0, 6]
	str	w0, [sp]
	mov	w0, 8
	bl	dprint_vfmw
	ldr	w2, [x19, 168]
	ldr	w1, [x19, 160]
	cmp	w2, wzr
	add	w0, w2, 7
	csel	w0, w0, w2, lt
	ubfx	x1, x1, 3, 29
	asr	w0, w0, 3
	add	x0, x1, x0, sxtw
	ldr	x1, .LC30
	sub	x0, x0, #8
	add	x8, x22, x0
	ldrb	w2, [x22, x0]
	ldrb	w0, [x8, 7]
	ldrb	w3, [x8, 1]
	ldrb	w7, [x8, 5]
	ldrb	w6, [x8, 4]
	ldrb	w5, [x8, 3]
	ldrb	w4, [x8, 2]
	str	w0, [sp, 8]
	ldrb	w0, [x8, 6]
	str	w0, [sp]
	mov	w0, 9
	bl	dprint_vfmw
	ldr	w3, [x19, 152]
	mov	w0, 22
	ldr	w2, [x19, 168]
	ldr	x1, .LC32
	add	w2, w3, w2
	bl	dprint_vfmw
.L42:
	ldr	x1, [x21, 80]
	and	w23, w23, 15
	ldr	w0, [x1]
	and	w0, w0, -16777216
	str	w0, [x1]
	ldr	x1, [x21, 88]
	ldr	w0, [x19, 172]
	ldr	w2, [x1]
	add	w0, w0, 24
	bfi	w2, w0, 0, 24
	str	w2, [x1]
	ldr	x1, [x21, 88]
	ldr	w0, [x19, 164]
	ldrb	w2, [x1, 3]
	and	w0, w0, 7
	add	w0, w0, w23, lsl 3
	bfi	w2, w0, 0, 7
	strb	w2, [x1, 3]
	cbz	x24, .L43
	ldr	w1, [x19, 164]
	ubfx	x1, x1, 3, 29
	add	x0, x24, x1
	ldrb	w2, [x24, x1]
	ldrb	w1, [x0, 7]
	ldrb	w7, [x0, 5]
	ldrb	w6, [x0, 4]
	ldrb	w5, [x0, 3]
	ldrb	w4, [x0, 2]
	ldrb	w3, [x0, 1]
	str	w1, [sp, 8]
	ldr	x1, .LC34
	ldrb	w0, [x0, 6]
	str	w0, [sp]
	mov	w0, 8
	bl	dprint_vfmw
	ldr	w2, [x19, 172]
	ldr	w1, [x19, 164]
	add	w0, w2, 7
	cmp	w2, wzr
	csel	w0, w0, w2, lt
	ubfx	x1, x1, 3, 29
	asr	w0, w0, 3
	add	x0, x1, x0, sxtw
	ldr	x1, .LC36
	sub	x0, x0, #8
	add	x8, x24, x0
	ldrb	w2, [x24, x0]
	ldrb	w0, [x8, 7]
	ldrb	w7, [x8, 5]
	ldrb	w6, [x8, 4]
	ldrb	w5, [x8, 3]
	ldrb	w4, [x8, 2]
	ldrb	w3, [x8, 1]
	str	w0, [sp, 8]
	ldrb	w0, [x8, 6]
	str	w0, [sp]
	mov	w0, 9
	bl	dprint_vfmw
.L43:
	mov	w6, 0
	.p2align 2
.L41:
	mov	w1, w6
	lsl	w5, w6, 1
	add	w10, w6, 16
.L44:
	add	x0, x21, x5, sxtw 3
	add	x7, x19, x1, sxtw
	add	w4, w1, 16
	add	w3, w1, 32
	add	w2, w1, 48
	add	w1, w1, 8
	ldr	x8, [x0, 96]
	add	x4, x19, x4, sxtw
	ldrb	w9, [x7, 80]
	add	x3, x19, x3, sxtw
	add	x2, x19, x2, sxtw
	cmp	w10, w1
	strb	w9, [x8]
	add	w5, w5, 1
	ldr	x8, [x0, 96]
	ldrb	w9, [x4, 80]
	strb	w9, [x8, 1]
	ldr	x8, [x0, 96]
	ldrb	w9, [x3, 80]
	strb	w9, [x8, 2]
	ldr	x8, [x0, 96]
	ldrb	w9, [x2, 80]
	strb	w9, [x8, 3]
	ldr	x8, [x0, 352]
	ldrb	w7, [x7, 16]
	strb	w7, [x8]
	ldr	x7, [x0, 352]
	ldrb	w4, [x4, 16]
	strb	w4, [x7, 1]
	ldr	x4, [x0, 352]
	ldrb	w3, [x3, 16]
	strb	w3, [x4, 2]
	ldr	x0, [x0, 352]
	ldrb	w2, [x2, 16]
	strb	w2, [x0, 3]
	bne	.L44
	add	w6, w6, 1
	cmp	w6, 8
	bne	.L41
	ldr	x2, [x21, 608]
	mov	w0, 0
	ldr	w1, [x20, 1164]
	and	w1, w1, -16
	str	w1, [x2]
.L37:
	add	sp, x29, 0
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x29, x30, [sp], 64
	ret
	.p2align 3
.L59:
	ldr	x2, [x21, 64]
	ldr	w3, [x19, 152]
	ldr	w0, [x19, 160]
	ldr	w1, [x2]
	and	w1, w1, -16777216
	str	w1, [x2]
	add	w0, w3, w0, lsr 3
	ldr	x2, [x21, 72]
	and	w0, w0, 15
	ldr	w1, [x19, 168]
	ldr	w3, [x2]
	add	w1, w1, 24
	bfi	w3, w1, 0, 24
	str	w3, [x2]
	ldr	x2, [x21, 72]
	ldr	w1, [x19, 160]
	ldrb	w3, [x2, 3]
	and	w1, w1, 7
	add	w0, w1, w0, lsl 3
	bfi	w3, w0, 0, 7
	strb	w3, [x2, 3]
	cbz	x22, .L40
	ldr	w1, [x19, 160]
	ubfx	x1, x1, 3, 29
	add	x0, x22, x1
	ldrb	w2, [x22, x1]
	ldrb	w1, [x0, 7]
	ldrb	w7, [x0, 5]
	ldrb	w6, [x0, 4]
	ldrb	w5, [x0, 3]
	ldrb	w4, [x0, 2]
	ldrb	w3, [x0, 1]
	str	w1, [sp, 8]
	ldr	x1, .LC24
	ldrb	w0, [x0, 6]
	str	w0, [sp]
	mov	w0, 8
	bl	dprint_vfmw
	ldr	w2, [x19, 168]
	ldr	w1, [x19, 160]
	add	w0, w2, 7
	cmp	w2, wzr
	csel	w0, w0, w2, lt
	ubfx	x1, x1, 3, 29
	asr	w0, w0, 3
	add	x0, x1, x0, sxtw
	ldr	x1, .LC26
	sub	x0, x0, #8
	add	x8, x22, x0
	ldrb	w2, [x22, x0]
	ldrb	w0, [x8, 7]
	ldrb	w7, [x8, 5]
	ldrb	w6, [x8, 4]
	ldrb	w5, [x8, 3]
	ldrb	w4, [x8, 2]
	ldrb	w3, [x8, 1]
	str	w0, [sp, 8]
	ldrb	w0, [x8, 6]
	str	w0, [sp]
	mov	w0, 9
	bl	dprint_vfmw
.L40:
	ldr	x1, [x21, 80]
	ldr	w0, [x1]
	and	w0, w0, -16777216
	str	w0, [x1]
	ldr	x1, [x21, 88]
	ldr	w0, [x1]
	and	w0, w0, -16777216
	str	w0, [x1]
	ldr	x1, [x21, 88]
	ldrb	w0, [x1, 3]
	and	w0, w0, -128
	strb	w0, [x1, 3]
	b	.L43
.L58:
	ldr	x3, .LC22
.L56:
	ldr	x2, .LC18
	mov	w0, 0
	ldr	x1, .LC20
	bl	dprint_vfmw
	mov	w0, -1
	b	.L37
.L57:
	ldr	x3, .LC17
	b	.L56
	.size	MP2HAL_V5R6C1_MakeDnMsg, .-MP2HAL_V5R6C1_MakeDnMsg
	.align	3
.LC17:
	.xword	.LC16
	.align	3
.LC18:
	.xword	.LANCHOR0
	.align	3
.LC20:
	.xword	.LC19
	.align	3
.LC22:
	.xword	.LC21
	.align	3
.LC24:
	.xword	.LC23
	.align	3
.LC26:
	.xword	.LC25
	.align	3
.LC28:
	.xword	.LC27
	.align	3
.LC30:
	.xword	.LC29
	.align	3
.LC32:
	.xword	.LC31
	.align	3
.LC34:
	.xword	.LC33
	.align	3
.LC36:
	.xword	.LC35
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	MP2HAL_V5R6C1_CfgReg
	.type	MP2HAL_V5R6C1_CfgReg, %function
MP2HAL_V5R6C1_CfgReg:
	stp	x29, x30, [sp, -96]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	stp	x21, x22, [sp, 32]
	stp	x23, x24, [sp, 48]
	str	x25, [sp, 64]
	mov	x22, x0
	mov	x0, x30
	mov	w19, w2
	mov	x23, x1
	mov	x21, x3
	mov	x20, x4
	bl	_mcount
	str	wzr, [x29, 92]
	cmp	w19, wzr
	bgt	.L91
	beq	.L64
	cmp	w19, 1
	bne	.L92
	mov	w0, -104529920
.L65:
	ldr	x1, [x23]
	cbz	x1, .L93
.L66:
	ldrh	w2, [x22, 146]
	mov	x3, x20
	ldrh	w1, [x22, 150]
	ldr	w0, [x29, 92]
	mul	w1, w1, w2
	mov	w2, w19
	sub	w1, w1, #1
	bfi	w0, w1, 0, 20
	str	w0, [x29, 92]
	ubfx	x1, x0, 24, 6
	ubfx	x0, x0, 16, 6
	orr	w1, w1, 64
	orr	w0, w0, 64
	orr	w1, w1, 1
	strb	w0, [x29, 94]
	and	w0, w1, -3
	strb	w0, [x29, 95]
	mov	w0, 8
	ldr	w24, [x29, 92]
	mov	w1, w24
	bl	MFDE_ConfigReg
	ldr	x1, .LC55
	mov	w2, w24
	mov	w0, 3
	add	x24, x22, 45056
	bl	dprint_vfmw
	ldr	w1, [x24, 244]
	mov	w0, 0
	ldrh	w2, [x22, 150]
	bfi	w0, w1, 4, 1
	mov	w1, 3
	orr	w0, w0, 64
	cmp	w2, 120
	strb	w1, [x29, 92]
	strb	w0, [x29, 93]
	strh	w1, [x29, 94]
	bgt	.L94
	ldrb	w0, [x29, 95]
	mov	w1, 0
	str	wzr, [x24, 240]
	and	w0, w0, -33
	strb	w0, [x29, 95]
.L68:
	ldrb	w2, [x29, 95]
	mov	w0, 111
	strb	wzr, [x22, 144]
	mov	x3, x20
	and	w0, w2, w0
	mov	w2, w19
	bfi	w0, w1, 6, 1
	strb	w0, [x29, 95]
	mov	w0, 12
	ldr	w25, [x29, 92]
	mov	w1, w25
	bl	MFDE_ConfigReg
	ldr	x1, .LC45
	mov	w2, w25
	mov	w0, 3
	bl	dprint_vfmw
	ldr	w1, [x23, 72]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 16
	and	w1, w1, -16
	bl	MFDE_ConfigReg
	ldr	w1, [x23, 56]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 20
	and	w1, w1, -16
	bl	MFDE_ConfigReg
	str	wzr, [x29, 92]
	ldr	w5, [x24, 236]
	mov	w3, 0
	mov	w4, -1
	cbz	w5, .L70
	.p2align 2
.L84:
	sxtw	x2, w3
	lsl	x1, x2, 2
	sub	x1, x1, x2
	lsl	x1, x1, 2
	sub	x1, x1, x2
	add	x1, x22, x1, lsl 2
	mov	x0, x1
	ldr	w2, [x1, 236]
	cbz	w2, .L74
	ldr	w1, [x1, 244]
	and	w2, w2, -16
	cmp	w1, wzr
	ble	.L74
	cmp	w4, w2
	csel	w4, w4, w2, ls
.L74:
	ldr	w1, [x0, 240]
	cbz	w1, .L71
	ldr	w0, [x0, 248]
	and	w1, w1, -16
	cmp	w0, wzr
	ble	.L71
	cmp	w4, w1
	csel	w4, w4, w1, ls
.L71:
	add	w3, w3, 1
	cmp	w3, w5
	bne	.L84
	cmn	w4, #1
	beq	.L70
	mov	w1, w4
	str	w4, [x21]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 24
	str	w4, [x29, 92]
	bl	MFDE_ConfigReg
	ldrh	w1, [x22, 150]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 4
	cmp	w1, 120
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
	ldr	w1, [x22, 188]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 96
	and	w1, w1, -16
	bl	MFDE_ConfigReg
	ldr	w1, [x22, 208]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 100
	bl	MFDE_ConfigReg
	ldr	w1, [x22, 212]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 104
	bl	MFDE_ConfigReg
	ldr	w2, [x22, 212]
	mov	w0, 3
	ldr	x1, .LC49
	bl	dprint_vfmw
	str	wzr, [x29, 92]
	ldp	w1, w2, [x22, 192]
	mov	w0, 0
	mov	x3, x20
	bfi	w0, w2, 0, 2
	mov	w2, w19
	bfi	w0, w1, 2, 2
	strb	w0, [x29, 92]
	mov	w0, 148
	ldr	w21, [x29, 92]
	mov	w1, w21
	bl	MFDE_ConfigReg
	ldr	x1, .LC51
	mov	w2, w21
	mov	w0, 3
	bl	dprint_vfmw
	str	wzr, [x29, 92]
	strb	wzr, [x29, 92]
	mov	x3, x20
	mov	w2, w19
	mov	w0, 152
	ldr	w1, [x29, 92]
	bl	MFDE_ConfigReg
	ldr	w21, [x22, 220]
	mov	x3, x20
	mov	w2, w19
	mov	w1, w21
	mov	w0, 108
	bl	MFDE_ConfigReg
	ldr	x1, .LC53
	mov	w2, w21
	mov	w0, 3
	bl	dprint_vfmw
	mov	x3, x20
	mov	w2, w19
	mov	w1, -1
	mov	w0, 32
	bl	MFDE_ConfigReg
	ldr	x25, [sp, 64]
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	mov	w0, 0
	ldp	x29, x30, [sp], 96
	ret
	.p2align 3
.L92:
	ldr	x1, .LC41
	mov	w0, 0
	bl	dprint_vfmw
	mov	w0, -1
.L87:
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldr	x25, [sp, 64]
	ldp	x29, x30, [sp], 96
	ret
	.p2align 3
.L94:
	ldrb	w0, [x29, 95]
	ldr	w1, [x24, 240]
	and	w0, w0, -33
	strb	w0, [x29, 95]
	and	w1, w1, 1
	b	.L68
	.p2align 3
.L64:
	mov	w0, -121438208
	b	.L65
	.p2align 3
.L93:
	bl	MEM_Phy2Vir
	cbz	x0, .L67
	str	x0, [x23]
	b	.L66
.L91:
	ldr	x2, .LC37
	mov	w4, 0
	ldr	x1, .LC39
	mov	w3, w19
	add	x2, x2, 24
	mov	w0, 0
	bl	dprint_vfmw
	mov	w0, -1
	b	.L87
.L70:
	ldr	x1, .LC47
	mov	w2, -1
	mov	w0, 0
	bl	dprint_vfmw
	str	wzr, [x21]
	mov	w0, -1
	b	.L87
.L67:
	ldr	x1, .LC43
	mov	w0, 0
	bl	dprint_vfmw
	mov	w0, -1
	b	.L87
	.size	MP2HAL_V5R6C1_CfgReg, .-MP2HAL_V5R6C1_CfgReg
	.align	3
.LC37:
	.xword	.LANCHOR0
	.align	3
.LC39:
	.xword	.LC38
	.align	3
.LC41:
	.xword	.LC40
	.align	3
.LC43:
	.xword	.LC42
	.align	3
.LC45:
	.xword	.LC44
	.align	3
.LC47:
	.xword	.LC46
	.align	3
.LC49:
	.xword	.LC48
	.align	3
.LC51:
	.xword	.LC50
	.align	3
.LC53:
	.xword	.LC52
	.align	3
.LC55:
	.xword	.LC54
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	MP2HAL_V5R6C1_CfgDnMsg
	.type	MP2HAL_V5R6C1_CfgDnMsg, %function
MP2HAL_V5R6C1_CfgDnMsg:
	sub	sp, sp, #112
	stp	x29, x30, [sp, 16]
	add	x29, sp, 16
	stp	x19, x20, [sp, 32]
	stp	x21, x22, [sp, 48]
	stp	x23, x24, [sp, 64]
	str	x25, [sp, 80]
	mov	x20, x1
	mov	x19, x0
	mov	x0, x30
	mov	w21, w3
	bl	_mcount
	str	wzr, [x29, 92]
	ldr	w0, [x20, 72]
	bl	MEM_Phy2Vir
	mov	x22, x0
	cbz	x0, .L123
	ldrh	w1, [x19, 150]
	cmp	w1, 512
	bhi	.L124
	ldrh	w2, [x19, 146]
	cmp	w2, 512
	bhi	.L125
	ldrh	w0, [x29, 94]
	sub	w2, w2, #1
	ldr	w4, [x19, 176]
	sub	w1, w1, #1
	ldrh	w3, [x29, 92]
	bfi	w0, w2, 0, 9
	strh	w0, [x29, 94]
	lsr	x0, x0, 8
	bfi	w3, w1, 0, 9
	bfi	w0, w4, 1, 1
	strh	w3, [x29, 92]
	mov	w2, 0
	strb	w0, [x29, 95]
	mov	w0, 0
	mov	w3, 0
	mov	w5, 0
	ldr	w1, [x29, 92]
	mov	w4, 0
	str	w1, [x22]
	mov	w1, 0
	ldrb	w6, [x19]
	bfi	w0, w6, 0, 3
	ldrb	w6, [x19, 3]
	bfi	w2, w6, 0, 2
	ldrb	w6, [x19, 5]
	bfi	w3, w6, 0, 1
	strb	w3, [x29, 92]
	ldrb	w3, [x19, 2]
	bfi	w0, w3, 3, 1
	ldrb	w3, [x19, 1]
	bfi	w0, w3, 4, 1
	strb	w0, [x29, 95]
	mov	w0, 0
	mov	w3, 0
	ldrb	w6, [x19, 4]
	bfi	w2, w6, 2, 1
	strb	w2, [x29, 93]
	ldrb	w2, [x19, 7]
	bfi	w5, w2, 0, 1
	strb	w5, [x29, 94]
	ldr	w2, [x29, 92]
	str	w2, [x22, 4]
	ldrb	w2, [x19, 14]
	ldrb	w5, [x19, 15]
	bfi	w0, w2, 0, 4
	ldrb	w2, [x19, 12]
	bfi	w4, w5, 0, 4
	ldrb	w5, [x19, 13]
	bfi	w1, w2, 0, 4
	ldrb	w2, [x19, 6]
	strb	w0, [x29, 93]
	mov	w0, w1
	bfi	w3, w5, 0, 4
	bfi	w0, w2, 7, 1
	strb	w3, [x29, 94]
	mov	w2, 0
	strb	w0, [x29, 95]
	mov	w3, 0
	strb	w4, [x29, 92]
	mov	w1, 0
	mov	w0, 0
	ldr	w4, [x29, 92]
	str	w4, [x22, 8]
	ldrb	w5, [x19, 11]
	ldrb	w4, [x19, 10]
	bfi	w3, w5, 0, 2
	ldrb	w5, [x19, 9]
	bfi	w2, w4, 0, 1
	ldrb	w4, [x19, 8]
	strb	w3, [x29, 92]
	bfi	w1, w5, 0, 1
	strb	w2, [x29, 93]
	bfi	w0, w4, 0, 1
	strb	w1, [x29, 94]
	strb	w0, [x29, 95]
	ldr	w0, [x29, 92]
	str	w0, [x22, 12]
	ldr	w0, [x19, 180]
	and	w0, w0, -16
	str	w0, [x22, 16]
	ldr	w0, [x19, 184]
	and	w0, w0, -16
	str	w0, [x22, 20]
	ldr	w0, [x19, 200]
	and	w0, w0, -16
	str	w0, [x22, 24]
	ldr	w0, [x19, 224]
	and	w0, w0, -16
	str	w0, [x22, 28]
	str	w0, [x29, 92]
	ldr	w0, [x19, 152]
	bl	MEM_Phy2Vir
	mov	x23, x0
	ldr	w0, [x19, 156]
	bl	MEM_Phy2Vir
	mov	x25, x0
	ldr	w0, [x19, 172]
	cbz	w0, .L126
	ldp	w0, w24, [x19, 160]
	ldp	w1, w2, [x19, 152]
	add	w0, w1, w0, lsr 3
	add	w24, w2, w24, lsr 3
	and	w1, w0, -16
	and	w2, w24, -16
	sub	w1, w1, w2
	mov	w2, 0
	bfi	w2, w1, 0, 24
	str	w2, [x22, 32]
	mov	w2, 0
	and	w0, w0, 15
	ldr	w1, [x19, 168]
	bfi	w2, w1, 0, 24
	ldr	w1, [x19, 160]
	str	w2, [x29, 92]
	and	w1, w1, 7
	add	w0, w1, w0, lsl 3
	mov	w1, 0
	bfi	w1, w0, 0, 7
	strb	w1, [x29, 95]
	ldr	w0, [x29, 92]
	str	w0, [x22, 36]
	cbz	x23, .L103
	ldr	w1, [x19, 160]
	ubfx	x1, x1, 3, 29
	add	x0, x23, x1
	ldrb	w2, [x23, x1]
	ldrb	w1, [x0, 7]
	ldrb	w7, [x0, 5]
	ldrb	w6, [x0, 4]
	ldrb	w5, [x0, 3]
	ldrb	w4, [x0, 2]
	ldrb	w3, [x0, 1]
	str	w1, [sp, 8]
	ldr	x1, .LC66
	ldrb	w0, [x0, 6]
	str	w0, [sp]
	mov	w0, 8
	bl	dprint_vfmw
	ldr	w2, [x19, 168]
	ldr	w1, [x19, 160]
	cmp	w2, wzr
	add	w0, w2, 7
	csel	w0, w0, w2, lt
	ubfx	x1, x1, 3, 29
	asr	w0, w0, 3
	add	x0, x1, x0, sxtw
	ldr	x1, .LC67
	sub	x0, x0, #8
	add	x8, x23, x0
	ldrb	w2, [x23, x0]
	ldrb	w0, [x8, 7]
	ldrb	w3, [x8, 1]
	ldrb	w7, [x8, 5]
	ldrb	w6, [x8, 4]
	ldrb	w5, [x8, 3]
	ldrb	w4, [x8, 2]
	str	w0, [sp, 8]
	ldrb	w0, [x8, 6]
	str	w0, [sp]
	mov	w0, 9
	bl	dprint_vfmw
	ldr	w3, [x19, 152]
	mov	w0, 22
	ldr	w2, [x19, 168]
	ldr	x1, .LC68
	add	w2, w3, w2
	bl	dprint_vfmw
.L103:
	str	wzr, [x22, 40]
	and	w24, w24, 15
	mov	w3, 0
	mov	w2, 0
	ldr	w0, [x19, 164]
	ldr	w1, [x19, 172]
	and	w0, w0, 7
	add	w1, w1, 24
	add	w0, w0, w24, lsl 3
	bfi	w3, w1, 0, 24
	str	w3, [x29, 92]
	bfi	w2, w0, 0, 7
	strb	w2, [x29, 95]
	ldr	w0, [x29, 92]
	str	w0, [x22, 44]
	cbz	x25, .L104
	ldr	w1, [x19, 164]
	ubfx	x1, x1, 3, 29
	add	x0, x25, x1
	ldrb	w2, [x25, x1]
	ldrb	w1, [x0, 7]
	ldrb	w7, [x0, 5]
	ldrb	w6, [x0, 4]
	ldrb	w5, [x0, 3]
	ldrb	w4, [x0, 2]
	ldrb	w3, [x0, 1]
	str	w1, [sp, 8]
	ldr	x1, .LC69
	ldrb	w0, [x0, 6]
	str	w0, [sp]
	mov	w0, 8
	bl	dprint_vfmw
	ldr	w2, [x19, 172]
	ldr	w1, [x19, 164]
	add	w0, w2, 7
	cmp	w2, wzr
	csel	w0, w0, w2, lt
	ubfx	x1, x1, 3, 29
	asr	w0, w0, 3
	add	x0, x1, x0, sxtw
	ldr	x1, .LC70
	sub	x0, x0, #8
	add	x8, x25, x0
	ldrb	w2, [x25, x0]
	ldrb	w0, [x8, 7]
	ldrb	w7, [x8, 5]
	ldrb	w6, [x8, 4]
	ldrb	w5, [x8, 3]
	ldrb	w4, [x8, 2]
	ldrb	w3, [x8, 1]
	str	w0, [sp, 8]
	ldrb	w0, [x8, 6]
	str	w0, [sp]
	mov	w0, 9
	bl	dprint_vfmw
.L104:
	add	x11, x22, 128
	mov	w6, 0
	.p2align 2
.L102:
	mov	w0, w6
	add	w12, w6, 16
	mov	x4, x11
.L105:
	add	w3, w0, 16
	add	w2, w0, 32
	add	w1, w0, 48
	add	x5, x19, x0, sxtw
	add	x3, x19, x3, sxtw
	add	x2, x19, x2, sxtw
	add	x1, x19, x1, sxtw
	add	w0, w0, 8
	ldrb	w10, [x5, 80]
	cmp	w12, w0
	ldrb	w9, [x3, 80]
	ldrb	w7, [x1, 80]
	ldrb	w8, [x2, 80]
	strb	w10, [x29, 92]
	strb	w9, [x29, 93]
	strb	w8, [x29, 94]
	strb	w7, [x29, 95]
	ldr	w7, [x29, 92]
	str	w7, [x4, -64]
	ldrb	w1, [x1, 16]
	ldrb	w5, [x5, 16]
	ldrb	w3, [x3, 16]
	ldrb	w2, [x2, 16]
	strb	w5, [x29, 92]
	strb	w3, [x29, 93]
	strb	w2, [x29, 94]
	strb	w1, [x29, 95]
	ldr	w1, [x29, 92]
	str	w1, [x4], 4
	bne	.L105
	add	w6, w6, 1
	add	x11, x11, 8
	cmp	w6, 8
	bne	.L102
	ldr	w0, [x20, 1164]
	and	w0, w0, -16
	str	w0, [x22, 192]
	str	w0, [x29, 92]
	ldr	w23, [x20, 72]
	and	w23, w23, -16
	add	w23, w23, 256
	mov	w0, w23
	bl	MEM_Phy2Vir
	cbz	x0, .L127
	mov	x1, x0
	mov	w3, w21
	mov	w2, w23
	mov	x0, x19
	str	w23, [x22, 252]
	str	w23, [x29, 92]
	bl	MP2HAL_V5R6C1_WriteSliceMsg
	ldr	x1, .LC73
	mov	w0, 0
	ldr	w1, [x1]
	tbnz	x1, 4, .L128
.L97:
	add	sp, x29, 0
	ldr	x25, [sp, 64]
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x29, x30, [sp], 96
	ret
	.p2align 3
.L126:
	ldr	w0, [x19, 160]
	mov	w4, 0
	ldr	w1, [x19, 152]
	mov	w3, 0
	str	wzr, [x22, 32]
	add	w0, w1, w0, lsr 3
	ldr	w2, [x19, 168]
	and	w0, w0, 15
	ldr	w1, [x19, 160]
	add	w2, w2, 24
	and	w1, w1, 7
	bfi	w4, w2, 0, 24
	add	w0, w1, w0, lsl 3
	str	w4, [x29, 92]
	bfi	w3, w0, 0, 7
	strb	w3, [x29, 95]
	ldr	w0, [x29, 92]
	str	w0, [x22, 36]
	cbz	x23, .L101
	ldr	w1, [x19, 160]
	ubfx	x1, x1, 3, 29
	add	x0, x23, x1
	ldrb	w2, [x23, x1]
	ldrb	w1, [x0, 7]
	ldrb	w7, [x0, 5]
	ldrb	w6, [x0, 4]
	ldrb	w5, [x0, 3]
	ldrb	w4, [x0, 2]
	ldrb	w3, [x0, 1]
	str	w1, [sp, 8]
	ldr	x1, .LC64
	ldrb	w0, [x0, 6]
	str	w0, [sp]
	mov	w0, 8
	bl	dprint_vfmw
	ldr	w2, [x19, 168]
	ldr	w1, [x19, 160]
	add	w0, w2, 7
	cmp	w2, wzr
	csel	w0, w0, w2, lt
	ubfx	x1, x1, 3, 29
	asr	w0, w0, 3
	add	x0, x1, x0, sxtw
	ldr	x1, .LC65
	sub	x0, x0, #8
	add	x8, x23, x0
	ldrb	w2, [x23, x0]
	ldrb	w0, [x8, 7]
	ldrb	w7, [x8, 5]
	ldrb	w6, [x8, 4]
	ldrb	w5, [x8, 3]
	ldrb	w4, [x8, 2]
	ldrb	w3, [x8, 1]
	str	w0, [sp, 8]
	ldrb	w0, [x8, 6]
	str	w0, [sp]
	mov	w0, 9
	bl	dprint_vfmw
.L101:
	str	wzr, [x22, 40]
	str	wzr, [x29, 92]
	strb	wzr, [x29, 95]
	ldr	w0, [x29, 92]
	str	w0, [x22, 44]
	b	.L104
	.p2align 3
.L128:
	ldr	x4, .LC74
	mov	w0, 4
	ldr	w3, [x20, 72]
	mov	x19, x22
	ldr	x1, .LC76
	mov	w20, 0
	ldr	w2, [x4]
	add	w2, w2, 1
	str	w2, [x4]
	bl	dprint_vfmw
	ldr	x21, .LC78
	.p2align 2
.L108:
	ldp	w4, w5, [x19, 4]
	ldr	w6, [x19, 12]
	mov	w2, w20
	ldr	w3, [x19], 16
	mov	w0, 4
	mov	x1, x21
	add	w20, w20, w0
	bl	dprint_vfmw
	cmp	w20, 64
	bne	.L108
	ldr	x1, .LC80
	mov	w0, 4
	bl	dprint_vfmw
	add	sp, x29, 0
	mov	w0, 0
	ldr	x25, [sp, 64]
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x29, x30, [sp], 96
	ret
.L125:
	ldr	x2, .LC60
	ldr	x3, .LC63
.L122:
	ldr	x1, .LC61
	mov	w0, 0
	add	x2, x2, 48
	bl	dprint_vfmw
	mov	w0, -1
	b	.L97
.L124:
	ldr	x2, .LC60
	ldr	x3, .LC62
	b	.L122
.L127:
	ldr	x1, .LC72
	bl	dprint_vfmw
	mov	w0, -1
	b	.L97
.L123:
	ldr	x2, .LC60
	ldr	x3, .LC59
	b	.L122
	.size	MP2HAL_V5R6C1_CfgDnMsg, .-MP2HAL_V5R6C1_CfgDnMsg
	.align	3
.LC59:
	.xword	.LC58
	.align	3
.LC60:
	.xword	.LANCHOR0
	.align	3
.LC61:
	.xword	.LC19
	.align	3
.LC62:
	.xword	.LC16
	.align	3
.LC63:
	.xword	.LC21
	.align	3
.LC64:
	.xword	.LC23
	.align	3
.LC65:
	.xword	.LC25
	.align	3
.LC66:
	.xword	.LC27
	.align	3
.LC67:
	.xword	.LC29
	.align	3
.LC68:
	.xword	.LC31
	.align	3
.LC69:
	.xword	.LC33
	.align	3
.LC70:
	.xword	.LC35
	.align	3
.LC72:
	.xword	.LC71
	.align	3
.LC73:
	.xword	g_PrintEnable
	.align	3
.LC74:
	.xword	.LANCHOR1
	.align	3
.LC76:
	.xword	.LC75
	.align	3
.LC78:
	.xword	.LC77
	.align	3
.LC80:
	.xword	.LC79
	.global	_mcount
	.align	2
	.p2align 3,,7
	.global	MP2HAL_V5R6C1_StartDec
	.type	MP2HAL_V5R6C1_StartDec, %function
MP2HAL_V5R6C1_StartDec:
	stp	x29, x30, [sp, -80]!
	add	x29, sp, 0
	stp	x19, x20, [sp, 16]
	stp	x21, x22, [sp, 32]
	str	x23, [sp, 48]
	mov	x20, x0
	mov	x0, x30
	mov	w22, w1
	mov	x23, x2
	bl	_mcount
	ldr	x21, .LC81
	sxtw	x0, w22
	cmp	w22, wzr
	lsl	x19, x0, 6
	sub	x19, x19, x0
	lsl	x19, x19, 2
	sub	x0, x19, x0
	add	x19, x19, x0, lsl 2
	add	x19, x19, x21
	bgt	.L140
	bne	.L138
	ldr	x0, [x21]
	cbz	x0, .L141
.L135:
	ldr	x6, .LC87
	mov	x4, x23
	add	x3, x29, 76
	mov	w2, 0
	mov	x1, x19
	mov	x0, x20
	ldr	w5, [x6]
	add	w5, w5, 1
	str	w5, [x6]
	bl	MP2HAL_V5R6C1_CfgReg
	mov	w21, w0
	cbnz	w0, .L142
	ldr	w3, [x29, 76]
	mov	w2, 0
	mov	x1, x19
	mov	x0, x20
	bl	MP2HAL_V5R6C1_CfgDnMsg
.L131:
	mov	w0, w21
	ldr	x23, [sp, 48]
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x29, x30, [sp], 80
	ret
	.p2align 3
.L141:
	mov	w0, -121438208
	bl	MEM_Phy2Vir
	cbz	x0, .L136
	str	x0, [x21]
	b	.L135
	.p2align 3
.L140:
	ldr	x2, .LC82
	mov	w4, 0
	ldr	x1, .LC83
	mov	w3, w22
	add	x2, x2, 72
	mov	w0, 0
	mov	w21, -1
	bl	dprint_vfmw
	b	.L131
	.p2align 3
.L142:
	ldr	x1, .LC89
	mov	w0, 1
	mov	w21, -1
	bl	dprint_vfmw
	b	.L131
	.p2align 3
.L138:
	ldr	x1, .LC85
	mov	w0, 0
	mov	w21, -1
	bl	dprint_vfmw
	b	.L131
.L136:
	ldr	x1, .LC86
	mov	w0, 0
	mov	w21, -1
	bl	dprint_vfmw
	b	.L131
	.size	MP2HAL_V5R6C1_StartDec, .-MP2HAL_V5R6C1_StartDec
	.align	3
.LC81:
	.xword	g_HwMem
	.align	3
.LC82:
	.xword	.LANCHOR0
	.align	3
.LC83:
	.xword	.LC38
	.align	3
.LC85:
	.xword	.LC84
	.align	3
.LC86:
	.xword	.LC42
	.align	3
.LC87:
	.xword	.LANCHOR2
	.align	3
.LC89:
	.xword	.LC88
	.section	.rodata
	.align	3
.LANCHOR0 = . + 0
	.type	__func__.12075, %object
	.size	__func__.12075, 24
__func__.12075:
	.string	"MP2HAL_V5R6C1_MakeDnMsg"
	.type	__func__.12114, %object
	.size	__func__.12114, 21
__func__.12114:
	.string	"MP2HAL_V5R6C1_CfgReg"
	.zero	3
	.type	__func__.12137, %object
	.size	__func__.12137, 23
__func__.12137:
	.string	"MP2HAL_V5R6C1_CfgDnMsg"
	.zero	1
	.type	__func__.12028, %object
	.size	__func__.12028, 23
__func__.12028:
	.string	"MP2HAL_V5R6C1_StartDec"
	.data
	.align	2
.LANCHOR2 = . + 0
	.type	FrameNum, %object
	.size	FrameNum, 4
FrameNum:
	.word	-1
	.section	.rodata.str1.8,"aMS",%progbits,1
	.align	3
.LC0:
	ASCII(.string	"D0 = %#x \n" )
	.zero	5
.LC2:
	ASCII(.string	"D1 = %#x \n" )
	.zero	5
.LC4:
	ASCII(.string	"D2 = %#x \n" )
	.zero	5
.LC6:
	ASCII(.string	"D3 = %#x \n" )
	.zero	5
.LC8:
	ASCII(.string	"D4 = %#x \n" )
	.zero	5
.LC10:
	ASCII(.string	"D5 = %#x \n" )
	.zero	5
.LC12:
	ASCII(.string	"D6 = %#x \n" )
	.zero	5
.LC14:
	ASCII(.string	"D7 = %#x \n" )
	.zero	5
.LC16:
	ASCII(.string	"picture width out of range" )
	.zero	5
.LC19:
	ASCII(.string	"%s: %s\n" )
.LC21:
	ASCII(.string	"picture height out of range" )
	.zero	4
.LC23:
	ASCII(.string	"Stream Head (8bytes): 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n" )
	.zero	1
.LC25:
	ASCII(.string	"Stream Tail (8bytes): 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n" )
	.zero	1
.LC27:
	ASCII(.string	"1p Stream Head (8bytes): 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n" )
	.zero	6
.LC29:
	ASCII(.string	"1p Stream Tail (8bytes): 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n" )
	.zero	6
.LC31:
	ASCII(.string	"1p last phy addr = 0x%x\n" )
	.zero	7
.LC33:
	ASCII(.string	"2p Stream Head (8bytes): 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n" )
	.zero	6
.LC35:
	ASCII(.string	"2p Stream Tail (8bytes): 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n" )
	.zero	6
.LC38:
	ASCII(.string	"%s: VdhId(%d) > %d\n" )
	.zero	4
.LC40:
	ASCII(.string	"VdhId is wrong! MP2HAL_V200R003_CfgReg\n" )
.LC42:
	ASCII(.string	"vdm register virtual address not mapped, reset failed!\n" )
.LC44:
	ASCII(.string	"MPEG2  VREG_V5R6C1_BASIC_CFG1= 0x%x\n" )
	.zero	3
.LC46:
	ASCII(.string	"stream_base_addr = %#x\n" )
.LC48:
	ASCII(.string	"MPEG2  VREG_V5R6C1_UVOFFSET_1D= 0x%x\n" )
	.zero	2
.LC50:
	ASCII(.string	"MPEG2  VREG_V5R6C1_REF_PIC_TYPE= 0x%x\n" )
	.zero	1
.LC52:
	ASCII(.string	"HEAD_INF_OFFSET = 0x%x\n" )
.LC54:
	ASCII(.string	"MPEG2  VREG_V5R6C1_BASIC_CFG0= 0x%x\n" )
	.zero	3
.LC58:
	ASCII(.string	"can not map down msg virtual address!" )
	.zero	2
.LC71:
	ASCII(.string	"Map SlcDnMsgPhyAddr to SlcDnMsgVirAddr is NULL \n" )
	.zero	7
.LC75:
	ASCII(.string	"\n*****No.%2d Down Msg (phy addr: %#8x) *****\n" )
	.zero	2
.LC77:
	ASCII(.string	"\n0x%02x 0x%08x 0x%08x 0x%08x 0x%08x\n" )
	.zero	3
.LC79:
	ASCII(.string	"\n***** Down Msg print finished *****\n" )
	.zero	2
.LC84:
	ASCII(.string	"VdhId is wrong! MP2HAL_V200R003_StartDec\n" )
	.zero	6
.LC88:
	ASCII(.string	"MP2HAL_V200R003_CfgReg ERROR!\n" )
	.bss
	.align	2
.LANCHOR1 = . + 0
	.type	num.12148, %object
	.size	num.12148, 4
num.12148:
	.zero	4
	.ident	"GCC: (gcc-linaro-5.1-2015.08 + glibc-2.22 (Build by czyong Wed Mar  9 18:57:48 CST 2016)) 5.1.1 20150608"
	.section	.note.GNU-stack,"",%progbits
