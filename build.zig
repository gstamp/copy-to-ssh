const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{
        .os_tag = .windows,
        .cpu_arch = .x86_64,
    } });

    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "sync-to-remote",
        .root_module = mod,
    });

    // Windows GUI subsystem (no console window)
    exe.subsystem = .Windows;

    // Link required Windows libraries
    exe.root_module.linkSystemLibrary("user32", .{});
    exe.root_module.linkSystemLibrary("shell32", .{});
    exe.root_module.linkSystemLibrary("gdi32", .{});
    exe.root_module.linkSystemLibrary("gdiplus", .{});
    exe.root_module.linkSystemLibrary("ole32", .{});
    exe.root_module.linkSystemLibrary("comctl32", .{});
    exe.root_module.linkSystemLibrary("advapi32", .{});

    // Embed directory for @embedFile
    exe.root_module.addEmbedPath(b.path("src"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run sync-to-remote");
    run_step.dependOn(&run_cmd.step);
}
