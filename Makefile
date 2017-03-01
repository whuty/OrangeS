#########################
# Makefile for Orange'S #
#########################

# Entry point of Orange'S
# It must have the same value with 'KernelEntryPointPhyAddr' in load.inc!
ENTRYPOINT	= 0x30400

# Offset of entry point in kernel file
# It depends on ENTRYPOINT
ENTRYOFFSET	=   0x400

# Programs, flags, etc.
ASM = nasm
DASM= ndisasm
CC = gcc
LD = ld
ASMBFLAGS = -I boot/include/
ASMKFLAGS = -I include/ -f elf
CFLAGS    = -I include/ -c -fno-builtin -fno-stack-protector -m32
LDFLAGS   = -s -Ttext $(ENTRYPOINT) -m elf_i386
DASMFLAGS = -u -o $(ENTRYPOINT) -e $(ENTRYOFFSET)

# This Program
ORANGESBOOT = boot/boot.bin boot/loader.bin
ORANGESKERNEL=kernel.bin
OBJS		= kernel/kernel.o kernel/start.o lib/kliba.o lib/string.o \
  lib/klib.o kernel/global.o kernel/i8259.o kernel/protect.o kernel/main.o
DASMOUTPUT	= kernel.bin.asm

# All Phony Targets
.PHONY : everything final image clean realclean disasm all buildimg

# Default starting position
everything : $(ORANGESBOOT) $(ORANGESKERNEL)

all : realclean everything

final: all clean

image:final buildimg

clean:
	rm -f $(OBJS)

realclean:
	rm -f $(OBJS) $(ORANGESBOOT) $(ORANGESKERNEL)

disasm:
	$(DASM) $(DASMFLAGS) $(ORANGESKERNEL) > $(DASMOUTPUT)

# We assume that "a.img" exists in current folder
buildimg :
	dd if=boot/boot.bin of=a.img bs=512 count=1 conv=notrunc
	sudo mount -o loop a.img /mnt/floppy/
	sudo cp -fv boot/loader.bin /mnt/floppy/
	sudo cp -fv kernel.bin /mnt/floppy
	sudo umount /mnt/floppy

boot/boot.bin : boot/boot.asm boot/include/load.inc \
 boot/include/fat12hdr.inc
	$(ASM) $(ASMBFLAGS) -o $@ $<

boot/loader.bin : boot/loader.asm boot/include/load.inc \
			boot/include/fat12hdr.inc boot/include/pm.inc
	$(ASM) $(ASMBFLAGS) -o $@ $<

$(ORANGESKERNEL) : $(OBJS)
	$(LD) $(LDFLAGS) -o $(ORANGESKERNEL) $(OBJS)

kernel/kernel.o : kernel/kernel.asm include/sconst.inc
	$(ASM) $(ASMKFLAGS) -o $@ $<

kernel/start.o : kernel/start.c /usr/include/stdc-predef.h include/type.h \
 include/const.h include/protect.h include/proto.h include/string.h \
 include/global.h
	$(CC) $(CFLAGS) -o $@ $<

kernel/i8259.o : kernel/i8259.c /usr/include/stdc-predef.h include/type.h \
 include/const.h include/protect.h include/proto.h
	$(CC) $(CFLAGS) -o $@ $<

kernel/global.o : kernel/global.c include/type.h \
 include/const.h include/protect.h include/proto.h include/proc.h \
 include/global.h
	$(CC) $(CFLAGS) -o $@ $<

kernel/protect.o : kernel/protect.c /usr/include/stdc-predef.h include/type.h \
 include/const.h include/protect.h include/global.h include/proto.h
	$(CC) $(CFLAGS) -o $@ $<

kernel/main.o: kernel/main.c /usr/include/stdc-predef.h include/type.h \
 include/const.h include/protect.h include/proto.h include/string.h \
 include/proc.h include/global.h
 	$(CC) $(CFLAGS) -o $@ $<

lib/klib.o : lib/klib.c /usr/include/stdc-predef.h include/type.h \
 include/const.h include/protect.h include/proto.h include/string.h \
 include/global.h
	$(CC) $(CFLAGS) -o $@ $<

lib/kliba.o : lib/kliba.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<

lib/string.o : lib/string.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<