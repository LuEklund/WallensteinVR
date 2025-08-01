const std = @import("std");
const CompileShaders = @import("build/CompileShaders.zig");

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
        .imports = &.{
            .{ .name = "loader", .module = loader },
        },
    });

    const exe = b.addExecutable(.{
        .name = "WallensteinVr",
        .root_module = exe_mod,
    });

    const sdl3 = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("sdl3", sdl3.module("sdl3"));

    const numz_dep = b.dependency("numz", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("numz", numz_dep.module("numz"));

    const build_options = b.addOptions();
    const eye_count = b.option(u8, "eye_count", "eye count") orelse 2;
    build_options.addOption(u8, "eye_count", eye_count);
    exe_mod.addOptions("build_options", build_options);

    const shader_compile_step = addCompileShaders(b, .{
        .in_dir = b.path("assets/shaders"),
    });

    const install_shaders_step = b.addInstallDirectory(.{
        .source_dir = shader_compile_step.getOutputDir(),
        .install_dir = .bin,
        .install_subdir = "shaders",
    });
    b.installArtifact(exe);
    b.getInstallStep().dependOn(&install_shaders_step.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    // set the working directory to the installation's `bin` directory,
    // so the executable can find its assets (like shaders)
    run_cmd.cwd = .{ .cwd_relative = b.exe_dir };
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

fn addCompileShaders(b: *std.Build, options: CompileShaders.Options) *CompileShaders {
    const step = CompileShaders.create(b, options);
    return step;
}
