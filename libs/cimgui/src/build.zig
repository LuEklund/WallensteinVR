const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build, target: Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *Build.Module {
    const module = b.addModule("imgui", .{
        .root_source_file = b.path("libs/cimgui/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    module.addIncludePath(.{ .cwd_relative = "common/imgui" });
    module.addCSourceFile(.{ .file = b.path("common/imgui/imgui.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("common/imgui/imgui_widgets.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("common/imgui/imgui_tables.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("common/imgui/imgui_draw.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("common/imgui/imgui_demo.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("common/imgui/dcimgui.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("common/imgui/dcimgui_internal.cpp"), .flags = &.{""} });

    // Add SDL3 and Vulkan backends
    module.addCSourceFile(.{ .file = b.path("common/imgui/imgui_impl_sdl3.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("common/imgui/imgui_impl_vulkan.cpp"), .flags = &.{""} });

    // add the c bindings for SDL3 and Vulkan
    module.addCSourceFile(.{ .file = b.path("common/imgui/dcimgui_impl_sdl3.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("common/imgui/dcimgui_impl_vulkan.cpp"), .flags = &.{""} });

    return module;
}
