const std = @import("std");

const c = @cImport({
    @cDefine("XR_USE_GRAPHICS_API_VULKAN", "1");
    @cDefine("XR_EXTENSION_PROTOTYPES", "1");
    @cInclude("vulkan/vulkan.h");
    @cInclude("openxr/openxr.h");
    @cInclude("openxr/openxr_platform.h");
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2)
        return error.@"missing output file arg";

    var output_file = try std.fs.cwd().createFile(args[1], .{});
    defer output_file.close();

    var buf_writer = std.io.bufferedWriter(output_file.writer());
    const writer = buf_writer.writer();

    try writer.writeAll(@embedFile("loader-generator-base.zig"));

    const s = @typeInfo(c).@"struct".decls;

    inline for (s) |decl| {
        @setEvalBranchQuota(100_000);

        if (comptime std.mem.startsWith(
            u8,
            decl.name[0..],
            "PFN_vk",
        )) try addVkWrapper(writer, decl);

        if (comptime std.mem.startsWith(
            u8,
            decl.name[0..],
            "PFN_xr",
        )) try addXrWrapper(writer, decl);
    }

    try buf_writer.flush();
}

fn addVkWrapper(
    writer: anytype,
    comptime decl: std.builtin.Type.Declaration,
) !void {
    const trimmed_name = std.mem.trimLeft(u8, decl.name, "PFN_vk");
    const Pfn = @typeInfo(@field(c, decl.name)).optional.child;

    try writer.print(
        \\
        \\pub const PfnVk{0s} = {1any};
        \\pub fn loadVk{0s}(instance_or_device: anytype) LoadError!PfnVk{0s} {{
        \\    var func: c.PFN_vkVoidFunction = null;
        \\    if (comptime @TypeOf(instance_or_device) == c.VkInstance) {{
        \\        func = c.vkGetInstanceProcAddr(instance_or_device, "vk{0s}");
        \\    }} else {{
        \\        func = c.vkGetDeviceProcAddr(instance_or_device, "vk{0s}");
        \\    }}
        \\    if (func == null) return error.LoadFailed;
        \\    return @ptrCast(func.?);
        \\}}
    , .{ trimmed_name, Pfn });
}

fn addXrWrapper(
    writer: anytype,
    comptime decl: std.builtin.Type.Declaration,
) !void {
    const trimmed_name = std.mem.trimLeft(u8, decl.name, "PFN_xr");
    const Pfn = @typeInfo(@field(c, decl.name)).optional.child;

    try writer.print(
        \\
        \\pub const PfnXr{0s} = {1any};
        \\pub fn loadXr{0s}(instance: c.XrInstance) (LoadError || XrError)!PfnXr{0s} {{
        \\    var func: c.PFN_vkVoidFunction = null;
        \\    try xrCheck(c.xrGetInstanceProcAddr(instance, "xr{0s}", &func), LoadError.LoadFailed);
        \\    if (func == null) return LoadError.LoadFailed;
        \\    return @ptrCast(func.?);
        \\}}
    , .{ trimmed_name, Pfn });
}
