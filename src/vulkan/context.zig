const std = @import("std");
const log = @import("std").log;
const c = @import("../c.zig");

const xr = @import("../xr.zig");

const Device = @import("device.zig");

export fn debugCallback(
    message_severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    _: c.VkDebugUtilsMessageTypeFlagsEXT,
    callback_data: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT,
    _: ?*anyopaque,
) callconv(.C) c.VkBool32 {
    const prefix: []const u8 = switch (message_severity) {
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => "info",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => "warn", // ← fix typo from "wanr"
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => "error",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => "verbose",
        else => "unknown",
    };

    log.info("[Vulkan {s}]: {s}\n", .{ prefix, std.mem.sliceTo(callback_data.*.pMessage, 0) });
    return c.VK_FALSE;
}

pub const Context = struct {
    const Self = @This();

    instance: c.VkInstance,
    device: Device,

    pub fn init(extensions: []const [*:0]const u8) !Self {
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

    fn createInstance(extensions: []const [*:0]const u8) !c.VkInstance {
        const validation_layers: []const [*:0]const u8 = &.{
            "VK_LAYER_KHRONOS_validation",
        };

        const debug_info = c.VkDebugUtilsMessengerCreateInfoEXT{
            .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = debugCallback,
            .pUserData = null,
        };

        var create_info = c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = &debug_info,
            .flags = 0,
            .ppEnabledExtensionNames = extensions.ptr,
            .enabledExtensionCount = @intCast(extensions.len),
            .ppEnabledLayerNames = validation_layers.ptr,
            .enabledLayerCount = @intCast(validation_layers.len),

            .pApplicationInfo = &.{
                .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
                .pNext = null,
                .pApplicationName = "WallensteinVR",
                .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
                .pEngineName = "WallensteinVR_Engine",
                .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
                .apiVersion = c.VK_API_VERSION_1_0,
            },
        };

        var instance: c.VkInstance = undefined;
        try c.check(
            c.vkCreateInstance(&create_info, null, &instance),
            error.CreateInstance,
        );
        return instance;
    }
};
