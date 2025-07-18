const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // const c_source = b.addWriteFile("c_deps.h",
    //     \\#define XR_USE_GRAPHICS_API_VULKAN 1
    //     \\#define XR_EXTENSION_PROTOTYPES 1
    //     \\#include "vulkan/vulkan.h"
    //     \\#include "openxr/openxr.h"
    //     \\#include "openxr/openxr_platform.h"
    // );

    // const c_source_superior_language = b.addTranslateC(.{
    //     .target = target,
    //     .optimize = optimize,
    //     .root_source_file = c_source.getDirectory().path(b, "c_deps.h"),
    // });
    // c_source_superior_language.addSystemIncludePath(lazy_path: LazyPath)

    const loader_generator = b.addExecutable(.{
        .name = "loader-generator",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("tools/loader-generator.zig"),
        }),
    });
    loader_generator.linkSystemLibrary("vulkan");
    loader_generator.linkSystemLibrary("openxr_loader");
    // loader_generator.root_module.addImport("c-deps", c_source_superior_language.createModule());

    const loader_generator_run = b.addRunArtifact(loader_generator);
    const loader_zig = loader_generator_run.addOutputFileArg("loader.zig");

    const loader = b.addModule("loader", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = loader_zig,
        .link_libc = true,
    });
    loader.linkSystemLibrary("vulkan", .{});
    loader.linkSystemLibrary("openxr_loader", .{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("loader", loader);

    const exe = b.addExecutable(.{
        .name = "WallensteinVr",
        .root_module = exe_mod,
        .use_llvm = false,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
