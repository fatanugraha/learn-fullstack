const symbols = @import("symbols.zig");

const TSS = packed struct {
    prev_tss: u32,
    esp0: u32, // Kernel stack pointer
    ss0: u32, // Kernel stack segment
    unused: u704,
    iomap_base: u32,
};

pub const GDT = struct {
    gdtEntries: [6]u64,
    gdtr: u48,
    tssdata: TSS,

    pub fn initialize(self: *GDT) void {
        self.gdtEntries = [6]u64{
            0,

            // kernel code segment
            (Entry{
                .base = 0,
                .limit = 0x0fffff,
                .access_byte = .{
                    .accessed = 0,
                    .rw = 1,
                    .direction = 0,
                    .exec = 1,
                    .sys_type = 0,
                    .desc_type = 1,
                    .priv_level = 0,
                    .present = 1,
                },
                .flags = .{
                    .size = 1,
                    .granularity = 1,
                },
            }).pack(),

            // kernel data segment
            (Entry{
                .base = 0,
                .limit = 0xfffff,
                .access_byte = .{
                    .accessed = 0,
                    .rw = 1,
                    .direction = 0,
                    .exec = 0,
                    .sys_type = 0,
                    .desc_type = 1,
                    .priv_level = 0,
                    .present = 1,
                },
                .flags = .{
                    .size = 1,
                    .granularity = 1,
                },
            }).pack(),

            // user code segment
            (Entry{
                .base = 0,
                .limit = 0xfffff,
                .access_byte = .{
                    .accessed = 0,
                    .rw = 1,
                    .direction = 0,
                    .exec = 1,
                    .sys_type = 0,
                    .desc_type = 1,
                    .priv_level = 3,
                    .present = 1,
                },
                .flags = .{
                    .size = 1,
                    .granularity = 1,
                },
            }).pack(),

            // user data segment
            (Entry{
                .base = 0,
                .limit = 0xfffff,
                .access_byte = .{
                    .accessed = 0,
                    .rw = 1,
                    .direction = 0,
                    .exec = 0,
                    .sys_type = 0,
                    .desc_type = 1,
                    .priv_level = 3,
                    .present = 1,
                },
                .flags = .{
                    .size = 1,
                    .granularity = 1,
                },
            }).pack(),

            // tss
            (Entry{
                .base = @intFromPtr(&self.tssdata),
                .limit = 104,
                .access_byte = .{
                    .accessed = 0,
                    .rw = 0,
                    .direction = 0,
                    .exec = 0,
                    .sys_type = 9,
                    .desc_type = 0,
                    .priv_level = 0,
                    .present = 1,
                },
                .flags = .{
                    .granularity = 0,
                    .size = 0,
                },
            }).pack(),
        };

        self.tssdata = .{
            .prev_tss = 0,
            .esp0 = symbols.extern_stack_top.*,
            .ss0 = 0x10, // kernel data segment is at 0x10.
            .unused = 0,
            .iomap_base = @sizeOf(TSS),
        };

        self.gdtr = @bitCast(packed struct(u48) {
            limit: u16,
            base: u32,
        }{
            .limit = 8 * 6 - 1,
            .base = @intFromPtr(&self.gdtEntries),
        });
    }

    // ref: https://wiki.osdev.org/Global_Descriptor_Table
    const Entry = struct {
        base: u32,
        limit: u32,
        access_byte: struct {
            // code/data segment only
            accessed: u1,
            rw: u1,
            direction: u1,
            exec: u1,

            // system-segment only
            sys_type: u4,

            desc_type: u1, // 0: system segment, 1: code/data segment
            priv_level: u2,
            present: u1,
        },
        flags: struct {
            size: u1,
            granularity: u1,
        },

        fn pack(self: Entry) u64 {
            const flag: u4 = @as(u4, self.flags.granularity) << 3 |
                @as(u4, self.flags.size) << 2;

            var access_byte: u8 = @as(u8, self.access_byte.desc_type) << 4 |
                @as(u8, self.access_byte.priv_level) << 5 |
                @as(u8, self.access_byte.present) << 7;

            if (self.access_byte.desc_type == 1) {
                // code/data segment
                access_byte |= self.access_byte.accessed |
                    @as(u8, self.access_byte.rw) << 1 |
                    @as(u8, self.access_byte.direction) << 2 |
                    @as(u8, self.access_byte.exec) << 3;
            } else {
                // system segment
                access_byte |= self.access_byte.sys_type;
            }

            const val: packed struct(u64) {
                limit_low: u16,
                base_low: u24,
                access_byte: u8,
                limit_high: u4,
                flags: u4,
                base_high: u8,
            } = .{
                .limit_low = @truncate(self.limit),
                .base_low = @truncate(self.base & 0xffffff),
                .access_byte = access_byte,
                .limit_high = @truncate((self.limit & 0xff0000) >> 16),
                .flags = flag,
                .base_high = @truncate(self.base & 0xff000000 >> 24),
            };

            return @bitCast(val);
        }
    };
};
