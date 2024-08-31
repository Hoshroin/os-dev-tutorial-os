org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A
KERNEL_OFFSET equ 0x1000

;
; FAT12 header
;
jmp short start
nop

bpb_oem: 		db 'MSWIN4.1'
bpb_bytes_per_sector: 	dw 512
bpb_sector_per_cluster: db 1
bpb_reserved_sectors: 	dw 1
bpb_fat_count: 		db 2
bpb_root_dir_entries:	dw 224
bpb_total_sectors:	dw 2880
bpb_media_descriptor:	db 0F0h
bpb_sector_per_fat:	dw 9
bpb_sector_per_track:	dw 18
bpb_number_of_sides:	dw 2
bpb_hidden_sectors:	dd 0
bpb_large_sector:	dd 0
ebpb_drive_type:	db 0			; 0x80 for hdd, 0x00 for floppy
ebpb_winnt_flag:	db 0
ebpb_signature:		db 29h
ebpb_volume_id:		db 68h, 6Fh, 73h, 68h	; just a serial number. doesnt matter
ebpb_volume_label:	db 'HOSHROIN   '	; label, doesnt matter
ebpb_system_id:		db 'FAT12   '

;
; start
;
start:
	jmp main

;
; main
;
main:
	; initialize some segment registers (in case some weird BIOS wont)
	mov ax, 0			; cannot directly change DS/ES
	mov ds, ax			; YES, JUST ASSIGNS TO 0 (same below)
	mov es, ax
	mov ss, ax
	mov sp, 0x7C00			; 7C00 is where program starts, pushing to the stack decrements SP

	; switch video mode
	mov ah, 0
	mov al, 03h
	int 0x10

	; change background color
	mov ah, 0Bh
	mov bh, 0
	mov bl, 0Ch
	int 0x10

	; read sth from disk
	mov [ebpb_drive_type], dl	; BIOS should set dl to drive number
	mov ax, 1			; LBA=1, second sector
	mov cl, 15			; 15 sector to read (exclude boot sector)
	mov bx, KERNEL_OFFSET		; data buffer -> ES:BX, set to kernel
	call disk_read

	; printing
	mov si, msg_greeting	; only passing address
	call prts

	; wait key
	mov ah, 0
	int 16h

	; change background color back to default
	mov ah, 0Bh
	mov bh, 0
	mov bl, 0
	int 0x10
	
	call switch2pm

	jmp $

;
; error handlers
;
floppy_error:
	mov si, msg_read_failed		
	call prts			; print msg_read_failed

	jmp waitkey_reboot

waitkey_reboot:
	mov ah, 0
	int 16h				; int = 16h, ah = 0, wait for keypresses
	jmp 0FFFFh:0			; jump to beginning of BIOS, which kinda equals to reboot

.halt:
	cli				; disable interrupts
	hlt				; CPU will just keep halting

;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
prts:
	; save registers for later use
	push si
	push ax

.loop:
	lodsb		; loads from ds:si to al/ax/eax
	or al, al	; checks if al is null (gonna modify zero flags if yes)
	jz .done	; if zero flags, then jump

	; BIOS int 10h, ah = 0e -> print chr to screen in tty mode
	mov ah, 0x0e
	mov bh, 0	; page number (ignorable if in text mode)
	mov bl, 0Fh
	int 0x10

	jmp .loop

.done:
	; release the stack, fifo
	pop ax
	pop si
	ret

;
; Converts LBA address to CHS
; Params:
;   - ax: LBA address
; Returns:
;   - cx (bits 0-5): sector number
;   - cx (bits 6-15): cyclinder
;   - dh: head
;
lba_to_chs:
	push ax
	push dx				; intented to save dl but cant	

	xor dx, dx			; dx = 0
	div word [bpb_sector_per_track]	; ax = LBA / SectorPerTrack, dx = LBA % SectorPerTrack
	inc dx				; dx + 1 then dx = sector
	mov cx, dx			; cx = dx = sector
	
	xor dx, dx			; dx = 0
	div word [bpb_number_of_sides]	; ax = (LBA / SectorPerTrack) / Heads = cyclinder, dx = (LBA / SectorPerTrack) % Heads = head
	mov dh, dl			; dl is lower 8-bit of dx, dl = head
	mov ch, al			; al is lower 8-bit of ax, ch is higher of cx, ch = cyclinder
	shl ah, 6			; shl = shift bits left
	or cl, ah			; put in rest 2 bits of cylinder

	pop ax
	mov dl, al			; restore dl
	pop ax
	ret

;
; Read sectors from a disk
; Params:
;   - ax: LBA address
;   - cl: number of sectors to read (max 128)
;   - dl: drive number
;   - es:bx: memory address of where to store the data
;
disk_read:
	push ax				; save registers 'll be modified
	push bx
	push cx
	push dx
	push di

	push cx				; temply save cl (numbers of sectors)
	call lba_to_chs
	pop ax				; AL = number of sectors to read
	
	mov ah, 02h
	mov di, 3			; retry count
	
.retry:
	pusha				; save all registers
	stc				; set carry flag
	int 13h				; int 13h, ah = 2, read disk sectors
	jnc .done			; Jump if No Carry
	
	; read fails again
	popa
	call disk_reset
	
	dec di
	test di, di
	jnz .retry			; if di != 0, jump

.fail:
	; none attempt succeeded
	jmp floppy_error

.done:
	popa
	
	pop di				; restore modified registers
	pop dx
	pop cx
	pop bx
	pop ax
	ret

;
; Resets disk controller
; Params:
;   - dl: drive number
;
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret

%include "src/bootloader/32bit-gdt.asm"
%include "src/bootloader/32bit-print-string.asm"


;
; 32-bit Protected Mode begins
;
bits 32

BEGIN_PM:
	mov ebx, msg_greeting_pm
	call prts_pm

	call KERNEL_OFFSET		; kernel begins

	jmp $

;
; Global varibles
;
temp_hex_string: db '0x00', 0
msg_greeting: db 'Hello you useless cunt', ENDL, 0
msg_greeting_pm: db 'Big fuck you from 32-bit protected mode', 0
msg_read_failed: db 'Read from disk failed cunt' , ENDL, 0

;
; Bootloader sign
;
times 510-($-$$) db 0
dw 0AA55h
