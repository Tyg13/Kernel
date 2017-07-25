global start

section .text
bits 32 ; needed since CPU is still in protected mode (32 bit)
start:
    ; print 'OK' to screen
    mov dword [0xb8000], 0x2f4b2f4f
    hlt