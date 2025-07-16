const std = @import("std");
const log = @import("std").log;
const xr = @import("xr.zig");
const vk = @import("vulkan/context.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const extensions = &[_][:0]const u8{
        "XR_KHR_vulkan_enable",
        "XR_EXT_debug_utils",
        "XR_KHR_vulkan_enable2",
    };

    const xr_context = try xr.Context.init(allocator, extensions);
    defer xr_context.deinit();

    const vk_context = try vk.Context.init(try xr_context.getVulkanExtensions());
    defer vk_context.deinit();
}
