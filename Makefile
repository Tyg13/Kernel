all: linker.ld multiboot_header.o boot.o
	ld -n -o kernel.bin -T linker.ld multiboot_header.o boot.o

multiboot_header.o: multiboot_header.asm
	nasm -f elf64 multiboot_header.asm

boot.o: boot.asm
	nasm -f elf64 boot.asm
