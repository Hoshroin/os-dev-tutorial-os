bits 32

VIDEO_MEMORY equ 0xB8000

;
; Prints string on screen in protected mode
; Params:
;   - ebx: char to print
;
prts_pm:
	pusha
	mov edx, VIDEO_MEMORY

.loop:
	mov al, [ebx]
	mov ah, 0x0F		; set color, white on black

	cmp al, 0		; if string ends
	je .done

	mov [edx], ax		; store character + attribute in vram
	add ebx, 1		; next char
	add edx, 2		; next vram position

	jmp .loop

.done:
	popa
	ret
