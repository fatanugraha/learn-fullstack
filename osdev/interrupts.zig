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
        .entrypoint = @intFromPtr(&handle_divide_error),
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

const InterruptFrame = struct {
    eip: u32,
    cs: u32,
    eflags: u32,
    // only populated when CPL transitioned.
    esp: u32,
    ss: u32,
};

export fn handle_divide_error(_: *InterruptFrame) callconv(.{ .x86_interrupt = .{} }) void {
    serial.Writer.print("DivByZero!");
    while (true) asm volatile ("hlt");
}

pub export var Table: [256]u64 = @splat(0);

pub var IDTR: u48 = undefined;
