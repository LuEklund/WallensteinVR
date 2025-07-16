const std = @import("std");
const c = @import("../c.zig");

pub const Context = struct {
    const Self = @This();

    instance: c.VkInstance,

    pub fn init() !Self {
        const instance = createInstance();

        return .{ .instance = instance };
    }

    pub fn deinit(_: Self) void {}

    fn createInstance(xr_instance: c.XrInstance) !c.VkInstance {
        var ext_str_len: u32 = 0;
        _ = c.xrGetVulkanInstanceExtensionsKHR(xr_instance, null, &ext_str_len, null);

        var buffer: [512]u8 = undefined;
        const ext_slice = buffer[0..ext_str_len];
        _ = c.xrGetVulkanInstanceExtensionsKHR(xr_instance, null, &ext_str_len, ext_slice.ptr);

        var extensions: [16][:0]const u8 = undefined;
        var count: usize = 0;
        var it = std.mem.splitAny(u8, ext_slice[0..ext_str_len], " ");
        while (it.next()) |ext| : (count += 1) extensions[count] = std.mem.span(ext);

        const app_info = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "WallensteinVR",
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "WallensteinVR_Engine",
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = c.VK_API_VERSION_1_0,
        };

        var create_info = c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledExtensionCount = @intCast(count),
            .ppEnabledExtensionNames = @ptrCast(&extensions),
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
        };

        var instance: c.VkInstance = undefined;
        try c.check(
            c.vkCreateInstance(&create_info, null, &instance),
            error.CreateInstance,
        );
        return instance;
    }
};
