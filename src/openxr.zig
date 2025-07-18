const std = @import("std");
const log = @import("std").log;

const c = @import("c.zig");

pub fn createInstance(extensions: []const [*:0]const u8, layers: []const [*:0]const u8) !c.XrInstance {
    var create_info = c.XrInstanceCreateInfo{
        .type = c.XR_TYPE_INSTANCE_CREATE_INFO,
        .next = null,
        .createFlags = 0,
        .applicationInfo = .{
            .applicationName = ("WallensteinVR\x00" ++ [1]u8{0} ** (128 - "WallensteinVR\x00".len)).*, //mafs
            .applicationVersion = 1,
            .engineName = ("WallensteinVR_Engine\x00" ++ [1]u8{0} ** (128 - "WallensteinVR_Engine\x00".len)).*,
            .engineVersion = 1,
            .apiVersion = c.XR_MAKE_VERSION(1, 0, 34), // c.XR_CURRENT_API_VERSION <-- Too modern for Steam VR
        },
        .enabledExtensionNames = @ptrCast(extensions.ptr),
        .enabledExtensionCount = @intCast(extensions.len),
        .enabledApiLayerCount = @intCast(layers.len),
        .enabledApiLayerNames = @ptrCast(layers.ptr),
    };

    var instance: c.XrInstance = undefined;
    try c.xrCheck(
        c.xrCreateInstance(&create_info, &instance),
        error.CreateInstance,
    );

    return instance;
}

pub fn getXRFunction(
    comptime T: type,
    instance: c.XrInstance,
    name: [*:0]const u8,
) !switch (@typeInfo(T)) {
    .optional => |O| O.child,
    else => T,
} {
    var func: c.PFN_xrVoidFunction = undefined;

    try c.xrCheck(
        c.xrGetInstanceProcAddr(instance, name, &func),
        error.GetInstanceProcAddr,
    );

    return @ptrCast(func);
}

fn handleXRError(severity: c.XrDebugUtilsMessageSeverityFlagsEXT, @"type": c.XrDebugUtilsMessageTypeFlagsEXT, callback_data: *const c.XrDebugUtilsMessengerCallbackDataEXT, _: *anyopaque) c.XrBool32 {
    const type_str: []const u8 = switch (@"type") {
        c.XR_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT => "general",
        c.XR_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT => "validation",
        c.XR_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT => "performance",
        c.XR_DEBUG_UTILS_MESSAGE_TYPE_CONFORMANCE_BIT_EXT => "conformance",
        else => "other",
    };

    const severity_str = switch (severity) {
        c.XR_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => "(verbose)",
        c.XR_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => "(info)",
        c.XR_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => "(warning)",
        c.XR_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => "(error)",
        else => "(other)",
    };

    log.err("XR: {s}: {s}: {s}\n", .{ type_str, severity_str, callback_data.message });

    return c.XR_FALSE;
}

pub fn createDebugMessenger(instance: c.XrInstance) !c.XrDebugUtilsMessengerEXT {
    var debug_messenger: c.XrDebugUtilsMessengerEXT = undefined;

    var debug_messenger_create_info = c.XrDebugUtilsMessengerCreateInfoEXT{
        .type = c.XR_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .next = null,
        .messageSeverities = c.XR_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT |
            c.XR_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            c.XR_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        .messageTypes = c.XR_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            c.XR_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            c.XR_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT |
            c.XR_DEBUG_UTILS_MESSAGE_TYPE_CONFORMANCE_BIT_EXT,
        .userCallback = @ptrCast(&handleXRError),
        .userData = null,
    };

    // const PFN_xrCreateDebugUtilsMessengerEXT = *const fn (
    //     instance: c.XrInstance,
    //     createInfo: *const c.XrDebugUtilsMessengerCreateInfoEXT,
    //     messenger: *c.XrDebugUtilsMessengerEXT,
    // ) callconv(.c) c.XrResult;

    const xrCreateDebugUtilsMessengerEXT = try getXRFunction(c.PFN_xrCreateDebugUtilsMessengerEXT, instance, "xrCreateDebugUtilsMessengerEXT");

    try c.xrCheck(
        xrCreateDebugUtilsMessengerEXT(instance, &debug_messenger_create_info, &debug_messenger),
        error.CreateDebugUtilsMessengerEXT,
    );

    return debug_messenger;
}

pub fn destroyDebugMessenger(instance: c.XrInstance, debug_messenger: c.XrDebugUtilsMessengerEXT) void {
    const xrDestroyDebugUtilsMessengerEXT = getXRFunction(c.PFN_xrDestroyDebugUtilsMessengerEXT, instance, "xrDestroyDebugUtilsMessengerEXT") catch unreachable;

    _ = xrDestroyDebugUtilsMessengerEXT(debug_messenger);
}

pub fn getSystem(instance: c.XrInstance) !c.XrSystemId {
    var system_get_info = c.XrSystemGetInfo{
        .type = c.XR_TYPE_SYSTEM_GET_INFO,
        .formFactor = c.XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY,
    };

    var system_id: c.XrSystemId = undefined;
    try c.xrCheck(
        c.xrGetSystem(instance, &system_get_info, &system_id),
        error.getSystem,
    );

    return system_id;
}

pub fn getVulkanInstanceRequirements(allocator: std.mem.Allocator, instance: c.XrInstance, system_id: c.XrSystemId) !struct { c.XrGraphicsRequirementsVulkanKHR, []const [*:0]const u8 } {
    // const PFN_xrGetVulkanGraphicsRequirementsKHR = *const fn (
    //     instance: c.XrInstance,
    //     system_id: c.XrSystemId,
    //     graphics_requirements: *c.XrGraphicsRequirementsVulkanKHR,
    // ) callconv(.c) c.XrResult;

    const xrGetVulkanGraphicsRequirementsKHR = try getXRFunction(c.PFN_xrGetVulkanGraphicsRequirementsKHR, instance, "xrGetVulkanGraphicsRequirementsKHR");

    log.info("\n\nXR Func PTR 2 {}\n\n", .{&xrGetVulkanGraphicsRequirementsKHR});

    const xrGetVulkanInstanceExtensionsKHR = try getXRFunction(c.PFN_xrGetVulkanInstanceExtensionsKHR, instance, "xrGetVulkanInstanceExtensionsKHR");

    var graphics_requirements = c.XrGraphicsRequirementsVulkanKHR{
        .type = c.XR_TYPE_GRAPHICS_REQUIREMENTS_VULKAN_KHR,
    };

    try c.xrCheck(
        xrGetVulkanGraphicsRequirementsKHR(instance, system_id, &graphics_requirements),
        error.GetVulkanGraphicsRequirement,
    );

    var instance_extensions_size: u32 = 0;
    try c.xrCheck(
        xrGetVulkanInstanceExtensionsKHR(instance, system_id, 0, &instance_extensions_size, null),
        error.GetVulkanInstanceExtensionsCount,
    );

    var instance_extensions_data = try allocator.alloc(u8, instance_extensions_size + 1);
    defer allocator.free(instance_extensions_data);
    try c.xrCheck(
        xrGetVulkanInstanceExtensionsKHR(instance, system_id, instance_extensions_size, &instance_extensions_size, instance_extensions_data.ptr),
        error.GetVulkanInstanceExtensionsData,
    );

    std.debug.print("\n\n\nInstance Extenstion: {s}\n\n", .{instance_extensions_data});
    var extensions = try std.ArrayList([*:0]const u8).initCapacity(allocator, instance_extensions_size + 1);

    instance_extensions_data[instance_extensions_size] = ' ';
    var iter = std.mem.splitScalar(u8, instance_extensions_data, ' ');
    while (iter.next()) |slice| {
        const null_terminated_slice = try allocator.dupeZ(u8, slice);
        defer allocator.free(null_terminated_slice);
        try extensions.append(null_terminated_slice);
    }

    return .{ graphics_requirements, try extensions.toOwnedSlice() };
}

pub fn getVulkanDeviceRequirements(allocator: std.mem.Allocator, instance: c.XrInstance, system: c.XrSystemId, vk_instance: c.VkInstance) !struct { c.VkPhysicalDevice, []const [*:0]const u8 } {
    const xrGetVulkanGraphicsDeviceKHR = try getXRFunction(c.PFN_xrGetVulkanGraphicsDeviceKHR, instance, "xrGetVulkanGraphicsDeviceKHR");
    const xrGetVulkanDeviceExtensionsKHR = try getXRFunction(c.PFN_xrGetVulkanDeviceExtensionsKHR, instance, "xrGetVulkanDeviceExtensionsKHR");

    var physical_device: c.VkPhysicalDevice = undefined;
    try c.xrCheck(
        xrGetVulkanGraphicsDeviceKHR(instance, system, vk_instance, &physical_device),
        error.xrGetVulkanGraphicsDevice,
    );

    var device_extensions_size: u32 = 0;
    try c.xrCheck(
        xrGetVulkanDeviceExtensionsKHR(instance, system, 0, &device_extensions_size, null),
        error.xrGetVulkanDeviceExtensionsCount,
    );

    var device_extensions_data = try allocator.alloc(u8, device_extensions_size);
    std.debug.print("Instance Extenstion: {s}\n", .{device_extensions_data});
    defer allocator.free(device_extensions_data);
    try c.xrCheck(
        xrGetVulkanDeviceExtensionsKHR(instance, system, device_extensions_size, &device_extensions_size, device_extensions_data.ptr),
        error.xrGetVulkanDeviceExtensionsData,
    );

    var extensions = try std.ArrayList([*:0]const u8).initCapacity(allocator, device_extensions_size);

    device_extensions_data[device_extensions_size] = ' ';
    var iter = std.mem.splitScalar(u8, device_extensions_data, ' ');
    while (iter.next()) |slice| {
        const null_terminated_slice = try allocator.dupeZ(u8, slice);
        try extensions.append(null_terminated_slice);
    }

    return .{ physical_device, try extensions.toOwnedSlice() };
}
