bits 32
extern main	; declare that we'll referencing something external
call main	; invoke main()
jmp $		; hang the CPU
