const std = @import("std");
const log = @import("std").log;
const xr = @import("xr.zig");
const c = @import("c.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const xr_extensions = &[_][*:0]const u8{
        "XR_KHR_vulkan_enable",
        "XR_KHR_vulkan_enable2",
        c.XR_EXT_DEBUG_UTILS_EXTENSION_NAME,
    };
    const xr_layers = &[_][*:0]const u8{
        "XR_APILAYER_LUNARG_core_validation",
        "XR_APILAYER_LUNARG_api_dump",
    };

    // const vk_context = try vk.Context.init(try xr.Context.getVulkanExtensions());
    // defer vk_context.deinit();

    const xr_context = try xr.Context.init(allocator, xr_extensions, xr_layers);
    defer xr_context.deinit();
}
