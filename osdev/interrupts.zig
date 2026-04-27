const segment = @import("segment.zig");
const serial = @import("serial.zig");

const Descriptor = struct {
    entrypoint: u32,
    selector: u16,
    dpl: u2,
    gate_type: u4,

    fn pack(self: Descriptor) u64 {
        return @bitCast(
            packed struct {
                offset_low: u16,
                segment_selector: u16,
                _unused: u8 = undefined,
                attrs: u8,
                offset_high: u16,
            }{
                .offset_low = @truncate(self.entrypoint),
                .offset_high = @truncate(self.entrypoint >> 16),
                .segment_selector = self.selector,
                .attrs = @bitCast(packed struct {
                    gate_type: u4,
                    zero: u1 = 0,
                    dpl: u2,
                    present: u1,
                }{
                    .present = 1,
                    .dpl = self.dpl,
                    .gate_type = self.gate_type,
                }),
            },
        );
    }
};

pub fn initialize() void {
    Table[0] = (Descriptor{
        .entrypoint = @intFromPtr(&isr_wrapper2(66)),
        .selector = 0x08, // todo: put in segment
        .dpl = 0,
        .gate_type = 0xE, // 32-bit interrupt gate
    }).pack();

    IDTR = @bitCast(packed struct(u48) {
        limit: u16,
        base: u32,
    }{
        .limit = 8 * 256 - 1,
        .base = @intFromPtr(&Table),
    });
}

// const divide_error_handler = isr_wrapper1(handle_divide_error);

// export fn handle_divide_error(_: *InterruptFrame) callconv(.naked) void {
//     serial.Writer.print("DivByZero!");
//     while (true) asm volatile ("hlt");
// }

const InterruptFrame = extern struct {
    // pusha order (last-pushed first):
    edi: u32,
    esi: u32,
    ebp: u32,
    esp_dummy: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,
    // your stub pushed:
    vector_code: u32,
    error_code: u32,
    // CPU pushed:
    eip: u32,
    cs: u32,
    eflags: u32,
    // present only on cross-ring (read conditionally):
    user_esp: u32,
    user_ss: u32,
};

// fn isr_wrapper1(vector_code: u8) fn () callconv(.naked) void {
//     asm volatile (
//         \\pushl 0
//         \\pushl %vec
//         \\pushl %eip
//         \\pusha
//         \\jmp isr_common
//         :
//         : [vec] "i" (vector_code),
//     );

//     asm volatile (
//         \\popa
//         \\add esp, 12
//         \\iret
//     );
// }

fn isr_wrapper2(vector_code: u32) fn () callconv(.naked) void {
    return struct {
        fn wrapper() callconv(.naked) void {
            asm volatile (
                \\pushl $0
                \\pushl %[vec]
                \\pusha
                \\call isr_common
                :
                : [vec] "i" (vector_code),
            );

            asm volatile (
                \\popa
                \\add %esp, 8
                \\iret
            );
        }
    }.wrapper;
}

export fn isr_common(frame: InterruptFrame) callconv(.c) void {
    _ = frame;
    serial.Writer.puts("HERE!");
}

pub export var Table: [256]u64 = @splat(0);

pub var IDTR: u48 = undefined;
