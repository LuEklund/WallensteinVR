const std = @import("std");
const c = @import("../c.zig");

const xr = @import("../xr.zig");

const Device = @import("device.zig");

pub const Context = struct {
    const Self = @This();

    instance: c.VkInstance,
    device: Device,

    pub fn init(extensions: []const [:0]const u8) !Self {
        const instance = try createInstance(extensions);
        const device = try Device.init(instance);

        return .{
            .instance = instance,
            .device = device,
        };
    }

    pub fn deinit(self: Self) void {
        c.vkDestroyInstance(self.instance, null);
    }

    fn createInstance(extensions: []const [:0]const u8) !c.VkInstance {
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
            .enabledExtensionCount = @intCast(extensions.len),
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
