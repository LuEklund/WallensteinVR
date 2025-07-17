const std = @import("std");
const log = @import("std").log;
const c = @import("../c.zig");

const Self = @This();

physical: c.VkPhysicalDevice,
logical: c.VkDevice,
graphics_queue: c.VkQueue,

pub fn init(instance: c.VkInstance) !Self {
    const physical = try selectPhysical(instance);
    const logical, const graphics_queue = try createLogicalDevice(physical);

    return .{
        .physical = physical,
        .logical = logical,
        .graphics_queue = graphics_queue,
    };
}

pub fn deinit(self: Self) void {
    c.vkDestroyDevice(self.logical);
}

pub fn selectPhysical(instance: c.VkInstance) !c.VkPhysicalDevice {
    var device_count: u32 = 0;
    try c.vkCheck(
        c.vkEnumeratePhysicalDevices(instance, &device_count, null),
        error.EnumeratePhysicalDevicesCount,
    );

    if (device_count == 0) return error.NoPhysicalDevicesFound;

    var physical_devices: [8]?c.VkPhysicalDevice = [_]?c.VkPhysicalDevice{null} ** 8;

    try c.vkCheck(
        c.vkEnumeratePhysicalDevices(instance, &device_count, @ptrCast(&physical_devices)),
        error.EnumeratePhysicalDevices,
    );

    var i: usize = 0;
    while (i < physical_devices.len and physical_devices[i] != null) {
        defer i += 1;
        const device = physical_devices[i].?;

        var properties: c.VkPhysicalDeviceProperties = undefined;
        c.vkGetPhysicalDeviceProperties(device, &properties);
        var features: c.VkPhysicalDeviceFeatures = undefined;
        c.vkGetPhysicalDeviceFeatures(device, &features);

        log.info("\t{d}/{d}: {s}", .{ properties.deviceID, device_count, properties.deviceName });

        if (properties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU and features.geometryShader == c.VK_TRUE) {
            log.info("\n\tSelected {s}\n", .{properties.deviceName});
            break;
        }
    }

    return physical_devices[i] orelse return error.InvalidPhysicalDevicesSelected;
}

const QueueFamilyIndices = struct {
    graphics_family: ?u32 = null,
};

fn findQueueFamilies(physical_device: c.VkPhysicalDevice) QueueFamilyIndices {
    const indices = QueueFamilyIndices{};

    var queue_family_count: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);

    std.debug.print("queue_family_count: {d} MAX 16\n", .{queue_family_count});
    const queue_families: [16]c.VkQueueFamilyProperties = undefined;
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_family_count);

    for (queue_families, 0..) |queue_family, i| {
        if (queue_family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
            indices.graphics_family = i;
        }
        if (indices.graphics_family != null) break;
    }
    return indices;
}

pub fn createLogicalDevice(physical_device: c.VkPhysicalDevice) !struct { c.VkDevice, c.VkQueue } {
    const indices: QueueFamilyIndices = findQueueFamilies(physical_device);

    // NOTE: Not used currently
    var queue_priority: f32 = 1.0;
    var queue_create_info = c.VkDeviceQueueCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = indices.graphics_family.?,
        .queueCount = 1,
        .pQueuePriorities = &queue_priority,
    };

    var device_features = c.VkPhysicalDeviceFeatures{};

    var create_info = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pQueueCreateInfos = &queue_create_info,
        .queueCreateInfoCount = 1,
        .pEnabledFeatures = &device_features,
        .enabledLayerCount = 0,
    };

    var logical_device: c.VkDevice = undefined;
    try c.vkCheck(
        c.vkCreateDevice(physical_device, &create_info, null, &logical_device),
        error.CreateDevice,
    );

    var graphics_queue: c.VkQueue = undefined;
    c.vkGetDeviceQueue(logical_device, indices.graphics_family.?, 0, &graphics_queue);

    return .{ logical_device, graphics_queue };
}

// NOTE: Might be used
// fn isDeviceSuitable(physical_device: c.VkPhysicalDevice) bool {
//     const indices: ?u32 = findQueueFamilies(physical_device);
//     return (indices != null);
// }
