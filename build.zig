const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    //const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zigt.elf", "src/main.zig");
    exe.setTarget(std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m0 },
        .os_tag = .freestanding,
        .abi = .none,
    });
    exe.setBuildMode(mode);
    exe.addPackagePath("hla", "extern/zig_hla/lib.zig");
    exe.setLinkerScriptPath(.{ .path = "nrf51_xxaa.ld" });
    //exe.addAssemblyFile("nrf5_sdk/modules/nrfx/mdk/gcc_startup_nrf51.S");
    //exe.addCSourceFile("nrf5_sdk/modules/nrfx/mdk/system_nrf51.c", &[_][]const u8{});
    exe.install();
}
