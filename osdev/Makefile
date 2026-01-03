.PHONY: all clean run

all: 
	zig build 
	grub-file --is-x86-multiboot zig-out/bin/os.bin
	mkdir -p isodir/boot/grub
	cp zig-out/bin/os.bin isodir/boot/os.bin
	cp grub.cfg isodir/boot/grub/grub.cfg
	grub-mkrescue -o os.iso isodir

debug: all
	qemu-system-i386 -s -S -cdrom os.iso

gdb:
	gdb -x lol zig-out/bin/os.bin

clean:
	rm os.iso os.bin boot.o kernel.o
