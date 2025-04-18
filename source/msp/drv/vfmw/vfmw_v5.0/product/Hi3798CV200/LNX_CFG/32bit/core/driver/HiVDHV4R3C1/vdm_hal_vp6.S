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
	.file	"vdm_hal_vp6.c"
	.text
	.align	2
	.global	VP6HAL_V4R3C1_InitHal
	.type	VP6HAL_V4R3C1_InitHal, %function
VP6HAL_V4R3C1_InitHal:
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
	.size	VP6HAL_V4R3C1_InitHal, .-VP6HAL_V4R3C1_InitHal
	.align	2
	.global	VP6HAL_V4R3C1_CfgReg
	.type	VP6HAL_V4R3C1_CfgReg, %function
VP6HAL_V4R3C1_CfgReg:
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
	UNWIND(.pad #20)
	sub	sp, sp, #20
	cmp	r2, #0
	mov	r6, r0
	mov	r7, r1
	mov	r5, r3
	beq	.L4
	cmp	r2, #1
	bne	.L10
	mov	r0, #0
	mov	r3, r2
	str	r0, [sp]
	ldr	r2, .L12
	ldr	r1, .L12+4
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L6
.L4:
	ldr	r3, [r1]
	cmp	r3, #0
	beq	.L11
.L7:
	ldrh	r0, [r6, #54]
	mov	r4, #0
	ldrh	r1, [r6, #56]
	mov	lr, r4
	mov	ip, #0
	bfi	ip, r4, #7, #1
	mov	r3, r5
	mov	r2, r4
	mul	r1, r1, r0
	mov	r0, #8
	sub	r1, r1, #1
	bfi	lr, r1, #0, #20
	str	lr, [fp, #-40]
	strb	ip, [fp, #-37]
	ldr	r8, [fp, #-40]
	mov	r1, r8
	bl	MFDE_ConfigReg
	mov	r2, r8
	ldr	r1, .L12+8
	mov	r0, #3
	bl	dprint_vfmw
	ldr	r2, [r6, #216]
	mov	r3, #0
	ldr	r1, [r6, #212]
	bfi	r3, r2, #4, #1
	mov	r2, #0
	and	r3, r3, #16
	bfi	r2, r1, #6, #1
	orr	r3, r3, #64
	mov	r1, #8192	@ movhi
	bfi	r2, r4, #7, #1
	strh	r1, [fp, #-38]	@ movhi
	mvn	r3, r3, asl #25
	strb	r2, [fp, #-37]
	mvn	r3, r3, lsr #25
	strb	r3, [fp, #-39]
	mov	r3, #10
	strb	r3, [fp, #-40]
	ldr	r8, [fp, #-40]
	mov	r3, r5
	mov	r2, r4
	mov	r0, #12
	mov	r1, r8
	bl	MFDE_ConfigReg
	mov	r2, r8
	ldr	r1, .L12+12
	mov	r0, #3
	bl	dprint_vfmw
	ldr	r8, [r7, #56]
	mov	r3, r5
	mov	r2, r4
	bic	r8, r8, #15
	mov	r0, #16
	mov	r1, r8
	bl	MFDE_ConfigReg
	mov	r2, r8
	ldr	r1, .L12+16
	mov	r0, #3
	bl	dprint_vfmw
	ldr	r8, [r7, #40]
	mov	r3, r5
	mov	r2, r4
	bic	r8, r8, #15
	mov	r0, #20
	mov	r1, r8
	bl	MFDE_ConfigReg
	mov	r2, r8
	ldr	r1, .L12+20
	mov	r0, #3
	bl	dprint_vfmw
	ldr	r8, [r6, #60]
	mov	r3, r5
	mov	r2, r4
	mov	r0, #24
	mov	r1, r8
	bl	MFDE_ConfigReg
	mov	r2, r8
	ldr	r1, .L12+24
	mov	r0, #3
	bl	dprint_vfmw
	ldr	r8, [r7, #1164]
	mov	r3, r5
	mov	r2, r4
	bic	r8, r8, #15
	mov	r0, #128
	mov	r1, r8
	bl	MFDE_ConfigReg
	mov	r2, r8
	ldr	r1, .L12+28
	mov	r0, #3
	bl	dprint_vfmw
	ldr	r1, [r7, #1168]
	str	r4, [fp, #-40]
	mov	r3, r5
	mov	r2, r4
	mov	r0, #132
	strh	r1, [fp, #-40]	@ movhi
	ldr	r7, [fp, #-40]
	mov	r1, r7
	bl	MFDE_ConfigReg
	mov	r2, r7
	ldr	r1, .L12+32
	mov	r0, #3
	bl	dprint_vfmw
	ldrh	r1, [r6, #54]
	mov	r2, r4
	mov	r3, r5
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
	ldr	r7, [r6, #176]
	mov	r3, r5
	mov	r2, r4
	bic	r7, r7, #15
	mov	r0, #96
	mov	r1, r7
	bl	MFDE_ConfigReg
	mov	r2, r7
	ldr	r1, .L12+36
	mov	r0, #3
	bl	dprint_vfmw
	ldr	r7, [r6, #192]
	mov	r3, r5
	mov	r2, r4
	mov	r0, #100
	mov	r1, r7
	bl	MFDE_ConfigReg
	mov	r2, r7
	ldr	r1, .L12+40
	mov	r0, #3
	bl	dprint_vfmw
	ldr	r7, [r6, #200]
	mov	r3, r5
	mov	r2, r4
	mov	r0, #104
	mov	r1, r7
	bl	MFDE_ConfigReg
	mov	r2, r7
	ldr	r1, .L12+44
	mov	r0, #3
	bl	dprint_vfmw
	ldr	r6, [r6, #208]
	mov	r3, r5
	mov	r2, r4
	mov	r0, #108
	mov	r1, r6
	bl	MFDE_ConfigReg
	mov	r2, r6
	ldr	r1, .L12+48
	mov	r0, #3
	bl	dprint_vfmw
	mov	r3, r5
	mov	r2, r4
	mov	r1, r4
	mov	r0, #152
	bl	MFDE_ConfigReg
	mov	r2, r4
	ldr	r1, .L12+52
	mov	r0, #3
	bl	dprint_vfmw
	mov	r0, #32
	mov	r3, r5
	mov	r2, r4
	mvn	r1, #0
	bl	MFDE_ConfigReg
	mov	r0, r4
.L6:
	sub	sp, fp, #32
	ldmfd	sp, {r4, r5, r6, r7, r8, fp, sp, pc}
.L10:
	ldr	r1, .L12+56
	mov	r0, #0
	bl	dprint_vfmw
	mvn	r0, #0
	sub	sp, fp, #32
	ldmfd	sp, {r4, r5, r6, r7, r8, fp, sp, pc}
.L11:
	mov	r0, #0
	movt	r0, 63683
	bl	MEM_Phy2Vir
	subs	r3, r0, #0
	strne	r3, [r7]
	bne	.L7
.L8:
	ldr	r1, .L12+60
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L6
.L13:
	.align	2
.L12:
	.word	.LANCHOR0
	.word	.LC1
	.word	.LC3
	.word	.LC4
	.word	.LC5
	.word	.LC6
	.word	.LC7
	.word	.LC8
	.word	.LC9
	.word	.LC10
	.word	.LC11
	.word	.LC12
	.word	.LC13
	.word	.LC14
	.word	.LC0
	.word	.LC2
	UNWIND(.fnend)
	.size	VP6HAL_V4R3C1_CfgReg, .-VP6HAL_V4R3C1_CfgReg
	.align	2
	.global	VP6HAL_V4R3C1_CfgDnMsg
	.type	VP6HAL_V4R3C1_CfgDnMsg, %function
VP6HAL_V4R3C1_CfgDnMsg:
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
	mov	r4, r0
	ldr	r0, [r1, #56]
	mov	r8, r1
	bl	MEM_Phy2Vir
	subs	r5, r0, #0
	beq	.L27
	ldr	r2, [r4, #64]
	mov	r6, #0
	mov	r3, #0
	str	r6, [fp, #-40]
	bfi	r3, r2, #0, #1
	strb	r3, [fp, #-40]
	ldr	r2, [fp, #-40]
	mov	r0, #4
	ldr	r1, .L35
	str	r2, [r5]
	bl	dprint_vfmw
	ldrh	r0, [r4, #54]
	ldrh	r1, [r4, #56]
	mov	r2, #0	@ movhi
	sub	r0, r0, #1
	mov	r3, r2	@ movhi
	sub	r1, r1, #1
	bfi	r2, r0, #0, #9
	bfi	r3, r1, #0, #9
	strh	r2, [fp, #-40]	@ movhi
	strh	r3, [fp, #-38]	@ movhi
	mov	r2, r2, lsr #8
	mov	r3, r3, lsr #8
	bfi	r2, r6, #1, #7
	bfi	r3, r6, #1, #7
	strb	r2, [fp, #-39]
	strb	r3, [fp, #-37]
	mov	r0, #4
	ldr	r2, [fp, #-40]
	ldr	r1, .L35+4
	str	r2, [r5, #4]
	bl	dprint_vfmw
	ldr	r3, [r4, #104]
	ldr	r2, [r4, #108]
	mov	r0, #4
	ldr	r1, [r4, #112]
	and	r3, r3, #31
	bfi	r3, r2, #5, #2
	ldr	r2, [r4, #76]
	ldr	ip, [r4, #72]
	mov	r1, r1, lsr #1
	and	r2, r2, #1
	bfi	r3, ip, #7, #1
	str	r6, [fp, #-40]
	bfi	r2, r1, #1, #1
	strb	r3, [fp, #-40]
	strb	r2, [fp, #-39]
	ldr	r2, [fp, #-40]
	ldr	r1, .L35+8
	bfi	r2, r6, #10, #22
	str	r2, [fp, #-40]
	str	r2, [r5, #8]
	bl	dprint_vfmw
	ldr	r3, [r4, #100]
	ldr	r2, [r4, #96]
	mov	r0, #4
	and	r3, r3, #31
	str	r6, [fp, #-40]
	bfi	r3, r2, #5, #3
	strb	r3, [fp, #-40]
	ldr	r3, [fp, #-40]
	ldr	r1, [r4, #92]
	ldr	r2, [r4, #88]
	bfi	r3, r1, #8, #10
	str	r3, [fp, #-40]
	ldr	r1, .L35+12
	mov	r3, r3, lsr #16
	bfi	r3, r2, #2, #2
	strb	r3, [fp, #-38]
	ldrh	r3, [fp, #-38]
	bfi	r3, r6, #4, #12
	strh	r3, [fp, #-38]	@ movhi
	ldr	r2, [fp, #-40]
	str	r2, [r5, #12]
	bl	dprint_vfmw
	ldrb	r2, [r4]	@ zero_extendqisi2
	str	r6, [fp, #-40]
	mov	r3, #0
	ldr	r1, [r4, #80]
	bfi	r3, r2, #0, #4
	strb	r3, [fp, #-40]
	mov	r0, #4
	ldrh	r3, [fp, #-40]
	ldr	r2, [r4, #84]
	bfi	r3, r1, #4, #8
	strh	r3, [fp, #-40]	@ movhi
	ldr	r3, [fp, #-40]
	ldr	r1, .L35+16
	bfi	r3, r2, #12, #9
	str	r3, [fp, #-40]
	mov	r3, r3, lsr #16
	bfi	r3, r6, #5, #11
	strh	r3, [fp, #-38]	@ movhi
	ldr	r2, [fp, #-40]
	str	r2, [r5, #16]
	bl	dprint_vfmw
	ldr	r2, [r4, #164]
	ldr	r1, .L35+20
	mov	r0, #4
	str	r2, [r5, #32]
	bl	dprint_vfmw
	ldr	r1, [r4, #172]
	ldr	r2, [r4, #168]
	mov	r3, #0
	str	r6, [fp, #-40]
	bfi	r3, r1, #0, #4
	strb	r3, [fp, #-38]
	mov	r0, #4
	ldrh	r3, [fp, #-38]
	strb	r6, [fp, #-39]
	bfi	r3, r6, #4, #12
	strb	r2, [fp, #-40]
	strh	r3, [fp, #-38]	@ movhi
	mov	r6, #0
	ldr	r2, [fp, #-40]
	ldr	r1, .L35+24
	str	r2, [r5, #36]
	bl	dprint_vfmw
	ldr	r2, [r4, #172]
	ldr	r0, [r4, #116]
	ldr	r1, [r4, #120]
	add	r3, r2, #8
	add	r0, r3, r0
	mov	r2, r6
	cmp	r3, r1
	bfi	r2, r0, #0, #25
	addhi	r1, r1, #128
	rsbls	r3, r3, r1
	rsbhi	r3, r3, r1
	str	r2, [fp, #-40]
	mov	r2, r2, lsr #24
	ldrhi	r7, [r4, #124]
	ldrls	r7, [r4, #124]
	bfi	r2, r3, #1, #7
	strb	r2, [fp, #-37]
	subhi	r7, r7, #16
	ldr	r2, [fp, #-40]
	mov	r0, #4
	ldr	r1, .L35+28
	str	r2, [r5, #64]
	bl	dprint_vfmw
	mov	r3, r6
	bfi	r3, r7, #0, #24
	str	r3, [fp, #-40]
	strb	r6, [fp, #-37]
	mov	r0, #4
	ldr	r2, [fp, #-40]
	ldr	r1, .L35+32
	str	r2, [r5, #68]
	bl	dprint_vfmw
	ldr	r0, [r4, #124]
	ldr	r3, [r4, #60]
	add	r0, r0, r3
	bl	MEM_Phy2Vir
	cmp	r0, r6
	beq	.L28
.L19:
	ldr	r1, [r4, #128]
	mov	r6, #0
	mov	r3, r6
	ldr	r2, [r4, #132]
	bfi	r3, r1, #0, #25
	str	r3, [fp, #-40]
	ldr	r1, .L35+36
	mov	r0, #4
	mov	r3, r3, lsr #24
	bfi	r3, r2, #1, #7
	strb	r3, [fp, #-37]
	ldr	r2, [fp, #-40]
	str	r2, [r5, #72]
	bl	dprint_vfmw
	ldr	r2, [r4, #136]
	mov	r3, r6
	ldr	r1, .L35+40
	bfi	r3, r2, #0, #24
	str	r3, [fp, #-40]
	strb	r6, [fp, #-37]
	mov	r0, #4
	ldr	r2, [fp, #-40]
	str	r2, [r5, #76]
	bl	dprint_vfmw
	ldr	r1, [r4, #140]
	mov	r3, r6
	ldr	r2, [r4, #144]
	bfi	r3, r1, #0, #25
	str	r3, [fp, #-40]
	ldr	r1, .L35+44
	mov	r0, #4
	mov	r3, r3, lsr #24
	bfi	r3, r2, #1, #7
	strb	r3, [fp, #-37]
	ldr	r2, [fp, #-40]
	str	r2, [r5, #80]
	bl	dprint_vfmw
	ldr	r2, [r4, #148]
	mov	r3, r6
	ldr	r1, .L35+48
	bfi	r3, r2, #0, #24
	str	r3, [fp, #-40]
	strb	r6, [fp, #-37]
	mov	r0, #4
	ldr	r2, [fp, #-40]
	str	r2, [r5, #84]
	bl	dprint_vfmw
	ldr	r1, [r4, #152]
	mov	r3, r6
	ldr	r2, [r4, #156]
	bfi	r3, r1, #0, #25
	str	r3, [fp, #-40]
	ldr	r1, .L35+52
	mov	r0, #4
	mov	r3, r3, lsr #24
	bfi	r3, r2, #1, #7
	strb	r3, [fp, #-37]
	ldr	r2, [fp, #-40]
	str	r2, [r5, #88]
	bl	dprint_vfmw
	ldr	r2, [r4, #160]
	mov	r3, r6
	ldr	r1, .L35+56
	bfi	r3, r2, #0, #24
	str	r3, [fp, #-40]
	strb	r6, [fp, #-37]
	mov	r0, #4
	ldr	r2, [fp, #-40]
	str	r2, [r5, #92]
	bl	dprint_vfmw
	ldr	r2, [r4, #176]
	ldr	r1, .L35+60
	mov	r0, #4
	bic	r2, r2, #15
	str	r2, [r5, #128]
	bl	dprint_vfmw
	ldr	r2, [r4, #180]
	ldr	r1, .L35+64
	mov	r0, #4
	bic	r2, r2, #15
	str	r2, [r5, #136]
	bl	dprint_vfmw
	ldr	r2, [r4, #184]
	ldr	r1, .L35+68
	mov	r0, #4
	bic	r2, r2, #15
	str	r2, [r5, #140]
	bl	dprint_vfmw
	ldr	r2, [r8, #1144]
	ldr	r1, .L35+72
	mov	r0, #4
	bic	r2, r2, #15
	str	r2, [r5, #144]
	bl	dprint_vfmw
	ldr	r2, [r8, #1148]
	ldr	r1, .L35+76
	mov	r0, #4
	bic	r2, r2, #15
	str	r2, [r5, #148]
	bl	dprint_vfmw
	ldr	r2, [r8, #1152]
	ldr	r1, .L35+80
	mov	r0, #4
	bic	r2, r2, #15
	str	r2, [r5, #152]
	bl	dprint_vfmw
	ldr	r7, [r8, #1184]
	ldr	r1, .L35+84
	mov	r0, #4
	bic	r7, r7, #15
	str	r7, [r5, #156]
	str	r7, [fp, #-40]
	mov	r2, r7
	bl	dprint_vfmw
	mov	r0, r7
	bl	MEM_Phy2Vir
	mov	r9, r0
	ldr	r0, [r8, #1184]
	bl	MEM_Phy2Vir
	cmp	r0, r6
	cmpne	r9, r6
	moveq	r1, #1
	movne	r1, #0
	beq	.L29
	ldr	r5, .L35+88
	mov	r2, #4096
	mov	r0, r9
	ldr	r3, [r5, #48]
	blx	r3
	ldr	r3, [r5, #52]
	mov	r2, #64
	ldr	r1, [r4, #4]
	mov	r0, r9
	blx	r3
	ldr	r3, [r5, #52]
	mov	r2, #640
	ldr	r1, [r4, #8]
	add	r0, r9, #64
	blx	r3
	ldr	r3, [r5, #52]
	add	r0, r9, #704
	mov	r2, #64
	ldr	r1, [r4, #12]
	blx	r3
	ldr	r3, [r4, #76]
	mov	r0, r7
	cmp	r3, #0
	beq	.L30
	bl	MEM_Phy2Vir
	mov	r6, r0
	adds	r0, r0, #768
	beq	.L31
	ldr	r3, [r5, #52]
	mov	r2, #1536
	ldr	r1, [r4, #44]
	blx	r3
	ldr	r3, [r5, #52]
	mov	r2, #128
	ldr	r1, [r4, #40]
	add	r0, r6, #2304
	blx	r3
	add	r0, r6, #2432
	ldr	r3, [r5, #52]
	mov	r2, #128
	ldr	r1, [r4, #48]
	blx	r3
.L23:
	mov	r0, r7
	bl	MEM_Phy2Vir
	mov	r6, r0
	adds	r0, r0, #2560
	beq	.L32
	ldr	r3, [r5, #52]
	mov	r2, #64
	ldr	r1, [r4, #16]
	blx	r3
	ldr	r3, [r5, #52]
	mov	r2, #64
	ldr	r1, [r4, #20]
	add	r0, r6, #2624
	ldr	r8, .L35+88
	blx	r3
	ldr	r3, [r5, #52]
	mov	r2, #960
	ldr	r1, [r4, #24]
	add	r0, r6, #2688
	blx	r3
	mov	r0, r7
	bl	MEM_Phy2Vir
	adds	r0, r0, #2816
	beq	.L33
	ldr	r3, [r8, #52]
	mov	r2, #960
	ldr	r1, [r4, #24]
	blx	r3
	mov	r0, #0
.L16:
	sub	sp, fp, #36
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, fp, sp, pc}
.L30:
	bl	MEM_Phy2Vir
	mov	r6, r0
	adds	r0, r0, #768
	beq	.L34
	ldr	r3, [r5, #52]
	mov	r2, #96
	ldr	r1, [r4, #28]
	blx	r3
	ldr	r3, [r5, #52]
	ldr	r1, [r4, #36]
	mov	r2, #32
	add	r0, r6, #864
	blx	r3
	add	r0, r6, #896
	ldr	r3, [r5, #52]
	mov	r2, #576
	ldr	r1, [r4, #32]
	blx	r3
	b	.L23
.L28:
	movw	r2, #343
	ldr	r1, .L35+92
	mov	r0, #1
	bl	dprint_vfmw
	b	.L19
.L29:
	mov	r3, r0
	str	r9, [sp]
	mov	r0, r6
	ldr	r2, .L35+96
	ldr	r1, .L35+100
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L16
.L27:
	ldr	r3, .L35+104
	ldr	r2, .L35+96
	ldr	r1, .L35+108
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L16
.L33:
	movw	r2, #553
	ldr	r1, .L35+112
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L16
.L32:
	mov	r2, #532
	ldr	r1, .L35+112
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L16
.L31:
	mov	r2, #508
	ldr	r1, .L35+112
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L16
.L34:
	movw	r2, #482
	ldr	r1, .L35+112
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L16
.L36:
	.align	2
.L35:
	.word	.LC17
	.word	.LC18
	.word	.LC19
	.word	.LC20
	.word	.LC21
	.word	.LC22
	.word	.LC23
	.word	.LC24
	.word	.LC25
	.word	.LC27
	.word	.LC28
	.word	.LC29
	.word	.LC30
	.word	.LC31
	.word	.LC32
	.word	.LC33
	.word	.LC34
	.word	.LC35
	.word	.LC36
	.word	.LC37
	.word	.LC38
	.word	.LC39
	.word	vfmw_Osal_Func_Ptr_S
	.word	.LC26
	.word	.LANCHOR0+24
	.word	.LC40
	.word	.LC15
	.word	.LC16
	.word	.LC41
	UNWIND(.fnend)
	.size	VP6HAL_V4R3C1_CfgDnMsg, .-VP6HAL_V4R3C1_CfgDnMsg
	.align	2
	.global	VP6HAL_V4R3C1_StartDec
	.type	VP6HAL_V4R3C1_StartDec, %function
VP6HAL_V4R3C1_StartDec:
	UNWIND(.fnstart)
	@ args = 0, pretend = 0, frame = 8
	@ frame_needed = 1, uses_anonymous_args = 0
	UNWIND(.movsp ip)
	mov	ip, sp
	stmfd	sp!, {r4, r5, fp, ip, lr, pc}
	UNWIND(.pad #4)
	UNWIND(.save {r4, r5, fp, ip, lr})
	UNWIND(.setfp fp, ip, #-4)
	sub	fp, ip, #4
	UNWIND(.pad #16)
	sub	sp, sp, #16
	cmp	r1, #0
	mov	r4, r0
	beq	.L39
	cmp	r1, #1
	bne	.L46
	mov	r0, #0
	mov	r3, r1
	str	r0, [sp]
	ldr	r2, .L50
	ldr	r1, .L50+4
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L41
.L39:
	ldrh	r0, [r0, #54]
	sub	r0, r0, #1
	cmp	r0, #512
	bcs	.L47
	ldrh	r0, [r4, #56]
	sub	r0, r0, #1
	cmp	r0, #512
	bcs	.L48
	ldr	r5, .L50+8
	ldr	r3, [r5]
	cmp	r3, #0
	beq	.L49
.L44:
	mov	r3, r2
	ldr	r1, .L50+8
	mov	r2, #0
	mov	r0, r4
	bl	VP6HAL_V4R3C1_CfgReg
	mov	r0, r4
	mov	r2, #0
	ldr	r1, .L50+8
	bl	VP6HAL_V4R3C1_CfgDnMsg
	mov	r0, #0
.L41:
	sub	sp, fp, #20
	ldmfd	sp, {r4, r5, fp, sp, pc}
.L46:
	ldr	r1, .L50+12
	mov	r0, #0
	bl	dprint_vfmw
	mvn	r0, #0
	sub	sp, fp, #20
	ldmfd	sp, {r4, r5, fp, sp, pc}
.L49:
	mov	r0, #0
	str	r2, [fp, #-24]
	movt	r0, 63683
	bl	MEM_Phy2Vir
	subs	r3, r0, #0
	beq	.L45
	str	r3, [r5]
	ldr	r2, [fp, #-24]
	b	.L44
.L47:
	mov	r0, r1
	ldr	r3, .L50+16
	ldr	r2, .L50
	ldr	r1, .L50+20
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L41
.L48:
	mov	r0, r1
	ldr	r3, .L50+24
	ldr	r2, .L50
	ldr	r1, .L50+20
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L41
.L45:
	ldr	r1, .L50+28
	bl	dprint_vfmw
	mvn	r0, #0
	b	.L41
.L51:
	.align	2
.L50:
	.word	.LANCHOR0+48
	.word	.LC1
	.word	g_HwMem
	.word	.LC42
	.word	.LC43
	.word	.LC16
	.word	.LC44
	.word	.LC2
	UNWIND(.fnend)
	.size	VP6HAL_V4R3C1_StartDec, .-VP6HAL_V4R3C1_StartDec
	.section	.rodata
	.align	2
.LANCHOR0 = . + 0
	.type	__func__.14133, %object
	.size	__func__.14133, 21
__func__.14133:
	.ascii	"VP6HAL_V4R3C1_CfgReg\000"
	.space	3
	.type	__func__.14148, %object
	.size	__func__.14148, 23
__func__.14148:
	.ascii	"VP6HAL_V4R3C1_CfgDnMsg\000"
	.space	1
	.type	__func__.14119, %object
	.size	__func__.14119, 23
__func__.14119:
	.ascii	"VP6HAL_V4R3C1_StartDec\000"
	.section	.rodata.str1.4,"aMS",%progbits,1
	.align	2
.LC0:
	ASCII(.ascii	"VdhId is wrong! MP2HAL_V200R003_CfgReg\012\000" )
.LC1:
	ASCII(.ascii	"%s: VdhId(%d) > %d\012\000" )
.LC2:
	ASCII(.ascii	"vdm register virtual address not mapped, reset fail" )
	ASCII(.ascii	"ed!\012\000" )
.LC3:
	ASCII(.ascii	"BASIC_CFG0 = 0x%x\012\000" )
	.space	1
.LC4:
	ASCII(.ascii	"BASIC_CFG1 = 0x%x\012\000" )
	.space	1
.LC5:
	ASCII(.ascii	"AVM_ADDR = 0x%x\012\000" )
	.space	3
.LC6:
	ASCII(.ascii	"VAM_ADDR = 0x%x\012\000" )
	.space	3
.LC7:
	ASCII(.ascii	"STREAM_BASE_ADDR = 0x%x\012\000" )
	.space	3
.LC8:
	ASCII(.ascii	"PPFD_V4R3C1_BUF_ADDR = 0x%x\012\000" )
	.space	3
.LC9:
	ASCII(.ascii	"PPFD_V200R003_BUF_LEN = 0x%x\012\000" )
	.space	2
.LC10:
	ASCII(.ascii	"YSTADDR_1D = 0x%x\012\000" )
	.space	1
.LC11:
	ASCII(.ascii	"YSTRIDE_1D = 0x%x\012\000" )
	.space	1
.LC12:
	ASCII(.ascii	"UVOFFSET_1D = 0x%x\012\000" )
.LC13:
	ASCII(.ascii	"HEAD_INF_OFFSET = 0x%x\012\000" )
.LC14:
	ASCII(.ascii	"FF_APT_EN = 0x%x\012\000" )
	.space	2
.LC15:
	ASCII(.ascii	"can not map down msg virtual address!\000" )
	.space	2
.LC16:
	ASCII(.ascii	"%s: %s\012\000" )
.LC17:
	ASCII(.ascii	"D0 = 0x%x\012\000" )
	.space	1
.LC18:
	ASCII(.ascii	"D1 = 0x%x\012\000" )
	.space	1
.LC19:
	ASCII(.ascii	"D2 = 0x%x\012\000" )
	.space	1
.LC20:
	ASCII(.ascii	"D3 = 0x%x\012\000" )
	.space	1
.LC21:
	ASCII(.ascii	"D4 = 0x%x\012\000" )
	.space	1
.LC22:
	ASCII(.ascii	"D8 = 0x%x\012\000" )
	.space	1
.LC23:
	ASCII(.ascii	"D9 = 0x%x\012\000" )
	.space	1
.LC24:
	ASCII(.ascii	"D16 = 0x%x\012\000" )
.LC25:
	ASCII(.ascii	"D17 = 0x%x\012\000" )
.LC26:
	ASCII(.ascii	"LINE:%d NULL == tmpAddr.\012\000" )
	.space	2
.LC27:
	ASCII(.ascii	"D18 = 0x%x\012\000" )
.LC28:
	ASCII(.ascii	"D19 = 0x%x\012\000" )
.LC29:
	ASCII(.ascii	"D20 = 0x%x\012\000" )
.LC30:
	ASCII(.ascii	"D21 = 0x%x\012\000" )
.LC31:
	ASCII(.ascii	"D22 = 0x%x\012\000" )
.LC32:
	ASCII(.ascii	"D23 = 0x%x\012\000" )
.LC33:
	ASCII(.ascii	"D32 = 0x%x\012\000" )
.LC34:
	ASCII(.ascii	"D34 = 0x%x\012\000" )
.LC35:
	ASCII(.ascii	"D35 = 0x%x\012\000" )
.LC36:
	ASCII(.ascii	"D36 = 0x%x\012\000" )
.LC37:
	ASCII(.ascii	"D37 = 0x%x\012\000" )
.LC38:
	ASCII(.ascii	"D38 = 0x%x\012\000" )
.LC39:
	ASCII(.ascii	"D39 = 0x%x\012\000" )
.LC40:
	ASCII(.ascii	"%s: tmpAddr(%p) = NULL / TabBaseAddr(%p) = NULL\012" )
	ASCII(.ascii	"\000" )
	.space	3
.LC41:
	ASCII(.ascii	"line: %d  NULL == TabBaseAddr.\012\000" )
.LC42:
	ASCII(.ascii	"VdhId is wrong! MP2HAL_V200R003_StartDec\012\000" )
	.space	2
.LC43:
	ASCII(.ascii	"picture width out of range\000" )
	.space	1
.LC44:
	ASCII(.ascii	"picture height out of range\000" )
	.ident	"GCC: (gcc-4.9.4 + glibc-2.27 Build by czyong Mon Jul  2 18:10:52 CST 2018) 4.9.4"
	.section	.note.GNU-stack,"",%progbits
