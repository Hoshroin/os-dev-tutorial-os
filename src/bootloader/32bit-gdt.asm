;
; GDT
;
gdt_start:

gdt_null:		; GDT starts with a null 8-byte
	dd 0x0	; 4 byte
	dd 0x0	; 4 byte

; GDT for code segment (base = 0x00000000, length = 0xfffff)
gdt_code:
	dw 0xffff	; segment limit, bits 0-15
	dw 0x0		; segment base, bits 0-15
	db 0x0		; segment base, bits 16-23
	db 10011010b	; type flags (8 bits)
	db 11001111b	; limit flags (4 bits) + segment length, bits 16-19
	db 0x0		; segment base, bits 24-31

; GDT for data segment (base = same, length = same)
gdt_data:
	dw 0xffff	; segment limit, bits 0-15
	dw 0x0		; segment base, bits 0-15
	db 0x0		; segment base, bits 16-23
	db 10010010b	; type flags (8 bits)
	db 11001111b 	; limit flags (4 bits) + segment length, bits 16-19
	db 0x0		; segment base, bits 24-31

gdt_end:

;
; GDT Descriptor
;
gdt_descriptor:
	dw gdt_end - gdt_start - 1	; size of the GDT, always less one than the true size
	dd gdt_start			; start address of the GDT

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

bits 16

switch2pm:
	cli					; disable all the interrupts
	lgdt [gdt_descriptor]			; load the GDT
	mov eax, cr0				; copy cr0 since we cannot directly set it
	or eax, 0x1				; set the last bit of cr0
	mov cr0, eax				; update cr0
	jmp CODE_SEG:init_pm			; the far jump

bits 32

init_pm:
	mov ax, DATA_SEG			; update segment registers
	mov ds, ax
	mov ss, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	mov ebp, 0x90000			; set the stack at the top of the free space
	mov esp, ebp

	call BEGIN_PM
