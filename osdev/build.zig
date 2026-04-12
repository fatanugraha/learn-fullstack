const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_features_sub = std.Target.x86.featureSet(&.{ .sse, .sse2, .avx }),
    });
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "os.bin",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("kernel.zig"),
        }),
    });
    exe.addAssemblyFile(b.path("boot.s"));
    exe.setLinkerScript(b.path("linker.ld"));

    b.installArtifact(exe);
}
