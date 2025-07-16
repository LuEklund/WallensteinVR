const std = @import("std");
const log = @import("std").log;
const xr = @import("xr.zig");
const c = @import("c.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const extensions = &[_][:0]const u8{
        "XR_KHR_vulkan_enable",
        "XR_EXT_debug_utils",
        "XR_KHR_vulkan_enable2",
    };

    const context = try xr.Context.init(allocator, extensions);
    defer context.deinit();
}
