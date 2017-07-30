global start
extern long_mode_start

section .text
bits 32 ; needed since CPU is still in protected mode (32 bit)
start:
    ; initialize stack pointer to our reserved stack space
    mov esp, stack_top

    call check_multiboot
    call check_cpuid
    call check_long_mode

    call set_up_page_tables
    call enable_paging

    ; load 64-bit GDT (for segments -- outdated)
    lgdt [gdt64.pointer]

    jmp gdt64.code:long_mode_start

; Prints 'ERR: ' and the given error code to screen and hangs
; parameter: error code (in ascii) in al
error:
    mov dword [0xb8000], 0x4f524f45
    mov dword [0xb8004], 0x4f3a4f52
    mov dword [0xb8008], 0x4f204f20
    mov byte  [0xb800a], al
    hlt

check_multiboot:
    cmp eax, 0x36d76289
    jne .no_multiboot
    ret
.no_multiboot:
    mov al, "0"
    jmp error

check_cpuid:
    ; Attempt to flip the ID bit (bit 21) in the flags register.
    ; If flippable, CPUID is available

    pushfd ; pushes flags onto stack
    pop eax

    mov ecx, eax

    ; flip cpuid bit in copy
    xor eax, 1 << 21 

    push eax
    popfd ; puts stack into flags

    pushfd
    pop eax ; back into eax to see if bit was flipped back

    push ecx
    popfd ; put original flags back in (to preserve CPUID if ever flipped)

    ; If equal, flipping the bit turned it on in the first place
    ; thus CPUID is off
    cmp eax, ecx
    je .no_cpuid
    ret
.no_cpuid:
    mov al, "1"
    jmp error

check_long_mode:
    ; test if extended processor info available
    mov eax, 0x80000000 ; check highest support argument
    cpuid               ; get highest supported argument into eax
    cmp eax, 0x80000001 ; must be at least this high
    jb .no_long_mode    ; if less, no extended info, no long mode

    ; use extended info to test if long mode available
    mov eax, 0x80000001 ; check long mode
    cpuid               ; returns features into ecx and edx
    test edx, 1 << 29   ; check if LM-bit set in edx
    jz .no_long_mode    ; if not, no long mode
    ret
.no_long_mode:
    mov al, "2"
    jmp error

set_up_page_tables:
    ; map first P4 entry to P3
    mov eax, p3_table
    or eax, 0b11 ; present + writable
    mov [p4_table], eax

    ; map first P3 entry to P2 table
    mov eax, p2_table
    or eax, 0b11 ; present + writable
    mov [p3_table], eax

    ; map each P2 entry to a 2MiB page
    mov ecx, 0   ; counter variable

.map_p2_table:
    ; map each ecx-th P2 entry to a huge 2MiB page
    mov eax, 0x200000   ; 2MiB
    mul ecx             ; start address at 2MiB*ecx address
    or eax, 0b10000011  ; present + writable + huge
    mov [p2_table + ecx * 8], eax ; map each entry (8 bits long)

    inc ecx             ; increase counter
    cmp ecx, 512        ; if counter == 512, whole table is mapped
    jne .map_p2_table   ; otherwise, map the next entry

    ret

enable_paging:
    ; load P4 to cr3 register (so cpu can see page table)
    mov eax, p4_table
    mov cr3, eax

    ; enable PAE-flag in cr4
    mov eax, cr4
    or eax, 1 << 5 ; flip PAE bit
    mov cr4, eax

    ;set the long mode bit in the EFER MSR (model specific register)
    mov ecx, 0xC0000080 ; location of EFER
    rdmsr ; read register in ecx into eax
    or eax, 1 << 8 ; set long mode bit
    wrmsr ; write into register in ecx using eax

    ; enable paging in cr0
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ret

section .rodata
gdt64:
    dq 0 ; zero entry
.code: equ $ - gdt44
    dq (1 << 43) | (1 << 44) | (1 << 47) || (1 << 53) ; code segment
.pointer:
    dw $ - gdt64 - 1
    dq gdt64

section .bss
align 4096
p4_table:
    resb 4096
p3_table:
    resb 4096
p2_table:
    resb 4096
stack_bottom:
    resb 64
stack_top: