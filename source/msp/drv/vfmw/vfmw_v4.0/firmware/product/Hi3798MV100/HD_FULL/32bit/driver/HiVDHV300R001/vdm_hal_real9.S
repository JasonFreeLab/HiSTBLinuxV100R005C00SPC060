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
	.file	"vdm_hal_real9.c"
	.text
	.align	2
	.global	RV9HAL_V300R001_WriteReg
	.type	RV9HAL_V300R001_WriteReg, %function
RV9HAL_V300R001_WriteReg:
	UNWIND(.fnstart)
	@ args = 0, pretend = 0, frame = 8
	@ frame_needed = 1, uses_anonymous_args = 0
	UNWIND(.movsp ip)
	mov	ip, sp
	stmfd	sp!, {r4, r5, r6, r7, r8, r9, r10, fp, ip, lr, pc}
	UNWIND(.pad #4)
	UNWIND(.save {r4, r5, r6, r7, r8, r9, r10, fp, ip, lr})
	UNWIND(.setfp fp, ip, #-4)
	sub	fp, ip, #4
	UNWIND(.pad #20)
	sub	sp, sp, #20
	ldr	r6, .L26
	mov	r4, r1
	mov	r8, r0
	ldr	r1, .L26+4
	mov	r0, #2
	ldr	r3, [r6, #68]
	mov	r5, r2
	blx	r3
	ldr	r0, [r4, #8]
	ldr	r2, [r4, #4]
	mov	r1, #0
	mov	r3, r1
	cmp	r5, r1
	mul	r2, r2, r0
	mov	r0, #1
	bfi	r0, r1, #1, #1
	sub	r2, r2, #1
	bfi	r3, r2, #0, #20
	str	r3, [fp, #-48]
	strb	r0, [fp, #-45]
	mov	r3, r3, lsr #16
	bfi	r3, r1, #7, #1
	strb	r3, [fp, #-46]
	ble	.L23
	mov	r3, #1
	ldr	r2, .L26+8
	str	r3, [sp]
	mov	r0, #32
	ldr	r7, [r6, #68]
	mov	r3, r5
	ldr	r1, .L26+12
	blx	r7
	ldr	r2, [fp, #-48]
.L3:
	ldr	r3, [r6, #68]
	mov	r0, #3
	ldr	r1, .L26+16
	blx	r3
	ldr	r3, [r4, #60]
	mov	r1, #0
	mov	r0, #9
	str	r1, [fp, #-48]
	add	ip, r4, #8192
	ldrh	r2, [fp, #-46]
	mov	r3, r3, lsr #6
	strb	r0, [fp, #-48]
	cmp	r5, r1
	ldrh	r0, [fp, #-48]
	bfi	r2, r1, #0, #12
	ldr	lr, [ip, #3148]
	bfi	r0, r3, #4, #10
	ldr	ip, [r4, #36]
	mov	r3, r2, lsr #8
	strh	r2, [fp, #-46]	@ movhi
	mov	r2, r0, lsr #8
	and	r3, r3, #239
	bfi	r2, ip, #6, #1
	orr	r3, r3, #32
	bfi	r3, lr, #6, #1
	strh	r0, [fp, #-48]	@ movhi
	mvn	r2, r2, asl #25
	bfi	r3, r1, #7, #1
	mvn	r2, r2, lsr #25
	ldr	r7, .L26
	strb	r3, [fp, #-45]
	strb	r2, [fp, #-47]
	ble	.L24
	mov	r10, #1
	ldr	r9, [r7, #68]
	mov	r3, r5
	ldr	r2, .L26+8
	ldr	r1, .L26+12
	mov	r0, #32
	str	r10, [sp]
	blx	r9
	ldr	r3, [r7, #68]
	ldr	r2, [fp, #-48]
	mov	r0, #3
	ldr	r1, .L26+20
	blx	r3
	ldr	r9, [r8, #48]
	mov	r3, r5
	str	r10, [sp]
	bic	r9, r9, #15
	ldr	ip, [r7, #68]
	ldr	r2, .L26+8
	mov	r0, #32
	ldr	r1, .L26+12
	blx	ip
	mov	r2, r9
	ldr	r3, [r7, #68]
	mov	r0, #3
	ldr	r1, .L26+24
	blx	r3
	ldr	r9, [r8, #32]
	mov	r3, r5
	str	r10, [sp]
	bic	r9, r9, #15
	ldr	ip, [r7, #68]
	ldr	r2, .L26+8
	mov	r0, #32
	ldr	r1, .L26+12
	blx	ip
	mov	r2, r9
	ldr	r3, [r7, #68]
	mov	r0, #3
	ldr	r1, .L26+28
	blx	r3
	ldr	r9, [r4, #40]
	mov	r3, r5
	str	r10, [sp]
	mov	r0, #32
	ldr	r7, [r7, #68]
	ldr	r2, .L26+8
	ldr	r1, .L26+12
	str	r9, [fp, #-48]
	blx	r7
.L5:
	ldr	r3, [r6, #68]
	mov	r2, r9
	ldr	r1, .L26+32
	mov	r0, #3
	blx	r3
	ldr	r3, [r4, #4]
	cmp	r3, #256
	movw	r3, #30480
	movtls	r3, 1
	cmp	r5, #0
	str	r3, [fp, #-48]
	beq	.L9
	cmp	r5, #1
	bne	.L25
	ldr	r3, .L26+36
	ldr	r1, [fp, #-48]
	ldr	r0, [r3]
	add	r0, r0, #4
	bl	MEM_WritePhyWord
.L12:
	mov	r0, #0
	ldr	r4, [r6, #68]
	mov	r3, r5
	str	r0, [sp]
	ldr	r2, .L26+8
	ldr	r1, .L26+40
	blx	r4
	sub	sp, fp, #40
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, r10, fp, sp, pc}
.L25:
	cmp	r5, #0
	bgt	.L12
.L11:
	movw	r9, #1208
	ldr	r7, .L26+44
	mul	r9, r9, r5
	movw	r3, #3075
	movt	r3, 48
	ldr	r1, .L26+48
	mov	r2, r3
	mov	r0, #3
	ldr	ip, [r7, r9]
	str	r3, [ip, #60]
	ldr	ip, [r7, r9]
	str	r3, [ip, #64]
	ldr	ip, [r7, r9]
	str	r3, [ip, #68]
	ldr	ip, [r7, r9]
	str	r3, [ip, #72]
	ldr	ip, [r7, r9]
	str	r3, [ip, #76]
	ldr	ip, [r7, r9]
	str	r3, [ip, #80]
	ldr	ip, [r7, r9]
	str	r3, [ip, #84]
	ldr	r3, [r6, #68]
	blx	r3
	ldr	r3, [r7, r9]
	ldr	r2, [r4, #52]
	mov	r0, #3
	ldr	r1, .L26+52
	bic	r2, r2, #15
	str	r2, [r3, #96]
	ldr	r3, [r6, #68]
	blx	r3
	ldr	r3, [r7, r9]
	ldr	r2, [r4, #60]
	mov	r0, #3
	ldr	r9, [r4, #8]
	ldr	r1, .L26+56
	str	r2, [r3, #100]
	ldr	r3, [r6, #68]
	blx	r3
	ldr	r3, [r4, #4]
	mov	r3, r3, asl #4
	sub	r2, r3, #1
	cmp	r2, #2048
	movcc	r10, #16
	bcc	.L14
	sub	r2, r3, #2048
	sub	r2, r2, #1
	cmp	r2, #2048
	movcc	r10, #32
	bcc	.L14
	sub	r2, r3, #4096
	sub	r2, r2, #1
	cmp	r2, #2048
	movcc	r10, #48
	bcc	.L14
	sub	r3, r3, #6144
	sub	r3, r3, #1
	cmp	r3, #2048
	movcs	r10, #16
	movcc	r10, #64
.L14:
	ldr	r3, [r4, #8]
	add	r9, r9, #1
	ldr	r2, [r4, #60]
	movw	r0, #1208
	mul	r5, r0, r5
	mov	r3, r3, asl #4
	add	r3, r3, #31
	mov	r9, r9, lsr #1
	ldr	r1, .L26+60
	mov	r0, #3
	mov	r3, r3, lsr #5
	mul	r2, r2, r9
	mov	r3, r3, asl #4
	mov	r9, #0
	mla	r2, r10, r3, r2
	ldr	r3, [r7, r5]
	mov	r2, r2, asl #1
	str	r2, [r3, #104]
	ldr	r3, [r6, #68]
	blx	r3
	ldr	r3, [r4, #8]
	ldr	r2, [r7, r5]
	mov	r0, #3
	ldr	r1, .L26+64
	mov	r3, r3, asl #4
	add	r3, r3, #31
	bic	r3, r3, #31
	mul	r10, r10, r3
	str	r10, [r2, #108]
	ldr	r3, [r8, #1184]
	ldr	ip, [r7, r5]
	mov	r2, r3
	str	r3, [ip, #144]
	ldr	r3, [r6, #68]
	blx	r3
	ldr	r3, [r7, r5]
	mov	r2, r9
	ldr	r1, .L26+68
	mov	r0, #3
	str	r9, [fp, #-48]
	str	r9, [r3, #148]
	ldr	r3, [r6, #68]
	blx	r3
	ldrb	r3, [fp, #-48]	@ zero_extendqisi2
	ldr	ip, [r7, r5]
	mov	r0, #3
	bfi	r3, r9, #0, #1
	strb	r3, [fp, #-48]
	ldr	r2, [fp, #-48]
	ldr	r1, .L26+72
	str	r2, [ip, #152]
	ldr	r3, [r6, #68]
	blx	r3
	ldr	r3, [r7, r5]
	mvn	r2, #0
	str	r2, [r3, #32]
	sub	sp, fp, #40
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, r10, fp, sp, pc}
.L24:
	movw	r9, #1208
	ldr	r10, .L26+44
	mul	r9, r9, r5
	ldr	r3, [fp, #-48]
	ldr	r1, .L26+20
	mov	r0, #3
	mov	r2, r3
	ldr	ip, [r10, r9]
	str	r3, [ip, #12]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r3, [r10, r9]
	ldr	r2, [r8, #48]
	mov	r0, #3
	ldr	r1, .L26+24
	bic	r2, r2, #15
	str	r2, [r3, #16]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r3, [r10, r9]
	ldr	r2, [r8, #32]
	mov	r0, #3
	ldr	r1, .L26+28
	bic	r2, r2, #15
	str	r2, [r3, #20]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r3, [r10, r9]
	ldr	r9, [r4, #40]
	str	r9, [r3, #24]
	str	r9, [fp, #-48]
	b	.L5
.L23:
	movw	r3, #1208
	ldr	r1, .L26+44
	mul	r3, r3, r5
	ldr	r2, [fp, #-48]
	ldr	r3, [r1, r3]
	str	r2, [r3, #8]
	b	.L3
.L9:
	ldr	r3, .L26+76
	ldr	r1, [fp, #-48]
	ldr	r0, [r3]
	add	r0, r0, #4
	bl	MEM_WritePhyWord
	b	.L11
.L27:
	.align	2
.L26:
	.word	vfmw_Osal_Func_Ptr_S
	.word	.LC0
	.word	.LANCHOR0
	.word	.LC1
	.word	.LC2
	.word	.LC3
	.word	.LC4
	.word	.LC5
	.word	.LC6
	.word	s_RegPhyBaseAddr_1
	.word	.LC7
	.word	g_HwMem
	.word	.LC8
	.word	.LC9
	.word	.LC10
	.word	.LC11
	.word	.LC12
	.word	.LC13
	.word	.LC14
	.word	s_RegPhyBaseAddr
	UNWIND(.fnend)
	.size	RV9HAL_V300R001_WriteReg, .-RV9HAL_V300R001_WriteReg
	.align	2
	.global	RV9HAL_V300R001_WritePicMsg
	.type	RV9HAL_V300R001_WritePicMsg, %function
RV9HAL_V300R001_WritePicMsg:
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
	ldr	r4, .L33
	mov	r8, r0
	mov	r6, r1
	mov	r0, #2
	ldr	r1, .L33+4
	ldr	r3, [r4, #68]
	blx	r3
	ldr	r0, [r8, #48]
	bic	r0, r0, #15
	bl	MEM_Phy2Vir
	subs	r5, r0, #0
	beq	.L32
	ldrb	r2, [r6, #1]	@ zero_extendqisi2
	mov	r7, #0
	mov	r3, #0
	str	r7, [fp, #-40]
	bfi	r3, r2, #0, #2
	strb	r3, [fp, #-40]
	ldr	r2, [fp, #-40]
	mov	r0, #4
	ldr	r1, .L33+8
	str	r2, [r5]
	ldr	r3, [r4, #68]
	blx	r3
	ldmib	r6, {r2, r3}
	mov	r0, #0	@ movhi
	sub	r2, r2, #1
	sub	r3, r3, #1
	mov	r1, r0	@ movhi
	bfi	r0, r2, #0, #9
	bfi	r1, r3, #0, #9
	strh	r0, [fp, #-40]	@ movhi
	strh	r1, [fp, #-38]	@ movhi
	mov	r0, #4
	ldr	r2, [fp, #-40]
	ldr	r1, .L33+12
	str	r2, [r5, #4]
	ldr	r3, [r4, #68]
	blx	r3
	ldr	r2, [r6, #12]
	ldr	r3, [r6, #16]
	mov	r0, #4
	ldr	r1, .L33+16
	strh	r2, [fp, #-40]	@ movhi
	strh	r3, [fp, #-38]	@ movhi
	ldr	r2, [fp, #-40]
	str	r2, [r5, #8]
	ldr	r3, [r4, #68]
	blx	r3
	str	r7, [fp, #-40]
	mov	r3, #0
	bfi	r3, r7, #1, #3
	strb	r3, [fp, #-40]
	mov	r0, #4
	ldr	r2, [fp, #-40]
	ldr	r1, .L33+20
	str	r2, [r5, #12]
	ldr	r3, [r4, #68]
	blx	r3
	ldr	r2, [r6, #20]
	str	r7, [fp, #-40]
	mov	r3, #0
	bfi	r3, r2, #0, #5
	strb	r3, [fp, #-40]
	ldr	r2, [fp, #-40]
	mov	r0, #4
	ldr	r1, .L33+24
	str	r2, [r5, #16]
	ldr	r3, [r4, #68]
	blx	r3
	ldr	r2, [r6, #24]
	str	r7, [fp, #-40]
	mov	r3, #0
	bfi	r3, r2, #0, #5
	strb	r3, [fp, #-40]
	ldr	r2, [fp, #-40]
	mov	r0, #4
	ldr	r1, .L33+28
	str	r2, [r5, #20]
	ldr	r3, [r4, #68]
	blx	r3
	ldr	r2, [r6, #8]
	ldr	r3, [r6, #4]
	mov	r0, #4
	str	r7, [fp, #-40]
	ldr	r1, .L33+32
	mul	r3, r3, r2
	cmp	r3, #99
	ldrh	r3, [fp, #-40]
	movls	r2, #1
	bfihi	r3, r7, #5, #6
	bfils	r3, r2, #5, #6
	strh	r3, [fp, #-40]	@ movhi
	ldr	r2, [r6, #28]
	ldrb	r3, [fp, #-40]	@ zero_extendqisi2
	bfi	r3, r2, #0, #5
	strb	r3, [fp, #-40]
	ldr	r2, [fp, #-40]
	str	r2, [r5, #24]
	ldr	r3, [r4, #68]
	blx	r3
	ldr	r2, [r6, #56]
	ldr	r1, .L33+36
	mov	r0, #4
	bic	r2, r2, #15
	str	r2, [r5, #64]
	ldr	r3, [r4, #68]
	blx	r3
	ldr	r2, [r6, #48]
	ldr	r1, .L33+40
	mov	r0, #4
	bic	r2, r2, #15
	str	r2, [r5, #68]
	ldr	r3, [r4, #68]
	blx	r3
	ldr	r2, [r6, #44]
	ldr	r3, [r4, #68]
	mov	r0, #4
	bic	r2, r2, #15
	ldr	r1, .L33+44
	str	r2, [r5, #72]
	blx	r3
	ldr	r2, [r6, #68]
	ldr	r3, [r4, #68]
	mov	r0, #4
	ldr	r1, .L33+48
	str	r2, [r5, #76]
	blx	r3
	ldr	r2, [r6, #72]
	ldr	r3, [r4, #68]
	mov	r0, #4
	ldr	r1, .L33+52
	str	r2, [r5, #80]
	blx	r3
	ldr	r2, [r8, #1136]
	ldr	r3, [r4, #68]
	mov	r0, #4
	bic	r2, r2, #15
	ldr	r1, .L33+56
	str	r2, [r5, #84]
	blx	r3
	ldr	r2, [r8, #1140]
	ldr	r3, [r4, #68]
	mov	r0, #4
	bic	r2, r2, #15
	ldr	r1, .L33+60
	str	r2, [r5, #88]
	blx	r3
	ldr	r2, [r8, #1144]
	ldr	r3, [r4, #68]
	mov	r0, #4
	bic	r2, r2, #15
	ldr	r1, .L33+64
	str	r2, [r5, #92]
	blx	r3
	ldr	r2, [r8, #1152]
	ldr	r3, [r4, #68]
	mov	r0, #4
	ldr	r1, .L33+68
	str	r2, [r5, #96]
	blx	r3
	ldr	r2, [r8, #48]
	ldr	r3, [r4, #68]
	mov	r0, #4
	bic	r2, r2, #15
	ldr	r1, .L33+72
	add	r2, r2, #256
	str	r2, [r5, #252]
	sub	sp, fp, #32
	ldmfd	sp, {r4, r5, r6, r7, r8, fp, sp, lr}
	bx	r3
.L32:
	ldr	ip, [r4, #68]
	ldr	r3, .L33+76
	ldr	r2, .L33+80
	ldr	r1, .L33+84
	sub	sp, fp, #32
	ldmfd	sp, {r4, r5, r6, r7, r8, fp, sp, lr}
	bx	ip
.L34:
	.align	2
.L33:
	.word	vfmw_Osal_Func_Ptr_S
	.word	.LC15
	.word	.LC18
	.word	.LC19
	.word	.LC20
	.word	.LC21
	.word	.LC22
	.word	.LC23
	.word	.LC24
	.word	.LC25
	.word	.LC26
	.word	.LC27
	.word	.LC28
	.word	.LC29
	.word	.LC30
	.word	.LC31
	.word	.LC32
	.word	.LC33
	.word	.LC34
	.word	.LC16
	.word	.LANCHOR0+28
	.word	.LC17
	UNWIND(.fnend)
	.size	RV9HAL_V300R001_WritePicMsg, .-RV9HAL_V300R001_WritePicMsg
	.align	2
	.global	RV9HAL_V300R001_WriteSliceMsg
	.type	RV9HAL_V300R001_WriteSliceMsg, %function
RV9HAL_V300R001_WriteSliceMsg:
	UNWIND(.fnstart)
	@ args = 0, pretend = 0, frame = 24
	@ frame_needed = 1, uses_anonymous_args = 0
	UNWIND(.movsp ip)
	mov	ip, sp
	stmfd	sp!, {r4, r5, r6, r7, r8, r9, r10, fp, ip, lr, pc}
	UNWIND(.pad #4)
	UNWIND(.save {r4, r5, r6, r7, r8, r9, r10, fp, ip, lr})
	UNWIND(.setfp fp, ip, #-4)
	sub	fp, ip, #4
	UNWIND(.pad #28)
	sub	sp, sp, #28
	ldr	r7, .L56
	mov	r3, r1
	mov	r4, r0
	str	r1, [fp, #-56]
	mov	r0, #2
	ldr	r1, .L56+4
	add	r10, r3, #76
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r4, [r4, #48]
	bic	r4, r4, #15
	add	r5, r4, #256
	mov	r0, r5
	bl	MEM_Phy2Vir
	subs	r8, r0, #0
	beq	.L53
	ldr	r3, [fp, #-56]
	ldr	r3, [r3, #112]
	cmp	r3, #0
	moveq	r2, r3
	bne	.L54
.L37:
	ldr	r3, [fp, #-56]
	ldr	r3, [r3, #32]
	cmp	r3, #0
	beq	.L35
	mov	r2, r2, asl #6
	mov	r4, #0
	str	r2, [fp, #-64]
	add	r2, r2, r5
	str	r2, [fp, #-68]
	mov	r2, r3
.L47:
	cmp	r4, #0
	beq	.L50
	mov	r5, #44
	mla	r5, r5, r4, r10
	ldr	r0, [r5, #36]
	ldr	r1, [r5, #-8]
	cmp	r0, r1
	ble	.L41
.L40:
	ldr	ip, [r5, #16]
	mov	r9, #0
	ldr	r0, [r5, #8]
	mov	r1, r9
	ldr	r3, [fp, #-64]
	bfi	r1, ip, #0, #24
	mov	r2, #0
	str	r1, [fp, #-48]
	bfi	r2, r0, #0, #7
	strb	r2, [fp, #-45]
	ldr	r2, [fp, #-48]
	add	ip, r3, r4, lsl #6
	ldr	r1, .L56+8
	mov	r0, #4
	mov	r6, ip, asl #2
	add	r4, r4, #1
	str	r2, [r8, ip, asl #2]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r1, [r5]
	add	ip, r6, #4
	mov	r2, r9
	mov	r0, #4
	bfi	r2, r1, #0, #24
	ldr	r1, .L56+12
	str	r2, [fp, #-48]
	str	r2, [r8, ip]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	ip, [r5, #20]
	ldr	r0, [r5, #12]
	mov	r1, r9
	mov	r2, #0
	bfi	r1, ip, #0, #24
	bfi	r2, r0, #0, #7
	str	r1, [fp, #-48]
	strb	r2, [fp, #-45]
	add	ip, r6, #8
	ldr	r2, [fp, #-48]
	mov	r0, #4
	ldr	r1, .L56+16
	str	r2, [r8, ip]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r1, [r5, #4]
	add	ip, r6, #12
	mov	r2, r9
	mov	r0, #4
	bfi	r2, r1, #0, #24
	ldr	r1, .L56+20
	str	r2, [fp, #-48]
	str	r2, [r8, ip]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r2, [r5, #24]
	ldr	r1, [r5, #28]
	add	ip, r6, #16
	ldr	lr, [r5, #32]
	and	r2, r2, #1
	bfi	r2, r1, #1, #2
	str	r9, [fp, #-48]
	bfi	r2, lr, #3, #5
	strb	r2, [fp, #-46]
	ldr	r2, [fp, #-48]
	mov	r0, #4
	ldr	r1, .L56+24
	str	r2, [r8, ip]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r3, [fp, #-56]
	ldr	r0, [r5, #36]
	str	r9, [fp, #-48]
	ldr	r1, [r3, #32]
	strh	r0, [fp, #-48]	@ movhi
	cmp	r4, r1
	bcs	.L42
	mov	r2, #44
	mul	r2, r2, r4
	add	ip, r10, r2
	ldr	ip, [ip, #36]
	cmp	r0, ip
	blt	.L42
	sub	r2, r2, #44
	add	r2, r10, r2
	b	.L43
.L44:
	ldr	r3, [r2, #80]
	cmp	r0, r3
	blt	.L42
.L43:
	add	r4, r4, #1
	add	r2, r2, #44
	cmp	r4, r1
	bcc	.L44
.L42:
	cmp	r1, r4
	beq	.L55
	mov	r2, #44
	ldr	r3, [fp, #-68]
	mla	r2, r2, r4, r10
	add	r9, r3, r4, lsl #8
	mov	r3, r9
	ldr	r2, [r2, #36]
	sub	r2, r2, #1
	str	r2, [r5, #40]
.L46:
	strh	r2, [fp, #-46]	@ movhi
	add	ip, r6, #20
	ldr	r2, [fp, #-48]
	mov	r0, #4
	ldr	r1, .L56+28
	add	r6, r6, #252
	str	r3, [fp, #-60]
	sub	r4, r4, #1
	str	r2, [r8, ip]
	ldr	r5, [r7, #68]
	blx	r5
	ldr	r3, [fp, #-60]
	mov	r2, r9
	ldr	r1, .L56+32
	mov	r0, #4
	str	r9, [fp, #-48]
	str	r3, [r8, r6]
	ldr	r5, [r7, #68]
	blx	r5
	ldr	r3, [fp, #-56]
	ldr	r2, [r3, #32]
.L41:
	add	r4, r4, #1
	cmp	r2, r4
	bhi	.L47
.L35:
	sub	sp, fp, #40
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, r10, fp, sp, pc}
.L50:
	mov	r5, r10
	b	.L40
.L55:
	ldr	r2, [fp, #-56]
	mov	r3, #0
	mov	r9, r3
	ldr	r1, [r2, #8]
	ldr	r2, [r2, #4]
	mul	r2, r2, r1
	sub	r2, r2, #1
	str	r2, [r5, #40]
	b	.L46
.L54:
	ldr	r9, [fp, #-56]
	mov	r6, #0
	mov	r2, r6
	mov	r3, #0
	bfi	r2, r6, #0, #24
	mov	r0, #4
	ldr	r1, [r9, #84]
	add	r4, r4, #512
	str	r2, [fp, #-48]
	bfi	r3, r1, #0, #7
	strb	r3, [fp, #-45]
	ldr	r2, [fp, #-48]
	ldr	r1, .L56+8
	str	r2, [r8]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r2, [r9, #76]
	mov	r3, r6
	ldr	r1, .L56+12
	bfi	r3, r2, #0, #24
	mov	r0, #4
	str	r3, [fp, #-48]
	mov	r2, r3
	str	r3, [r8, #4]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r1, [r9, #88]
	mov	r2, r6
	mov	r3, #0
	bfi	r2, r6, #0, #24
	bfi	r3, r1, #0, #7
	str	r2, [fp, #-48]
	mov	r0, #4
	strb	r3, [fp, #-45]
	ldr	r2, [fp, #-48]
	ldr	r1, .L56+16
	str	r2, [r8, #8]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r2, [r9, #80]
	mov	r3, r6
	ldr	r1, .L56+20
	bfi	r3, r2, #0, #24
	mov	r0, #4
	str	r3, [fp, #-48]
	mov	r2, r3
	str	r3, [r8, #12]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r3, [r9, #100]
	ldr	r1, [r9, #104]
	mov	r0, #4
	ldr	r2, [r9, #108]
	and	r3, r3, #1
	bfi	r3, r1, #1, #2
	str	r6, [fp, #-48]
	bfi	r3, r2, #3, #5
	strb	r3, [fp, #-46]
	ldr	r2, [fp, #-48]
	ldr	r1, .L56+24
	str	r2, [r8, #16]
	ldr	r3, [r7, #68]
	blx	r3
	ldr	r3, [r9, #112]
	strh	r6, [fp, #-48]	@ movhi
	mov	r0, #4
	sub	r3, r3, #1
	strh	r3, [fp, #-46]	@ movhi
	ldr	r2, [fp, #-48]
	ldr	r1, .L56+28
	str	r2, [r8, #20]
	ldr	r3, [r7, #68]
	blx	r3
	mov	r2, r4
	ldr	r3, [r7, #68]
	mov	r0, #4
	str	r4, [r8, #252]
	ldr	r1, .L56+32
	str	r4, [fp, #-48]
	blx	r3
	mov	r2, #1
	b	.L37
.L53:
	ldr	ip, [r7, #68]
	ldr	r3, .L56+36
	ldr	r2, .L56+40
	ldr	r1, .L56+44
	sub	sp, fp, #40
	ldmfd	sp, {r4, r5, r6, r7, r8, r9, r10, fp, sp, lr}
	bx	ip
.L57:
	.align	2
.L56:
	.word	vfmw_Osal_Func_Ptr_S
	.word	.LC35
	.word	.LC18
	.word	.LC19
	.word	.LC20
	.word	.LC21
	.word	.LC22
	.word	.LC23
	.word	.LC34
	.word	.LC16
	.word	.LANCHOR0+56
	.word	.LC17
	UNWIND(.fnend)
	.size	RV9HAL_V300R001_WriteSliceMsg, .-RV9HAL_V300R001_WriteSliceMsg
	.align	2
	.global	RV9HAL_V300R001_StartDec
	.type	RV9HAL_V300R001_StartDec, %function
RV9HAL_V300R001_StartDec:
	UNWIND(.fnstart)
	@ args = 0, pretend = 0, frame = 8
	@ frame_needed = 1, uses_anonymous_args = 0
	UNWIND(.movsp ip)
	mov	ip, sp
	stmfd	sp!, {r4, r5, r6, r7, fp, ip, lr, pc}
	UNWIND(.pad #4)
	UNWIND(.save {r4, r5, r6, r7, fp, ip, lr})
	UNWIND(.setfp fp, ip, #-4)
	sub	fp, ip, #4
	UNWIND(.pad #16)
	sub	sp, sp, #16
	cmp	r1, #1
	mov	r5, r0
	bhi	.L66
	cmp	r1, #0
	bgt	.L67
	movw	r4, #1208
	ldr	r7, .L69
	mul	r4, r4, r1
	add	r6, r4, r7
	ldr	r3, [r4, r7]
	cmp	r3, #0
	beq	.L68
.L63:
	ldr	ip, .L69+4
	mov	r2, r1
	mov	r0, r6
	mov	r1, r5
	ldr	r3, [ip]
	add	r3, r3, #1
	str	r3, [ip]
	bl	RV9HAL_V300R001_WriteReg
	mov	r1, r5
	mov	r0, r6
	bl	RV9HAL_V300R001_WritePicMsg
	mov	r1, r5
	mov	r0, r6
	bl	RV9HAL_V300R001_WriteSliceMsg
	ldr	r3, .L69+8
	ldr	r1, .L69+12
	mov	r0, #2
	ldr	r3, [r3, #68]
	blx	r3
	mov	r0, #0
.L61:
	sub	sp, fp, #28
	ldmfd	sp, {r4, r5, r6, r7, fp, sp, pc}
.L68:
	mov	r0, #0
	str	r1, [fp, #-32]
	movt	r0, 63683
	bl	MEM_Phy2Vir
	subs	r3, r0, #0
	beq	.L64
	str	r3, [r4, r7]
	ldr	r1, [fp, #-32]
	b	.L63
.L67:
	ldr	ip, .L69+8
	mov	r0, #0
	mov	r3, r1
	str	r0, [sp]
	ldr	r2, .L69+16
	ldr	r4, [ip, #68]
	ldr	r1, .L69+20
	blx	r4
	mvn	r0, #0
	b	.L61
.L66:
	ldr	r3, .L69+8
	mov	r0, #0
	ldr	r1, .L69+24
	ldr	r3, [r3, #68]
	blx	r3
	mvn	r0, #0
	b	.L61
.L64:
	ldr	r3, .L69+8
	ldr	r1, .L69+28
	ldr	r3, [r3, #68]
	blx	r3
	mvn	r0, #0
	b	.L61
.L70:
	.align	2
.L69:
	.word	g_HwMem
	.word	.LANCHOR1
	.word	vfmw_Osal_Func_Ptr_S
	.word	.LC38
	.word	.LANCHOR0+88
	.word	.LC7
	.word	.LC36
	.word	.LC37
	UNWIND(.fnend)
	.size	RV9HAL_V300R001_StartDec, .-RV9HAL_V300R001_StartDec
	.align	2
	.global	RV9HAL_V300R001_StartVDH
	.type	RV9HAL_V300R001_StartVDH, %function
RV9HAL_V300R001_StartVDH:
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
	ldr	r3, .L72
	mov	r0, #2
	ldr	r1, .L72+4
	ldr	r3, [r3, #68]
	sub	sp, fp, #12
	ldmia	sp, {fp, sp, lr}
	bx	r3
.L73:
	.align	2
.L72:
	.word	vfmw_Osal_Func_Ptr_S
	.word	.LC38
	UNWIND(.fnend)
	.size	RV9HAL_V300R001_StartVDH, .-RV9HAL_V300R001_StartVDH
	.section	.rodata
	.align	2
.LANCHOR0 = . + 0
	.type	__func__.13807, %object
	.size	__func__.13807, 25
__func__.13807:
	.ascii	"RV9HAL_V300R001_WriteReg\000"
	.space	3
	.type	__func__.13819, %object
	.size	__func__.13819, 28
__func__.13819:
	.ascii	"RV9HAL_V300R001_WritePicMsg\000"
	.type	__func__.13832, %object
	.size	__func__.13832, 30
__func__.13832:
	.ascii	"RV9HAL_V300R001_WriteSliceMsg\000"
	.space	2
	.type	__func__.13798, %object
	.size	__func__.13798, 25
__func__.13798:
	.ascii	"RV9HAL_V300R001_StartDec\000"
	.data
	.align	2
.LANCHOR1 = . + 0
	.type	FrameNum, %object
	.size	FrameNum, 4
FrameNum:
	.word	-1
	.section	.rodata.str1.4,"aMS",%progbits,1
	.align	2
.LC0:
	ASCII(.ascii	"configuring VDM registers...\012\000" )
	.space	2
.LC1:
	ASCII(.ascii	"%s: WR_VREG but VdhId(%d) > MAX_VDH_NUM(%d)\012\000" )
	.space	3
.LC2:
	ASCII(.ascii	"BASIC_V300R001_CFG0 = 0x%x\012\000" )
.LC3:
	ASCII(.ascii	"BASIC_V300R001_CFG1=0x%x\012\000" )
	.space	2
.LC4:
	ASCII(.ascii	"AVM_V200R003_ADDR=0x%x\012\000" )
.LC5:
	ASCII(.ascii	"VAM_V200R003_ADDR=0x%x\012\000" )
.LC6:
	ASCII(.ascii	"STREAM_V300R001_BASE_ADDR=0x%x\012\000" )
.LC7:
	ASCII(.ascii	"%s: VdhId(%d) > %d\012\000" )
.LC8:
	ASCII(.ascii	"TIME_OUT = 0x%x\012\000" )
	.space	3
.LC9:
	ASCII(.ascii	"YSTADDR_V300R001_1D = 0x%x\012\000" )
.LC10:
	ASCII(.ascii	"YSTRIDE_V300R001_1D = 0x%x\012\000" )
.LC11:
	ASCII(.ascii	"UVOFFSET_V300R001_1D = 0x%x\012\000" )
	.space	3
.LC12:
	ASCII(.ascii	"DNR_MBINFO_STADDR=0x%x\012\000" )
.LC13:
	ASCII(.ascii	"REF_V200R003_PIC_TYPE=0x%x\012\000" )
.LC14:
	ASCII(.ascii	"FF_V200R003_APT_EN=0x%x\012\000" )
	.space	3
.LC15:
	ASCII(.ascii	"configuring Pic Msg...\012\000" )
.LC16:
	ASCII(.ascii	"can not map dn msg virtual address!\012\000" )
	.space	3
.LC17:
	ASCII(.ascii	"%s: %s\012\000" )
.LC18:
	ASCII(.ascii	"D0 = 0x%x\012\000" )
	.space	1
.LC19:
	ASCII(.ascii	"D1 = 0x%x\012\000" )
	.space	1
.LC20:
	ASCII(.ascii	"D2 = 0x%x\012\000" )
	.space	1
.LC21:
	ASCII(.ascii	"D3 = 0x%x\012\000" )
	.space	1
.LC22:
	ASCII(.ascii	"D4 = 0x%x\012\000" )
	.space	1
.LC23:
	ASCII(.ascii	"D5 = 0x%x\012\000" )
	.space	1
.LC24:
	ASCII(.ascii	"D6 = 0x%x\012\000" )
	.space	1
.LC25:
	ASCII(.ascii	"D16 = 0x%x\012\000" )
.LC26:
	ASCII(.ascii	"D17 = 0x%x\012\000" )
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
	ASCII(.ascii	"D024 = 0x%x\012\000" )
	.space	3
.LC34:
	ASCII(.ascii	"D63 = 0x%x\012\000" )
.LC35:
	ASCII(.ascii	"configuring Slice Msg...\012\000" )
	.space	2
.LC36:
	ASCII(.ascii	"VdhId is wrong! RV9HAL_V300R001_StartDec\012\000" )
	.space	2
.LC37:
	ASCII(.ascii	"vdm register virtual address not mapped, reset fail" )
	ASCII(.ascii	"ed!\012\000" )
.LC38:
	ASCII(.ascii	"start VDM...\012\000" )
	.ident	"GCC: (gcc-4.9.4 + glibc-2.27 Build by czyong Mon Jul  2 18:10:52 CST 2018) 4.9.4"
	.section	.note.GNU-stack,"",%progbits
