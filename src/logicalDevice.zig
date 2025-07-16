const std = @import("std");
const c = @import("c.zig");




var graphics_queue: c.VkQueue = undefined;

const QueueFamilyIndices = struct {
    const Self = @This();
    graphics_family: ?u32 = null,

    pub fn isComplete(self: Self) bool {
        return self.graphics_family != null;
    }
};

fn findQueueFamilies(physical_device: c.VkPhysicalDevice) QueueFamilyIndices {
    const indices: QueueFamilyIndices = undefined;

    var queue_family_count: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);

    std.debug.print("queue_family_count: {d} MAX 16\n", .{queue_family_count});
    const queue_families: [16]c.VkQueueFamilyProperties = undefined;
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_family_count);

    for (queue_families, 0..) |queue_family, i| {
        if (queue_family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) {
            indices.graphics_family = i;
        }
        if (indices.isComplete()) break;
    }
    return indices;
}

fn isDeviceSuitable(physical_device: c.VkPhysicalDevice) bool {
    const indices: QueueFamilyIndices = findQueueFamilies(physical_device);
    return (indices.isComplete());
}

fn createLogicalDevice(physical_device: c.VkPhysicalDevice) c.VkDevice {
    const indices: QueueFamilyIndices = findQueueFamilies(physical_device);

    var queue_priority: f32 = 1.0;
    var queue_create_info = c.VkDeviceQueueCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = indices.graphics_family,
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
    //TODO: Remeber to Destroy Logical Device once done
    try c.check(c.vkCreateDevice(&physical_device, &create_info, null, &logical_device), error.CreateDevice, );
    c.vkGetDeviceQueue(logical_device, indices.graphics_family, 0, &graphics_queue);
    return logical_device;
}
