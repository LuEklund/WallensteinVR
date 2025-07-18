const std = @import("std");
const log = @import("std").log;
const xr = @import("openxr.zig");
const vk = @import("vulkan.zig");
const c = @import("c.zig");

pub const Engine = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    xr_instance: c.XrInstance,
    xr_instance_extensions: []const [*:0]const u8,
    xr_debug_messenger: c.XrDebugUtilsMessengerEXT,
    vk_debug_messenger: c.VkDebugUtilsMessengerEXT,
    vk_instance: c.VkInstance,

    pub const Config = struct {
        xr_extensions: []const [*:0]const u8,
        xr_layers: []const [*:0]const u8,
        vk_layers: []const [*:0]const u8,
    };

    pub fn init(allocator: std.mem.Allocator, config: Config) !Self {
        const xr_instance: c.XrInstance = try xr.createInstance(config.xr_extensions, config.xr_layers);
        const xr_debug_messenger: c.XrDebugUtilsMessengerEXT = try xr.createDebugMessenger(xr_instance);
        const xr_system_id: c.XrSystemId = try xr.getSystem(xr_instance);
        const xr_graphics_requirements: c.XrGraphicsRequirementsVulkanKHR, const xr_instance_extensions: []const [*:0]const u8 = try xr.getVulkanInstanceRequirements(allocator, xr_instance, xr_system_id);

        const vk_instance: c.VkInstance = try vk.createInstance(xr_graphics_requirements, xr_instance_extensions, config.vk_layers);
        const vk_debug_messenger: c.VkDebugUtilsMessengerEXT = try vk.createDebugMessenger(vk_instance);

        const physical_device: c.VkPhysicalDevice, const vk_device_extensions: []const [*:0]const u8 = try xr.getVulkanDeviceRequirements(allocator, xr_instance, xr_system_id, vk_instance);
        const logical_device: c.VkDevice = try vk.createLogicalDevice(physical_device, vk_device_extensions);
        _ = logical_device;

        return .{
            .allocator = allocator,
            .xr_instance = xr_instance,
            .xr_instance_extensions = xr_instance_extensions,
            .xr_debug_messenger = xr_debug_messenger,
            .vk_debug_messenger = vk_debug_messenger,
            .vk_instance = vk_instance,
        };
    }

    pub fn deinit(self: Self) void {
        vk.destroyDebugMessenger(self.vk_instance, self.vk_debug_messenger);
        xr.destroyDebugMessenger(self.xr_instance, self.xr_debug_messenger); // Can prob be replaced with xorbits loader
        // self.allocator.free(self.xr_instance_extensions);
        _ = c.vkDestroyInstance(self.vk_instance, null);
        _ = c.xrDestroyInstance(self.xr_instance);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .verbose_log = true,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const xr_extensions = &[_][*:0]const u8{
        c.XR_KHR_VULKAN_ENABLE_EXTENSION_NAME,
        c.XR_KHR_VULKAN_ENABLE2_EXTENSION_NAME,
        c.XR_EXT_DEBUG_UTILS_EXTENSION_NAME,
    };
    const xr_layers = &[_][*:0]const u8{
        "XR_APILAYER_LUNARG_core_validation",
        "XR_APILAYER_LUNARG_api_dump",
    };

    const vk_layers = &[_][*:0]const u8{
        "VK_LAYER_KHRONOS_validation",
    };

    const engine = try Engine.init(allocator, .{
        .xr_extensions = xr_extensions,
        .xr_layers = xr_layers,
        .vk_layers = vk_layers,
    });
    defer engine.deinit();
}
