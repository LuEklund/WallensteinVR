const std = @import("std");
const c = @import("../c.zig");
const xr = @import("../xr.zig");

pub const Context = struct {
    const Self = @This();

    instance: c.VkInstance,
    device: struct {
        physical: c.VkPhysicalDevice,
        logical: c.VkDevice,
    },

    pub fn init(extensions: []const [:0]const u8) !Self {
        const instance = try createInstance(extensions);
        const physical_device = try createPhysicalDevice(instance);
        // const logical_device = try createLogicalDevice(instance);

        return .{
            .instance = instance,
            .device = .{
                .physical = physical_device,
                // .logical = logical_device,
            },
        };
    }

    pub fn deinit(_: Self) void {}

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

    fn createPhysicalDevice(instance: c.VkInstance) !c.VkPhysicalDevice {
        var device_count: u32 = 0;

        c.vkEnumeratePhysicalDevices(instance, &device_count, null);

        if (device_count == 0) {
            std.debug.print("Num physical devices in 0\n");
            return error.InvalidDeviceCount;
        }

        var physical_devices: [8]?c.VkPhysicalDevice = null ** 8;

        c.vkEnumeratePhysicalDevices(instance, &device_count, @ptrCast(&physical_devices));

        // debug
        std.debug.print("Found {d} num of GPUs!\n", .{device_count});

        return physical_devices[0];
    }
};
