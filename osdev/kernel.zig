const segment = @import("segment.zig");
const serial = @import("serial.zig");
const symbols = @import("symbols.zig");

var gdt: segment.GDT = undefined;

export fn kernel_main() noreturn {
    serial.Writer.initialize();
    serial.Writer.print("[+] kernel booted\n");

    // load the gdt table
    gdt.initialize();

    asm volatile (
        \\cli
        \\lgdt (%[a])

        // reload cs register by performing long jump
        \\ljmp $0x08, $1f
        \\1:
        \\mov $0x10, %%ax
        \\mov %%ax, %%ds
        \\mov %%ax, %%es
        \\mov %%ax, %%fs
        \\mov %%ax, %%gs
        \\mov %%ax, %%ss
        :
        : [a] "r" (&gdt.gdtr),
        : .{ .ax = true, .memory = true });

    // load tss
    asm volatile (
        \\ltr %%ax
        :
        : [a] "r" (0x28),
    );

    // jump to user mode
    asm volatile (
    // 0x20 (user data segment) | 0x3 (user mode)
        \\mov $0x23, %%ax
        \\mov %%ax, %%ds
        \\mov %%ax, %%es
        \\mov %%ax, %%fs
        \\mov %%ax, %%gs
        // user ss
        \\push $0x23
        // user esp
        \\push %[esp]
        // user eflags
        \\pushf
        // user cs 0x18 | 3
        \\push $0x1b
        // user eip
        \\push %[eip]
        \\iret
        :
        : [eip] "r" (&user_main),
          [esp] "r" (&symbols.extern_user_stack_top),
        : .{ .ax = true });

    while (true) {
        asm volatile ("hlt");
    }
}

export fn user_main() noreturn {
    while (true) {}
}
