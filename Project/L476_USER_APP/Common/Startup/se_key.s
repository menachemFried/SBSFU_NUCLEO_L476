	.section .SE_Key_Data,"a",%progbits
	.syntax unified
	.thumb 
	.global SE_ReadKey_1
SE_ReadKey_1:
	PUSH {R1-R5}
	MOVW R1, #0x454f
	MOVT R1, #0x5f4d
	MOVW R2, #0x454b
	MOVT R2, #0x5f59
	MOVW R3, #0x4f43
	MOVT R3, #0x504d
	MOVW R4, #0x4e41
	MOVT R4, #0x3159
	STM R0, {R1-R4}
	POP {R1-R5}
	BX LR

    .end
