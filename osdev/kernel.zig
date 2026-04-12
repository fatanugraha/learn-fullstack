const ggdt = @import("gdt.zig");

const stack_top = @extern(*u32, .{ .name = "stack_top" });
const user_stack_top = @extern(*u32, .{ .name = "user_stack_top" });

export fn kernel_main() noreturn {
    gdt = ggdt.setup_gdt(@intFromPtr(&tssdata));
    tssdata.esp0 = stack_top.*;
    tssdata.ss0 = 0x10; // kernel data segment is at 0x10.
    tssdata.iomap_base = @sizeOf(tss);

    // load the gdt table
    const gdtr: packed struct(u48) {
        limit: u16,
        base: u32,
    } = .{
        .limit = 8 * 6 - 1,
        .base = @intFromPtr(&gdt),
    };

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
        : [a] "r" (&gdtr),
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
          [esp] "r" (&user_stack_top),
        : .{ .ax = true });

    while (true) {
        asm volatile ("hlt");
    }
}

fn user_main() noreturn {
    const msg = "hello world!";
    print(msg);

    while (true) {}
}

const vga_mem: [*]u16 = @ptrFromInt(0xB8000);

inline fn print(str: []const u8) void {
    for (str, 0..) |c, i| {
        if (i > 10) {
            return;
        }

        vga_mem[i] = vga_entry(c);
    }
}

inline fn vga_entry(c: u8) u16 {
    const fg = 15;
    const bg = 0;
    const color: u8 = fg | bg << 4;
    return @as(u16, c) | (@as(u16, color) << 8);
}

var gdt: [6]u64 = undefined;

const tss = packed struct {
    prev_tss: u32,
    esp0: u32, // Kernel stack pointer
    ss0: u32, // Kernel stack segment
    unused: u704,
    iomap_base: u32,
};

var tssdata: tss = .{
    .prev_tss = 0,
    .esp0 = 0,
    .ss0 = 0,
    .unused = 0,
    .iomap_base = 0,
};
