//! CompileShaders is used to compile shader files from an input directory
//! to an output directory using glslc
pub const base_id: Step.Id = .custom;

pub const Options = struct {
    in_dir: LazyPath,
};

pub fn create(owner: *std.Build, options: Options) *@This() {
    const self = owner.allocator.create(@This()) catch @panic("OOM");
    const in_dir_dupe = options.in_dir.dupe(owner);
    self.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = owner.fmt("compile shaders from '{s}'", .{in_dir_dupe.getDisplayName()}),
            .owner = owner,
            .makeFn = make,
        }),
        .in_dir = in_dir_dupe,
        .out_dir = .{ .step = &self.step },
    };
    in_dir_dupe.addStepDependencies(&self.step);
    return self;
}

pub fn getOutputDir(self: *@This()) LazyPath {
    return .{ .generated = .{ .file = &self.out_dir } };
}

fn make(step: *Step, options: Step.MakeOptions) !void {
    const b = step.owner;
    const gpa = b.allocator;
    const self: *@This() = @fieldParentPtr("step", step);

    const glslc_path = b.findProgram(&.{"glslc"}, &.{}) catch |err| switch (err) {
        error.FileNotFound => @panic("glslc not found in PATH"), // double-check that you have vulkan sdk installed or install it from https://github.com/google/shaderc
    };

    var man = b.graph.cache.obtain();
    defer man.deinit();

    _ = try man.addFile(glslc_path, null);

    const in_dir_path = self.in_dir.getPath3(b, step);
    const need_derived_inputs = try step.addDirectoryWatchInput(self.in_dir);

    var in_dir = in_dir_path.root_dir.handle.openDir(in_dir_path.subPathOrDot(), .{ .iterate = true }) catch |err| {
        return step.fail("unable to open source directory '{f}': {s}", .{
            in_dir_path, @errorName(err),
        });
    };
    defer in_dir.close();

    var files_to_compile = ArrayList([]const u8).init(gpa);
    defer files_to_compile.deinit();

    var it = try in_dir.walk(gpa);
    defer it.deinit();
    while (try it.next()) |entry| {
        if (!isShaderFile(entry.path)) continue;

        switch (entry.kind) {
            .directory => {
                if (need_derived_inputs) {
                    const entry_path = try in_dir_path.join(gpa, entry.path);
                    try step.addDirectoryWatchInputFromPath(entry_path);
                }
            },
            .file => {
                const entry_path = try in_dir_path.join(gpa, entry.path);
                _ = try man.addFilePath(entry_path, null);
                try files_to_compile.append(try gpa.dupe(u8, entry.path));
            },
            else => continue,
        }
    }

    if (try step.cacheHit(&man)) {
        const digest = man.final();
        self.out_dir.path = try b.cache_root.join(gpa, &.{ "o", &digest });
        step.result_cached = true;
        return;
    }

    const digest = man.final();
    const out_dir_rel_path = try std.fs.path.join(gpa, &.{ "o", &digest });
    const cache_path_str = try b.cache_root.join(gpa, &.{out_dir_rel_path});
    self.out_dir.path = cache_path_str;

    var cache_dir = b.cache_root.handle.makeOpenPath(out_dir_rel_path, .{}) catch |err| {
        return step.fail("unable to make path '{s}': {s}", .{ cache_path_str, @errorName(err) });
    };
    defer cache_dir.close();

    for (files_to_compile.items) |rel_path| {
        const in_file_path = try in_dir_path.joinString(gpa, rel_path);

        const out_rel_path = try std.fmt.allocPrint(gpa, "{s}.spv", .{rel_path});
        const out_full_path = b.pathJoin(&.{ cache_path_str, out_rel_path });

        if (fs.path.dirname(out_rel_path)) |dirname| {
            try cache_dir.makePath(dirname);
        }

        const argv = &[_][]const u8{
            glslc_path,
            in_file_path,
            "-o",
            out_full_path,
        };

        const result = try step.captureChildProcess(options.progress_node, argv);
        if (result.term.Exited != 0) {
            return step.fail("glslc failed to compile '{s}':\n{s}", .{ in_file_path, result.stderr });
        }
    }

    try step.writeManifest(&man);
}

fn isShaderFile(path: []const u8) bool {
    const extensions = [_][]const u8{ ".vert", ".frag", ".tesc", ".tese", ".geom", ".comp", ".glsl" };
    for (extensions) |ext| {
        if (mem.endsWith(u8, path, ext)) {
            return true;
        }
    }
    return false;
}

step: Step,
in_dir: LazyPath,
out_dir: std.Build.GeneratedFile,

const std = @import("std");
const Step = std.Build.Step;
const LazyPath = std.Build.LazyPath;
const fs = std.fs;
const mem = std.mem;
const ArrayList = std.ArrayList;
