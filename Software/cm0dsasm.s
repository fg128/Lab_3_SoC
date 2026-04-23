; Vector table and exception handlers for S0C design assignment
; This version supports UART and SysTick interrupts

Stack_Size      EQU     0x00000400		; 1KB of STACK
Stack_Top		EQU		0x20003FFC		; top of stack at top of 16 KByte RAM
Heap_Size       EQU     0x00000400 		; 1KB of HEAP
	
                AREA    STACK, NOINIT, READWRITE, ALIGN=4
Stack_Mem       SPACE   Stack_Size
__initial_sp	; label set to top of stack space

                AREA    HEAP, NOINIT, READWRITE, ALIGN=4
__heap_base
Heap_Mem        SPACE   Heap_Size
__heap_limit


; Vector Table Mapped to Address 0 at Reset

				PRESERVE8
				THUMB

				AREA	RESET, DATA, READONLY
				EXPORT 	__Vectors
			
__Vectors    	DCD		Stack_Top			; Initial Stack Pointer
        		DCD		Reset_Handler		; Reset Handler
                DCD     0 ;NMI_Handler         ; NMI Handler (not used)
                DCD     Fault_Handler   	; Hard Fault Handler
                DCD     0                   ; Reserved
                DCD     0                   ; Reserved
                DCD     0                   ; Reserved
                DCD     0                   ; Reserved
                DCD     0                   ; Reserved
                DCD     0                   ; Reserved
                DCD     0                   ; Reserved
                DCD     0 ;SVC_Handler         ; SVCall Handler (not used)
                DCD     0                   ; Reserved
                DCD     0                   ; Reserved
                DCD     0 ;PendSV_Handler      ; PendSV Handler (not used)
        		DCD     SysTick_Handler     ; SysTick Handler
        				
				; External Interrupts
				DCD		0					; IRQn value 0  
				DCD		UART_Handler		; IRQn value 1
				DCD		0					; IRQn value 2
				DCD		0
				DCD		0
				DCD		0
				DCD		0
				DCD		0
				DCD		0
				DCD		0
				DCD		0
				DCD		0
				DCD		0
				DCD		0
				DCD		0
				DCD		0					; IRQn value 15

              
                AREA |.text|, CODE, READONLY
;Reset Handler
Reset_Handler   PROC
                GLOBAL Reset_Handler
                ENTRY
				IMPORT  __main
                LDR     R0, =__main               
                BX      R0                        ;Branch to __main
                ENDP

Fault_Handler   PROC	; simple fault handler - requests a reset of the processor
                LDR		R0, =0x05FA0004		; value to request reset
				LDR		R1, =0xE000ED0C		; AIRCR address
				STR		R0, [R1]			; write to AIRCR to request reset
                ENDP

SysTick_Handler PROC
                EXPORT 	SysTick_Handler
				IMPORT 	SysTick_ISR
                PUSH    {R0,R1,R2,LR}
				BL 		SysTick_ISR
                POP     {R0,R1,R2,PC}
                ENDP


UART_Handler    PROC
                EXPORT 	UART_Handler
				IMPORT 	UART_ISR
                PUSH    {R0,R1,R2,LR}
				BL 		UART_ISR
                POP     {R0,R1,R2,PC}
                ENDP

				ALIGN 	4					 ; Align to a word boundary

; User Initial Stack & Heap
                IF      :DEF:__MICROLIB
                EXPORT  __initial_sp
                EXPORT  __heap_base
                EXPORT  __heap_limit
                ELSE
                IMPORT  __use_two_region_memory
                EXPORT  __user_initial_stackheap
__user_initial_stackheap

                LDR     R0, =  Heap_Mem
                LDR     R1, =(Stack_Mem + Stack_Size)
                LDR     R2, = (Heap_Mem +  Heap_Size)
                LDR     R3, = Stack_Mem
                BX      LR

                ALIGN

                ENDIF

		END                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
   