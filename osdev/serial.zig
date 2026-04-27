const std = @import("std");
pub const COM1: u16 = 0x3F8;

pub const Writer = struct {
    pub fn initialize() void {
        // https://wiki.osdev.org/Serial_Ports
        // we use first port to print to QEMU's stdio (see Makefile).
        outb(COM1 + 1, 0); // disable interrupt.

        // 115200 baud rate. note that QEMU ignores this.
        outb(COM1 + 3, 0x80); // DLAB = 1
        outb(COM1 + 0, 0x1); // Divisor low
        outb(COM1 + 1, 0x0); // Divisor high

        // no parity. stop bits = 1. data bits = 8 bits (ASCII).
        outb(COM1 + 3, 0x03);
        // set 14 byte threshold + Enable FIFO.
        outb(COM1 + 2, 0xC7);
        // for convention, not too sure yet why.
        outb(COM1 + 4, 0x0B);
        // disable interrupt
        outb(COM1 + 1, 0x0);
    }

    pub fn puts(comptime str: []const u8) void {
        for (str) |c| Writer.putc(c);
    }

    pub fn putc(c: u8) void {
        outb(COM1, c);
    }
};

inline fn outb(port: u16, value: u8) void {
    asm volatile (
        \\outb %[value], %[port]
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}
