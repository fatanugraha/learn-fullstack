.PHONY: all clean run

all:
	zig build -Doptimize=Debug
	grub2-file --is-x86-multiboot zig-out/bin/os.bin
	mkdir -p isodir/boot/grub
	cp zig-out/bin/os.bin isodir/boot/os.bin
	cp grub.cfg isodir/boot/grub/grub.cfg
	grub2-mkrescue -o os.iso isodir

run: all
	qemu-system-i386 -display gtk -cdrom os.iso -no-reboot -d int,cpu_reset -D qemu.log

debug: all
	qemu-system-i386 -display gtk -s -S -cdrom os.iso -no-reboot -d int,cpu_reset -D qemu.log

gdb:
	gdb -x lol zig-out/bin/os.bin

clean:
	rm os.iso os.bin boot.o kernel.o
