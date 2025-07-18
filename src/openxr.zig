const std = @import("std");
const log = @import("std").log;

const loader = @import("loader");
const c = loader.c;

pub const Dispatcher = loader.XrDispatcher(.{
    .xrCreateDebugUtilsMessengerEXT = true,
    .xrDestroyDebugUtilsMessengerEXT = true,
    .xrGetVulkanGraphicsRequirementsKHR = true,
    .xrGetVulkanInstanceExtensionsKHR = true,
    .xrGetVulkanDeviceExtensionsKHR = true,
    .xrGetVulkanGraphicsDeviceKHR = true,
});

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
    try loader.xrCheck(c.xrCreateInstance(&create_info, &instance));

    return instance;
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

pub fn createDebugMessenger(
    dispatcher: Dispatcher,
    instance: c.XrInstance,
) !c.XrDebugUtilsMessengerEXT {
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

    try dispatcher.xrCreateDebugUtilsMessengerEXT(
        instance,
        &debug_messenger_create_info,
        &debug_messenger,
    );

    return debug_messenger;
}

pub fn getSystem(instance: c.XrInstance) !c.XrSystemId {
    var system_get_info = c.XrSystemGetInfo{
        .type = c.XR_TYPE_SYSTEM_GET_INFO,
        .formFactor = c.XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY,
    };

    var system_id: c.XrSystemId = undefined;
    try loader.xrCheck(c.xrGetSystem(instance, &system_get_info, &system_id));

    return system_id;
}

pub fn getVulkanInstanceRequirements(
    dispatcher: Dispatcher,
    allocator: std.mem.Allocator,
    instance: c.XrInstance,
    system_id: c.XrSystemId,
) !struct { c.XrGraphicsRequirementsVulkanKHR, []const [*:0]const u8 } {
    var graphics_requirements = c.XrGraphicsRequirementsVulkanKHR{
        .type = c.XR_TYPE_GRAPHICS_REQUIREMENTS_VULKAN_KHR,
    };

    try dispatcher.xrGetVulkanGraphicsRequirementsKHR(
        instance,
        system_id,
        &graphics_requirements,
    );

    _ = allocator;

    // var instance_extensions_size: u32 = 0;
    // try c.xrCheck(
    //     xrGetVulkanInstanceExtensionsKHR(instance, system_id, 0, &instance_extensions_size, null),
    //     error.GetVulkanInstanceExtensionsCount,
    // );

    // var instance_extensions_data = try allocator.alloc(u8, instance_extensions_size + 1);
    // defer allocator.free(instance_extensions_data);
    // try c.xrCheck(
    //     xrGetVulkanInstanceExtensionsKHR(instance, system_id, instance_extensions_size, &instance_extensions_size, instance_extensions_data.ptr),
    //     error.GetVulkanInstanceExtensionsData,
    // );

    // std.debug.print("\n\n\nInstance Extenstion: |{s}|\n\n", .{instance_extensions_data});
    // var extensions = std.ArrayList([*:0]const u8).init(allocator);

    // instance_extensions_data[instance_extensions_size] = ' ';

    // var last: usize = 0;
    // var word_index: u8 = 0;
    // var word_lens: [10]usize = undefined;
    // for (0..instance_extensions_size + 1) |i| {
    //     std.debug.print("Index {d} = ", .{i});
    //     if (instance_extensions_data[i] == ' ' or (instance_extensions_data[i] == 0)) {
    //         if (instance_extensions_data[i] == 0) continue;
    //         //std.debug.print("AAAAAA\n", .{});
    //         instance_extensions_data[i] = '\x00';
    //         try extensions.append(@ptrCast(instance_extensions_data[last..i]));
    //         word_lens[word_index] = i - last;
    //         last = i + 1;
    //         word_index += 1;
    //         std.debug.print("[0] I: {d} - C: {c}\n", .{ instance_extensions_data[i], instance_extensions_data[i] });
    //     } else std.debug.print("I: {d} - C: {c}\n", .{ instance_extensions_data[i], instance_extensions_data[i] });
    // }

    // std.debug.print("EXT DATA: {s}\n", .{instance_extensions_data});

    // for (extensions.items, 0..) |ext, i| {
    //     std.debug.print("{d} {s}\n", .{ i, ext });
    //     std.debug.print("MASTER debug {d}\n", .{ext[word_lens[i]]});
    // }

    //TODO: DONT USE HARD CODED! Use the code from above but make it work!

    const extensions = &[_][*:0]const u8{
        "VK_KHR_external_memory_capabilities",
        "VK_KHR_get_physical_device_properties2",
        "VK_KHR_external_fence_capabilities",
        "VK_KHR_surface",
        "VK_KHR_external_semaphore_capabilities",
        "VK_EXT_debug_utils", // TODO: <---- EXTRA EXT add manunally!!!!
    };

    return .{ graphics_requirements, extensions };
}

pub fn getVulkanDeviceRequirements(
    dispatcher: Dispatcher,
    allocator: std.mem.Allocator,
    instance: c.XrInstance,
    system: c.XrSystemId,
    vk_instance: c.VkInstance,
) !struct { c.VkPhysicalDevice, []const [*:0]const u8 } {
    var physical_device: c.VkPhysicalDevice = undefined;
    try dispatcher.xrGetVulkanGraphicsDeviceKHR(
        instance,
        system,
        vk_instance,
        &physical_device,
    );

    _ = allocator;

    // var device_extensions_size: u32 = 0;
    // try c.xrCheck(
    //     xrGetVulkanDeviceExtensionsKHR(instance, system, 0, &device_extensions_size, null),
    //     error.xrGetVulkanDeviceExtensionsCount,
    // );

    // var device_extensions_data = try allocator.alloc(u8, device_extensions_size + 1);
    // std.debug.print("Instance Extenstion: {s}\n", .{device_extensions_data});
    // defer allocator.free(device_extensions_data);
    // try c.xrCheck(
    //     xrGetVulkanDeviceExtensionsKHR(instance, system, device_extensions_size, &device_extensions_size, device_extensions_data.ptr),
    //     error.xrGetVulkanDeviceExtensionsData,
    // );

    // var extensions = try std.ArrayList([*:0]const u8).initCapacity(allocator, device_extensions_size);

    // device_extensions_data[device_extensions_size] = ' ';
    // var iter = std.mem.splitScalar(u8, device_extensions_data, ' ');
    // while (iter.next()) |slice| {
    //     const null_terminated_slice = try allocator.dupeZ(u8, slice);
    //     try extensions.append(null_terminated_slice);
    // }

    //TODO: DONT USE HARD CODED! Use the code from above but make it work!

    const extensions = &[_][*:0]const u8{};

    return .{ physical_device, extensions };
}
