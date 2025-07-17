const std = @import("std");
const log = @import("std").log;
const xr = @import("xr.zig");
const vk = @import("vulkan.zig");
const c = @import("c.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .verbose_log = true,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // const allocator = std.heap.page_allocator;

    const xr_extensions = &[_][*:0]const u8{
        c.XR_KHR_VULKAN_ENABLE_EXTENSION_NAME,
        c.XR_KHR_VULKAN_ENABLE2_EXTENSION_NAME,
        c.XR_EXT_DEBUG_UTILS_EXTENSION_NAME,
    };
    const xr_layers = &[_][*:0]const u8{
        "XR_APILAYER_LUNARG_core_validation",
        "XR_APILAYER_LUNARG_api_dump",
    };

    const xr_context = try xr.Context.init(allocator, xr_extensions, xr_layers);
    defer xr_context.deinit();

    // const vk_instance = vk.createInstance();

    // const session = xr.Session.init(xr_context, );
}
