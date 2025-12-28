const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
    });
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "os.bin",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.addCSourceFile(.{ .file = b.path("kernel.c") });
    exe.addAssemblyFile(b.path("boot.s"));
    exe.setLinkerScript(b.path("linker.ld"));

    b.installArtifact(exe);
}
