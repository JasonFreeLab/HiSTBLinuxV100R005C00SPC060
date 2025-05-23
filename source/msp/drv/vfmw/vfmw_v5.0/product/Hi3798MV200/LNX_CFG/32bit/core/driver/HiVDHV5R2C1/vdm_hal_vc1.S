#include "hi_asm_define.h"
	.arch armv7-a
	.fpu softvfp
	.eabi_attribute 20, 1
	.eabi_attribute 21, 1
	.eabi_attribute 23, 3
	.eabi_attribute 24, 1
	.eabi_attribute 25, 1
	.eabi_attribute 26, 2
	.eabi_attribute 30, 2
	.eabi_attribute 34, 0
	.eabi_attribute 18, 4
	.file	"vdm_hal_vc1.c"
	.text
	.align	2
	.global	VC1HAL_V5R2C1_InitHal
	.type	VC1HAL_V5R2C1_InitHal, %function
VC1HAL_V5R2C1_InitHal:
	UNWIND(.fnstart)
	@ args = 0, pretend = 0, frame = 0
	@ frame_needed = 1, uses_anonymous_args = 0
	UNWIND(.movsp ip)
	mov	ip, sp
	stmfd	sp!, {fp, ip, lr, pc}
	UNWIND(.pad #4)
	UNWIND(.save {fp, ip, lr})
	UNWIND(.setfp fp, ip, #-4)
	sub	fp, ip, #4
	mov	r0, #0
	ldmfd	sp, {fp, sp, pc}
	UNWIND(.fnend)
	.size	VC1HAL_V5R2C1_InitHal, .-VC1HAL_V5R2C1_InitHal
	.align	2
	.global	VC1HAL_V5R2C1_CfgSliceMsg
	.type	VC1HAL_V5R2C1_CfgSliceMsg, %function
VC1HAL_V5R2C1_CfgSliceMsg:
	UNWIND(.fnstart)
	@ args = 0, pretend = 0, frame = 40
	@ frame_needed = 1, uses_anonymous_args = 0
	UNWIND(.movsp ip)
	mov	ip, sp
	stmfd	sp!, {r4, r5, r6, r7, r8, r9, r10, fp, ip, lr, pc}
	UNWIND(.pad #4)
	UNWIND(.save {r4, r5, r6, r7, r8, r9, r10, fp, ip, lr})
	UNWIND(.setfp fp, ip, #-4)
	sub	fp, ip, #4
	UNWIND(.pad #44)
	sub	sp, sp, #44
	ldr	r3, [r1, #60]
	mov	r10, r0
	mov	r0, r3
	str	r3, [fp, #-56]
	bl	MEM_Phy2Vir
	subs	r5, r0, #0
	beq	.L63
	ldrb	r3, [r10, #4]	@ zero_extendqisi2
	cmp	r3, #2
	beq	.L64
	ldr	lr, [r10, #96]
	add	r3, r10, #12288
	add	r2, r10, #84
	str	r3, [fp, #-48]
	bic	r8, lr, #15
	str	r8, [r3, #172]
	ldrb	r0, [r10, #70]	@ zero_extendqisi2
	str	r2, [fp, #-52]
	cmp	r0, #0
	ble	.L2
	mov	r4, #0
	add	r6, r10, #144
	mov	r7, r4
	cmp	r7, #0
	mov	ip, r5
	mov	r1, r4
	bne	.L26
.L65:
	cmp	r0, #1
	ldr	r4, [r10, #108]
	beq	.L48
	ble	.L28
	ldr	r3, [r10, #156]
	cmp	r4, r3
	blt	.L28
	ldr	r3, [fp, #-52]
	mov	r1, #1
	b	.L29
.L31:
	ldr	r2, [r3, #72]
	cmp	r4, r2
	blt	.L41
.L29:
	add	r1, r1, #1
	add	r3, r3, #48
	cmp	r1, r0
	bne	.L31
.L60:
	mov	r2, #0
.L32:
	mov	r3, #0
.L27:
	ldr	r5, [r6, #-44]
	rsb	lr, r8, lr
	ldr	r0, [r6, #-40]
	add	r3, r3, r4, lsl #16
	add	r5, r5, lr, lsl #3
	bic	lr, lr, #15
	add	r7, r7, #1
	add	r6, r6, #48
	add	r0, r0, r5, lsl #25
	str	r0, [ip]
	str	lr, [ip, #4]
	mov	r0, #0
	str	r0, [ip, #8]
	add	ip, ip, #256
	str	r0, [ip, #-244]
	str	r3, [ip, #-240]
	str	r2, [ip, #-4]
	ldrb	r0, [r10, #70]	@ zero_extendqisi2
	cmp	r0, r7
	ble	.L2
	ldr	r3, [fp, #-48]
	cmp	r7, #0
	ldr	lr, [r6, #-48]
	ldr	r8, [r3, #172]
	beq	.L65
.L26:
	ldr	r5, [fp, #-52]
	mov	r3, r1, asl #6
	add	r2, r1, #1
	sub	r3, r3, r1, asl #4
	add	r3, r5, r3
	cmp	r2, r0
	ldr	r5, [r3, #24]
	bge	.L33
	ldr	r9, [r3, #72]
	cmp	r5, r9
	blt	.L33
	mov	r9, r1
	b	.L34
.L36:
	ldr	r1, [r3, #72]
	cmp	r5, r1
	blt	.L61
.L34:
	add	r2, r2, #1
	add	r3, r3, #48
	cmp	r2, r0
	bne	.L36
	mov	r1, r9
	mov	r2, #0
.L37:
	add	r3, r4, #1
	mov	r4, r5
	b	.L27
.L33:
	cmp	r2, r0
	moveq	r2, #0
	beq	.L37
.L61:
	ldr	r3, [fp, #-56]
	mov	r1, r2
	add	r2, r3, r2, lsl #8
	b	.L37
.L28:
	cmp	r0, #1
	beq	.L49
	mov	r1, #1
.L41:
	ldr	r3, [fp, #-56]
	add	r2, r3, r1, lsl #8
	b	.L32
.L48:
	mov	r2, r7
	mov	r3, r7
	b	.L27
.L64:
	ldr	r0, [r10, #96]
	add	r3, r10, #12288
	add	r2, r10, #84
	str	r2, [fp, #-84]
	mov	lr, r3
	str	r3, [fp, #-48]
	str	r0, [r3, #172]
	ldrb	r2, [r10, #70]	@ zero_extendqisi2
	cmp	r2, #0
	ble	.L5
	mov	r3, r10
	mov	r1, #0
.L8:
	ldr	ip, [r3, #88]
	cmp	ip, #0
	beq	.L6
	ldr	ip, [r3, #112]
	cmp	ip, r0
	strcc	ip, [lr, #172]
	movcc	r0, ip
	bcc	.L7
.L6:
	ldr	ip, [r3, #96]
	cmp	ip, r0
	strcc	ip, [lr, #172]
	movcc	r0, ip
.L7:
	add	r1, r1, #1
	add	r3, r3, #48
	cmp	r1, r2
	bne	.L8
.L5:
	ldr	r3, [fp, #-48]
	bic	r0, r0, #15
	ldr	r1, .L67
	str	r0, [r3, #172]
	mov	r0, #4
	bl	dprint_vfmw
	ldrb	lr, [r10, #70]	@ zero_extendqisi2
	cmp	lr, #0
	ble	.L2
	mov	r9, #0
	mov	r6, r5
	mov	r8, r10
	str	r10, [fp, #-80]
	mov	r5, r9
	mov	r10, r9
.L24:
	ldr	r3, [fp, #-48]
	ldr	r2, [r8, #96]
	ldr	r1, [r8, #88]
	ldr	r3, [r3, #172]
	ldr	r4, [r8, #100]
	cmp	r1, #0
	rsb	r2, r3, r2
	ldr	r0, [r8, #104]
	and	ip, r2, #15
	bic	r2, r2, #15
	str	r2, [fp, #-52]
	add	ip, r4, ip, lsl #3
	beq	.L43
	ldr	r7, [r8, #112]
	ldr	r2, [r8, #116]
	rsb	r7, r3, r7
	ldr	r3, [r8, #120]
	str	r7, [fp, #-68]
	add	r2, r2, r7, lsl #3
	add	r3, r3, r2, lsl #25
	str	r3, [fp, #-60]
	str	r3, [fp, #-64]
.L11:
	cmp	r10, #0
	bne	.L12
	ldr	r3, [fp, #-80]
	cmp	lr, #1
	ldr	r9, [r3, #108]
	beq	.L44
	ble	.L14
	ldr	r3, [r3, #156]
	cmp	r9, r3
	blt	.L58
	ldr	r3, [fp, #-84]
	mov	r5, #1
	b	.L16
.L17:
	ldr	r2, [r3, #72]
	cmp	r9, r2
	blt	.L66
.L16:
	add	r5, r5, #1
	add	r3, r3, #48
	cmp	r5, lr
	bne	.L17
	mov	r3, #0
	mov	r4, r3
.L18:
	mov	r2, #0
	str	r2, [fp, #-76]
.L13:
	add	r2, r0, ip, lsl #25
	ldr	r1, .L67+4
	str	r2, [r6]
	mov	r0, #4
	str	r3, [fp, #-72]
	bl	dprint_vfmw
	ldr	r3, [fp, #-52]
	mov	r0, #4
	ldr	r1, .L67+8
	add	r10, r10, #1
	add	r8, r8, #48
	add	r6, r6, #256
	str	r3, [r6, #-252]
	mov	r2, r3
	bl	dprint_vfmw
	ldr	r3, [fp, #-64]
	ldr	r2, [fp, #-60]
	mov	r0, #4
	ldr	r1, .L67+12
	str	r3, [r6, #-248]
	bl	dprint_vfmw
	ldr	r3, [fp, #-68]
	mov	r2, r7
	ldr	r1, .L67+16
	mov	r0, #4
	str	r3, [r6, #-244]
	bl	dprint_vfmw
	ldr	r3, [fp, #-76]
	ldr	r1, .L67+20
	mov	r0, #4
	add	r2, r3, r9, lsl #16
	str	r2, [r6, #-240]
	bl	dprint_vfmw
	ldr	r3, [fp, #-72]
	mov	r2, r4
	ldr	r1, .L67+24
	mov	r0, #4
	str	r3, [r6, #-4]
	bl	dprint_vfmw
	ldr	r3, [fp, #-80]
	ldrb	lr, [r3, #70]	@ zero_extendqisi2
	cmp	lr, r10
	bgt	.L24
.L2:
	sub	sp, fp, #40
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, r10, fp, sp, pc}
.L12:
	ldr	r2, [fp, #-84]
	mov	r3, r5, asl #6
	add	r4, r5, #1
	sub	r3, r3, r5, asl #4
	add	r3, r2, r3
	cmp	r4, lr
	ldr	r2, [r3, #24]
	bge	.L19
	ldr	r1, [r3, #72]
	cmp	r2, r1
	bge	.L20
	b	.L19
.L22:
	ldr	r1, [r3, #72]
	cmp	r2, r1
	blt	.L59
.L20:
	add	r4, r4, #1
	add	r3, r3, #48
	cmp	r4, lr
	bne	.L22
.L47:
	mov	r3, #0
	mov	r4, r3
.L23:
	add	r1, r9, #1
	mov	r9, r2
	str	r1, [fp, #-76]
	b	.L13
.L19:
	cmp	r4, lr
	beq	.L47
.L59:
	ldr	r3, [fp, #-56]
	mov	r5, r4
	add	r4, r3, r4, lsl #8
	mov	r3, r4
	b	.L23
.L66:
	mov	r4, r5, asl #8
.L39:
	ldr	r3, [fp, #-56]
	add	r4, r4, r3
	mov	r3, r4
	b	.L18
.L43:
	str	r1, [fp, #-68]
	mov	r7, r1
	str	r1, [fp, #-64]
	str	r1, [fp, #-60]
	b	.L11
.L44:
	mov	r3, r10
	str	r10, [fp, #-76]
	mov	r4, r10
	b	.L13
.L58:
	mov	r4, #256
	mov	r5, #1
	b	.L39
.L63:
	ldr	r2, .L67+28
	ldr	r1, .L67+32
	sub	sp, fp, #40
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, r10, fp, sp, lr}
	b	dprint_vfmw
.L14:
	bne	.L58
	mov	r5, lr
	mov	r3, r10
	mov	r4, r10
	b	.L18
.L49:
	mov	r1, r0
	b	.L60
.L68:
	.align	2
.L67:
	.word	.LC1
	.word	.LC2
	.word	.LC3
	.word	.LC4
	.word	.LC5
	.word	.LC6
	.word	.LC7
	.word	.LANCHOR0
	.word	.LC0
	UNWIND(.fnend)
	.size	VC1HAL_V5R2C1_CfgSliceMsg, .-VC1HAL_V5R2C1_CfgSliceMsg
	.align	2
	.global	VC1HAL_V5R2C1_CfgReg
	.type	VC1HAL_V5R2C1_CfgReg, %function
VC1HAL_V5R2C1_CfgReg:
	UNWIND(.fnstart)
	@ args = 0, pretend = 0, frame = 8
	@ frame_needed = 1, uses_anonymous_args = 0
	UNWIND(.movsp ip)
	mov	ip, sp
	stmfd	sp!, {r4, r5, r6, r7, r8, r9, fp, ip, lr, pc}
	UNWIND(.pad #4)
	UNWIND(.save {r4, r5, r6, r7, r8, r9, fp, ip, lr})
	UNWIND(.setfp fp, ip, #-4)
	sub	fp, ip, #4
	UNWIND(.pad #16)
	sub	sp, sp, #16
	subs	r4, r2, #0
	mov	r9, #0
	mov	r7, r0
	mov	r8, r1
	mov	r5, r3
	str	r9, [fp, #-40]
	bgt	.L76
	add	r6, r0, #12288
	mov	r0, #8
	ldr	r1, [r6, #164]
	ubfx	r1, r1, #0, #20
	orr	r1, r1, #1090519040
	bl	MFDE_ConfigReg
	ldrh	r1, [fp, #-38]
	ldr	r0, [r6, #264]
	mov	r2, #1
	ldrh	ip, [r7, #78]
	bfi	r1, r2, #0, #12
	ldrb	r3, [fp, #-39]	@ zero_extendqisi2
	cmp	ip, #120
	mov	ip, r1, lsr #8
	bfi	r3, r0, #4, #1
	ldrb	r0, [fp, #-40]	@ zero_extendqisi2
	bfi	ip, r9, #4, #1
	strh	r1, [fp, #-38]	@ movhi
	bfi	r0, r2, #0, #4
	strb	ip, [fp, #-37]
	strb	r0, [fp, #-40]
	movgt	r0, r9
	strleb	r2, [r7, #71]
	movle	r0, r2
	strgtb	r9, [r7, #71]
	and	r3, r3, #223
	ldrgt	r9, [r6, #260]
	orr	r3, r3, #192
	strle	r9, [r6, #260]
	mov	r2, r4
	ldrb	r1, [fp, #-37]	@ zero_extendqisi2
	andgt	r9, r9, #1
	strb	r3, [fp, #-39]
	mov	r3, r5
	bfi	r1, r0, #5, #1
	mov	r0, #12
	bfi	r1, r9, #6, #1
	bfc	r1, #7, #1
	strb	r1, [fp, #-37]
	ldr	r1, [fp, #-40]
	str	r1, [r6, #168]
	bl	MFDE_ConfigReg
	mov	r3, r5
	mov	r2, r4
	ldr	r1, [r8, #56]
	mov	r0, #16
	bl	MFDE_ConfigReg
	mov	r3, r5
	mov	r2, r4
	ldr	r1, [r8, #40]
	mov	r0, #20
	bl	MFDE_ConfigReg
	ldr	ip, [r6, #172]
	mov	r3, r5
	mov	r2, r4
	mov	r0, #24
	mov	r1, ip
	str	ip, [fp, #-40]
	bl	MFDE_ConfigReg
	ldrh	r1, [r7, #78]
	mov	r3, r5
	mov	r2, r4
	cmp	r1, #256
	mov	r0, #4
	movhi	r1, #0
	movls	r1, #1
	bl	SCD_ConfigReg
	movw	r1, #3075
	mov	r3, r5
	mov	r2, r4
	mov	r0, #60
	movt	r1, 48
	bl	MFDE_ConfigReg
	movw	r1, #3075
	mov	r3, r5
	mov	r2, r4
	mov	r0, #64
	movt	r1, 48
	bl	MFDE_ConfigReg
	movw	r1, #3075
	mov	r3, r5
	mov	r2, r4
	mov	r0, #68
	movt	r1, 48
	bl	MFDE_ConfigReg
	movw	r1, #3075
	mov	r3, r5
	mov	r2, r4
	mov	r0, #72
	movt	r1, 48
	bl	MFDE_ConfigReg
	movw	r1, #3075
	mov	r3, r5
	mov	r2, r4
	mov	r0, #76
	movt	r1, 48
	bl	MFDE_ConfigReg
	movw	r1, #3075
	mov	r3, r5
	mov	r2, r4
	mov	r0, #80
	movt	r1, 48
	bl	MFDE_ConfigReg
	movw	r1, #3075
	mov	r3, r5
	mov	r2, r4
	mov	r0, #84
	movt	r1, 48
	bl	MFDE_ConfigReg
	mov	r3, r5
	mov	r2, r4
	ldr	r1, [r6, #228]
	mov	r0, #96
	bl	MFDE_ConfigReg
	ldr	r1, [r6, #176]
	mov	r3, r5
	mov	r2, r4
	mov	r0, #100
	str	r1, [r6, #232]
	bl	MFDE_ConfigReg
	ldr	r1, [r6, #184]
	mov	r3, r5
	mov	r2, r4
	mov	r0, #104
	str	r1, [r6, #236]
	bl	MFDE_ConfigReg
	mov	r3, r5
	mov	r2, r4
	ldrb	r1, [r7, #69]	@ zero_extendqisi2
	mov	r0, #152
	bl	MFDE_ConfigReg
	mov	r3, r5
	mov	r2, r4
	ldrb	r1, [r7, #68]	@ zero_extendqisi2
	mov	r0, #148
	bl	MFDE_ConfigReg
	mov	r3, r5
	mov	r2, r4
	ldr	r1, [r6, #192]
	mov	r0, #108
	bl	MFDE_ConfigReg
	mov	r3, r5
	mov	r2, r4
	mvn	r1, #0
	mov	r0, #32
	bl	MFDE_ConfigReg
	mov	r0, #0
	sub	sp, fp, #36
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, fp, sp, pc}
.L76:
	str	r9, [sp]
	mov	r3, r4
	mov	r0, r9
	ldr	r2, .L77
	ldr	r1, .L77+4
	bl	dprint_vfmw
	mvn	r0, #0
	sub	sp, fp, #36
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, fp, sp, pc}
.L78:
	.align	2
.L77:
	.word	.LANCHOR0+28
	.word	.LC8
	UNWIND(.fnend)
	.size	VC1HAL_V5R2C1_CfgReg, .-VC1HAL_V5R2C1_CfgReg
	.align	2
	.global	VC1HAL_V5R2C1_CfgDnMsg
	.type	VC1HAL_V5R2C1_CfgDnMsg, %function
VC1HAL_V5R2C1_CfgDnMsg:
	UNWIND(.fnstart)
	@ args = 0, pretend = 0, frame = 8
	@ frame_needed = 1, uses_anonymous_args = 0
	UNWIND(.movsp ip)
	mov	ip, sp
	stmfd	sp!, {r4, r5, r6, r7, r8, fp, ip, lr, pc}
	UNWIND(.pad #4)
	UNWIND(.save {r4, r5, r6, r7, r8, fp, ip, lr})
	UNWIND(.setfp fp, ip, #-4)
	sub	fp, ip, #4
	UNWIND(.pad #12)
	sub	sp, sp, #12
	mov	r4, r0
	ldr	r0, [r1, #56]
	mov	r6, r1
	bl	MEM_Phy2Vir
	subs	r3, r0, #0
	beq	.L83
	ldrb	r1, [r4, #4]	@ zero_extendqisi2
	mov	r2, #0
	ldrb	r0, [r4, #3]	@ zero_extendqisi2
	mov	r5, #0
	ldrb	ip, [r4, #5]	@ zero_extendqisi2
	bfi	r2, r1, #4, #2
	str	r5, [fp, #-40]
	bfi	r2, r0, #0, #2
	mov	r1, #0
	strb	r2, [fp, #-40]
	bfi	r1, ip, #6, #2
	strb	r1, [fp, #-39]
	ldr	r1, [fp, #-40]
	mov	r2, #0
	str	r5, [fp, #-40]
	mov	ip, r2
	mov	r0, r2
	str	r1, [r3]
	ldrh	lr, [r4, #80]
	ldrh	r1, [r4, #78]
	strb	lr, [fp, #-38]
	strb	r1, [fp, #-40]
	mov	r1, r2
	ldr	lr, [fp, #-40]
	str	r5, [fp, #-40]
	str	lr, [r3, #4]
	ldrb	lr, [r4, #8]	@ zero_extendqisi2
	bfi	r2, lr, #2, #1
	ldrb	lr, [r4, #6]	@ zero_extendqisi2
	bfi	r2, lr, #0, #1
	ldrb	lr, [r4, #9]	@ zero_extendqisi2
	bfi	r2, lr, #3, #1
	ldrb	lr, [r4, #7]	@ zero_extendqisi2
	bfi	r2, lr, #1, #1
	ldrb	lr, [r4, #10]	@ zero_extendqisi2
	bfi	r2, lr, #4, #2
	ldrb	lr, [r4, #11]	@ zero_extendqisi2
	bfi	r2, lr, #6, #2
	strb	r2, [fp, #-40]
	ldr	r2, [fp, #-40]
	mov	lr, ip
	str	r5, [fp, #-40]
	str	r2, [r3, #8]
	ldrb	r2, [r4, #15]	@ zero_extendqisi2
	ldrb	r7, [r4, #13]	@ zero_extendqisi2
	bfi	ip, r2, #4, #2
	mov	r2, ip
	ldrb	ip, [r4, #14]	@ zero_extendqisi2
	bfi	r2, r7, #1, #1
	bfi	r2, ip, #2, #1
	ldrb	ip, [r4, #12]	@ zero_extendqisi2
	bfi	r2, ip, #0, #1
	strb	r2, [fp, #-40]
	ldr	r2, [fp, #-40]
	mov	ip, r0
	str	r2, [r3, #12]
	ldrb	r7, [r4, #18]	@ zero_extendqisi2
	ldrb	r2, [r4, #19]	@ zero_extendqisi2
	bfi	r0, r7, #0, #5
	strb	r0, [fp, #-38]
	bfi	r1, r2, #0, #1
	ldrb	r0, [r4, #17]	@ zero_extendqisi2
	strb	r1, [fp, #-37]
	mov	r2, lr
	ldrb	r1, [r4, #16]	@ zero_extendqisi2
	bfi	lr, r0, #0, #5
	strb	lr, [fp, #-39]
	mov	lr, ip
	bfi	ip, r1, #0, #5
	strb	ip, [fp, #-40]
	ldr	r0, [fp, #-40]
	mov	ip, r2
	mov	r1, r2
	str	r5, [fp, #-40]
	str	r0, [r3, #16]
	ldrb	r0, [r4, #24]	@ zero_extendqisi2
	ldrb	r7, [r4, #23]	@ zero_extendqisi2
	bfi	r2, r0, #4, #1
	ldrb	r0, [r4, #20]	@ zero_extendqisi2
	ldrb	r8, [r4, #25]	@ zero_extendqisi2
	bfi	r2, r7, #0, #2
	ldrb	r7, [r4, #22]	@ zero_extendqisi2
	and	r0, r0, #1
	bfi	r2, r8, #6, #1
	ldrb	r8, [r4, #21]	@ zero_extendqisi2
	bfi	r0, r7, #2, #2
	ldrb	r7, [r4, #26]	@ zero_extendqisi2
	strb	r2, [fp, #-39]
	bfi	lr, r7, #0, #4
	mov	r2, r0
	strb	lr, [fp, #-38]
	bfi	r2, r8, #1, #1
	strb	r2, [fp, #-40]
	mov	r0, ip
	ldr	r2, [fp, #-40]
	str	r5, [fp, #-40]
	str	r2, [r3, #20]
	ldrb	r2, [r4, #27]	@ zero_extendqisi2
	ldrb	lr, [r4, #28]	@ zero_extendqisi2
	and	r2, r2, #7
	bfi	r2, lr, #4, #2
	strb	r2, [fp, #-40]
	ldr	lr, [fp, #-40]
	mov	r2, ip
	str	r5, [fp, #-40]
	str	lr, [r3, #24]
	ldrb	lr, [r4, #34]	@ zero_extendqisi2
	bfi	ip, lr, #6, #1
	ldrb	lr, [r4, #33]	@ zero_extendqisi2
	bfi	ip, lr, #4, #2
	strb	ip, [fp, #-39]
	ldrb	lr, [r4, #30]	@ zero_extendqisi2
	mov	ip, r1
	bfi	r1, lr, #1, #1
	ldrb	lr, [r4, #29]	@ zero_extendqisi2
	bfi	r1, lr, #0, #1
	ldrb	lr, [r4, #31]	@ zero_extendqisi2
	bfi	r1, lr, #2, #2
	ldrb	lr, [r4, #32]	@ zero_extendqisi2
	strb	r1, [fp, #-40]
	ldrh	r1, [fp, #-40]
	bfi	r1, lr, #4, #5
	strh	r1, [fp, #-40]	@ movhi
	ldr	r1, [fp, #-40]
	str	r5, [fp, #-40]
	str	r1, [r3, #28]
	ldrb	r1, [r4, #35]	@ zero_extendqisi2
	ldrb	lr, [r4, #36]	@ zero_extendqisi2
	and	r1, r1, #1
	ldrb	r7, [r4, #39]	@ zero_extendqisi2
	bfi	r1, lr, #1, #1
	ldrb	lr, [r4, #37]	@ zero_extendqisi2
	bfi	r1, lr, #2, #1
	ldrb	lr, [r4, #38]	@ zero_extendqisi2
	bfi	r1, lr, #4, #2
	ldrb	lr, [r4, #40]	@ zero_extendqisi2
	bfi	r1, r7, #6, #2
	strb	r1, [fp, #-40]
	bfi	r0, lr, #0, #2
	strb	r0, [fp, #-39]
	ldr	lr, [fp, #-40]
	mov	r1, r2
	mov	r0, r2
	str	r5, [fp, #-40]
	str	lr, [r3, #32]
	ldrb	lr, [r4, #46]	@ zero_extendqisi2
	bfi	r2, lr, #5, #1
	ldrb	lr, [r4, #42]	@ zero_extendqisi2
	bfi	r2, lr, #1, #1
	ldrb	lr, [r4, #44]	@ zero_extendqisi2
	bfi	r2, lr, #3, #1
	ldrb	lr, [r4, #41]	@ zero_extendqisi2
	bfi	r2, lr, #0, #1
	ldrb	lr, [r4, #43]	@ zero_extendqisi2
	bfi	r2, lr, #2, #1
	ldrb	lr, [r4, #47]	@ zero_extendqisi2
	bfi	r2, lr, #6, #1
	ldrb	lr, [r4, #45]	@ zero_extendqisi2
	bfi	r2, lr, #4, #1
	strb	r2, [fp, #-40]
	ldr	lr, [fp, #-40]
	add	r2, r4, #12288
	str	r5, [fp, #-40]
	str	lr, [r3, #36]
	ldrb	r7, [r4, #50]	@ zero_extendqisi2
	ldrb	lr, [r4, #49]	@ zero_extendqisi2
	bfi	ip, r7, #0, #7
	strb	ip, [fp, #-38]
	ldrb	ip, [r4, #48]	@ zero_extendqisi2
	bfi	r0, lr, #0, #3
	strb	r0, [fp, #-39]
	mov	r0, r1
	bfi	r1, ip, #0, #3
	strb	r1, [fp, #-40]
	ldr	ip, [fp, #-40]
	mov	r1, r0
	str	r5, [fp, #-40]
	str	ip, [r3, #40]
	ldrb	lr, [r4, #53]	@ zero_extendqisi2
	ldrb	r7, [r4, #54]	@ zero_extendqisi2
	ldrb	ip, [r4, #51]	@ zero_extendqisi2
	and	lr, lr, #3
	bfi	lr, r7, #4, #1
	strb	lr, [fp, #-39]
	ldrb	lr, [r4, #52]	@ zero_extendqisi2
	and	ip, ip, #7
	bfi	ip, lr, #4, #2
	strb	ip, [fp, #-40]
	ldr	lr, [fp, #-40]
	mov	ip, r0
	str	lr, [r3, #44]
	ldr	lr, [r2, #84]
	str	lr, [r3, #48]
	ldr	lr, [r2, #88]
	str	lr, [r3, #52]
	ldr	lr, [r2, #92]
	str	lr, [r3, #56]
	ldrb	lr, [r4, #55]	@ zero_extendqisi2
	ldrb	r7, [r4, #56]	@ zero_extendqisi2
	bfi	r0, lr, #4, #1
	ldrb	lr, [r4, #57]	@ zero_extendqisi2
	bfi	r0, r7, #5, #3
	strb	r0, [fp, #-38]
	ldrh	r0, [r4, #72]
	and	lr, lr, #1
	ldrb	r7, [r4, #58]	@ zero_extendqisi2
	strh	r0, [fp, #-40]	@ movhi
	bfi	lr, r7, #1, #3
	strb	lr, [fp, #-37]
	ldr	r0, [fp, #-40]
	str	r0, [r3, #60]
	ldr	r0, [r2, #96]
	str	r0, [r3, #64]
	ldr	r0, [r2, #100]
	str	r0, [r3, #68]
	ldr	r0, [r2, #104]
	str	r0, [r3, #72]
	ldr	r0, [r2, #108]
	str	r0, [r3, #76]
	ldr	r0, [r2, #112]
	str	r0, [r3, #80]
	ldr	r0, [r6, #1144]
	str	r0, [r3, #84]
	ldr	r0, [r6, #1148]
	str	r0, [r3, #88]
	ldr	r0, [r6, #1156]
	str	r0, [r3, #92]
	ldr	r0, [r6, #1160]
	str	r0, [r3, #96]
	ldr	r0, [r6, #1176]
	str	r0, [r3, #104]
	ldrh	lr, [r4, #74]
	ldrh	r0, [r4, #76]
	strh	lr, [fp, #-40]	@ movhi
	strh	r0, [fp, #-38]	@ movhi
	ldr	r0, [fp, #-40]
	str	r5, [fp, #-40]
	str	r0, [r3, #108]
	ldrb	r0, [r4, #59]	@ zero_extendqisi2
	ldrb	lr, [r4, #61]	@ zero_extendqisi2
	bfi	r1, r0, #4, #1
	ldrb	r0, [r4, #60]	@ zero_extendqisi2
	bfi	r1, r0, #5, #1
	ldrb	r0, [r4, #63]	@ zero_extendqisi2
	bfi	r1, lr, #6, #1
	strb	r1, [fp, #-38]
	bfi	ip, r0, #1, #3
	ldrb	r0, [r4, #62]	@ zero_extendqisi2
	mov	r1, ip
	bfi	r1, r0, #0, #1
	strb	r1, [fp, #-37]
	ldr	r1, [fp, #-40]
	str	r1, [r3, #112]
	ldr	r1, [r2, #116]
	str	r1, [r3, #116]
	ldr	r1, [r2, #120]
	str	r1, [r3, #120]
	ldr	r1, [r2, #124]
	str	r1, [r3, #124]
	ldr	r1, [r2, #128]
	str	r1, [r3, #128]
	ldr	r1, [r2, #132]
	str	r1, [r3, #132]
	ldr	r1, [r2, #136]
	str	r1, [r3, #136]
	ldr	r1, [r2, #140]
	str	r1, [r3, #140]
	ldr	r2, [r2, #144]
	str	r2, [r3, #144]
	ldr	r2, [r6, #60]
	str	r2, [r3, #252]
	ldr	r0, [r6, #1176]
	str	r2, [fp, #-40]
	bl	MEM_Phy2Vir
	cmp	r0, r5
	beq	.L84
	ldr	r3, .L85
	mov	r2, #3072
	ldr	r1, [r4, #64]
	ldr	r3, [r3, #52]
	blx	r3
	mov	r0, r5
.L81:
	sub	sp, fp, #32
	ldmfd	sp, {r4, r5, r6, r7, r8, fp, sp, pc}
.L83:
	ldr	r2, .L85+4
	ldr	r1, .L85+8
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L81
.L84:
	ldr	r2, .L85+4
	ldr	r1, .L85+12
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L81
.L86:
	.align	2
.L85:
	.word	vfmw_Osal_Func_Ptr_S
	.word	.LANCHOR0+52
	.word	.LC0
	.word	.LC9
	UNWIND(.fnend)
	.size	VC1HAL_V5R2C1_CfgDnMsg, .-VC1HAL_V5R2C1_CfgDnMsg
	.align	2
	.global	VC1HAL_V5R2C1_StartDec
	.type	VC1HAL_V5R2C1_StartDec, %function
VC1HAL_V5R2C1_StartDec:
	UNWIND(.fnstart)
	@ args = 0, pretend = 0, frame = 0
	@ frame_needed = 1, uses_anonymous_args = 0
	UNWIND(.movsp ip)
	mov	ip, sp
	stmfd	sp!, {r4, r5, r6, r7, r8, r9, fp, ip, lr, pc}
	UNWIND(.pad #4)
	UNWIND(.save {r4, r5, r6, r7, r8, r9, fp, ip, lr})
	UNWIND(.setfp fp, ip, #-4)
	sub	fp, ip, #4
	movw	r5, #1228
	ldr	r6, .L102
	mul	r5, r5, r1
	cmp	r1, #0
	mov	r8, r1
	mov	r9, r2
	mov	r4, r0
	add	r7, r5, r6
	bgt	.L97
	cmp	r0, #0
	beq	.L98
	ldrh	r3, [r0, #78]
	cmp	r3, #512
	ldrhi	r3, .L102+4
	bhi	.L96
	ldrh	r3, [r0, #80]
	cmp	r3, #512
	bhi	.L99
	ldr	r0, [r7, #56]
	bl	MEM_Phy2Vir
	cmp	r0, #0
	beq	.L100
	ldr	r3, [r5, r6]
	cmp	r3, #0
	beq	.L101
.L94:
	mov	r1, r7
	mov	r0, r4
	bl	VC1HAL_V5R2C1_CfgSliceMsg
	mov	r3, r9
	mov	r2, r8
	mov	r1, r7
	mov	r0, r4
	bl	VC1HAL_V5R2C1_CfgReg
	mov	r1, r7
	mov	r0, r4
	bl	VC1HAL_V5R2C1_CfgDnMsg
	mov	r0, #0
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, fp, sp, pc}
.L101:
	mov	r0, #0
	movt	r0, 63683
	bl	MEM_Phy2Vir
	subs	r3, r0, #0
	beq	.L95
	str	r3, [r5, r6]
	b	.L94
.L99:
	ldr	r3, .L102+8
.L96:
	ldr	r2, .L102+12
	mov	r0, #0
	ldr	r1, .L102+16
	bl	dprint_vfmw
	mvn	r0, #0
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, fp, sp, pc}
.L97:
	ldr	r1, .L102+20
	mov	r0, #0
	bl	dprint_vfmw
	mvn	r0, #0
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, fp, sp, pc}
.L98:
	ldr	r3, .L102+24
	ldr	r2, .L102+12
	ldr	r1, .L102+16
	bl	dprint_vfmw
	mvn	r0, #0
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, fp, sp, pc}
.L100:
	ldr	r3, .L102+28
	ldr	r2, .L102+12
	ldr	r1, .L102+16
	bl	dprint_vfmw
	mvn	r0, #0
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, fp, sp, pc}
.L95:
	ldr	r1, .L102+32
	bl	dprint_vfmw
	mvn	r0, #0
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, fp, sp, pc}
.L103:
	.align	2
.L102:
	.word	g_HwMem
	.word	.LC13
	.word	.LC14
	.word	.LANCHOR0+76
	.word	.LC12
	.word	.LC10
	.word	.LC11
	.word	.LC15
	.word	.LC16
	UNWIND(.fnend)
	.size	VC1HAL_V5R2C1_StartDec, .-VC1HAL_V5R2C1_StartDec
	.section	.rodata
	.align	2
.LANCHOR0 = . + 0
	.type	__func__.14462, %object
	.size	__func__.14462, 26
__func__.14462:
	.ascii	"VC1HAL_V5R2C1_CfgSliceMsg\000"
	.space	2
	.type	__func__.14470, %object
	.size	__func__.14470, 21
__func__.14470:
	.ascii	"VC1HAL_V5R2C1_CfgReg\000"
	.space	3
	.type	__func__.14478, %object
	.size	__func__.14478, 23
__func__.14478:
	.ascii	"VC1HAL_V5R2C1_CfgDnMsg\000"
	.space	1
	.type	__func__.14393, %object
	.size	__func__.14393, 23
__func__.14393:
	.ascii	"VC1HAL_V5R2C1_StartDec\000"
	.section	.rodata.str1.4,"aMS",%progbits,1
	.align	2
.LC0:
	ASCII(.ascii	"%s: pMsgBase = NULL\012\000" )
	.space	3
.LC1:
	ASCII(.ascii	"pVc1DecParam->SlcNum = %d\012\000" )
	.space	1
.LC2:
	ASCII(.ascii	"D0 = 0x%08x\012\000" )
	.space	3
.LC3:
	ASCII(.ascii	"D1 = 0x%08x\012\000" )
	.space	3
.LC4:
	ASCII(.ascii	"D2 = 0x%08x\012\000" )
	.space	3
.LC5:
	ASCII(.ascii	"D3 = 0x%08x\012\000" )
	.space	3
.LC6:
	ASCII(.ascii	"D4 = 0x%08x\012\000" )
	.space	3
.LC7:
	ASCII(.ascii	"D63 = 0x%08x\012\000" )
	.space	2
.LC8:
	ASCII(.ascii	"%s: VdhId(%d) > %d\012\000" )
.LC9:
	ASCII(.ascii	"%s: u8Tmp = NULL\012\000" )
	.space	2
.LC10:
	ASCII(.ascii	"VdhId is wrong! VC1HAL_V200R003_StartDec\012\000" )
	.space	2
.LC11:
	ASCII(.ascii	"point of picture para null\012\000" )
.LC12:
	ASCII(.ascii	"%s: %s\012\000" )
.LC13:
	ASCII(.ascii	"picture width out of range\000" )
	.space	1
.LC14:
	ASCII(.ascii	"picture height out of range\000" )
.LC15:
	ASCII(.ascii	"can not map down msg virtual address!\000" )
	.space	2
.LC16:
	ASCII(.ascii	"vdm register virtual address not mapped, reset fail" )
	ASCII(.ascii	"ed!\012\000" )
	.ident	"GCC: (gcc-4.9.4 + glibc-2.27 Build by czyong Mon Jul  2 18:10:52 CST 2018) 4.9.4"
	.section	.note.GNU-stack,"",%progbits
