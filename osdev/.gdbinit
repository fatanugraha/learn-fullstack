set confirm off
set pagination off
set print pretty on
set disassemble-next-line on
set arch i386

file zig-out/bin/os.bin
target remote localhost:1234

display/i $eip
display/x $eax
display/x $esp

layout split
b kernel_main
c
