const std = @import("std");
const log = @import("std").log;

const loader = @import("../tools/loader-generator-base.zig");
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

// NOTE: use xrDestroySession(session); to free
pub fn createSession(
    instance: c.XrInstance,
    system_id: c.XrSystemId,
    vk_instance: c.VkInstance,
    physical_device: c.VkPhysicalDevice,
    device: c.VkDevice,
    queue_family_index: u32,
) !c.XrSession {
    var graphics_binding = c.XrGraphicsBindingVulkanKHR{
        .type = c.XR_TYPE_GRAPHICS_BINDING_VULKAN_KHR,
        .instance = vk_instance,
        .physicalDevice = physical_device,
        .device = device,
        .queueFamilyIndex = queue_family_index,
        .queueIndex = 0,
    };

    var session_create_info = c.XrSessionCreateInfo{
        .type = c.XR_TYPE_SESSION_CREATE_INFO,
        .next = &graphics_binding,
        .createFlags = 0,
        .systemId = system_id,
    };

    var session: c.XrSession = undefined;
    try loader.xrCheck(c.xrCreateSession(instance, &session_create_info, &session));

    return session;
}

// Swapchain isnt just helper functions since its cool like this also no idea if this works, it seems very weird
pub const Swapchain = struct {
    const Self = @This();

    swapchain: c.XrSwapchain,
    format: c.VkFormat,
    width: u32,
    height: u32,

    // Same as createSwapchains
    pub fn init(allocator: std.mem.Allocator, instance: c.XrInstance, system_id: c.XrSystemId, session: c.XrSession) ![]const Self {
        const eyes = [_]c.XrViewConfigurationView{
            .{ .type = c.XR_TYPE_VIEW_CONFIGURATION_VIEW },
        } ** 2;

        try loader.xrCheck(c.xrEnumerateViewConfigurationViews(instance, system_id, c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO, @intCast(eyes.len), &@intCast(eyes.len), eyes.ptr));

        const format: i64 = blk: {
            var format_count: u32 = 0;
            try loader.xrCheck(c.xrEnumerateSwapchainFormats(session, 0, &format_count, null));

            var formats = try allocator.alloc(i64, format_count);
            defer allocator.free(formats);
            try loader.xrCheck(c.xrEnumerateSwapchainFormats(session, format_count, &format_count, formats.data()));

            for (formats) |fmt| {
                if (fmt == c.VK_FORMAT_R8G8B8A8_SRGB) break :blk fmt;
            }
        };

        var swapchains: [eyes.len]Self = undefined;

        for (eyes.len) |i| {
            var swapchain_create_info = c.XrSwapchainCreateInfo{
                .type = c.XR_TYPE_SWAPCHAIN_CREATE_INFO,
                .usageFlags = c.XR_SWAPCHAIN_USAGE_COLOR_ATTACHMENT_BIT,
                .format = format,
                .sampleCount = c.VK_SAMPLE_COUNT_1_BIT,
                .width = eyes[i].recommendedImageRectWidth,
                .height = eyes[i].recommendedImageRectHeight,
                .faceCount = 1,
                .arraySize = 1,
                .mipCount = 1,
            };

            var swapchain: c.XrSwapchain = undefined;
            try loader.xrCheck(c.xrCreateSwapchain(session, &swapchain_create_info, &swapchain));

            swapchains[i] = Self{
                .swapchain = swapchains[0],
                .format = @intCast(format),
                .width = eyes[i].recommendedImageRectWidth,
                .height = eyes[i].recommendedImageRectHeight,
            };
        }

        return @ptrCast(swapchains);
    }

    pub fn getImages(self: Self) ![]const c.XrSwapchainImageVulkanKHR {
        var image_count: u32 = undefined;
        try loader.xrCheck(c.xrEnumerateSwapchainImages(self.swapchain, 0, &image_count, null));

        var images = [_]c.XrSwapchainImageVulkanKHR{
            .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_VULKAN_KHR },
        } ** 8;

        try loader.xrCheck(c.xrEnumerateSwapchainImages(self.swapchain, image_count, &image_count, images[image_count..].ptr));

        return images[image_count..];
    }
};

// More shit here https://amini-allight.org/post/openxr-tutorial-part-8

// NOTE: Use     xrDestroySpace(space);
pub fn createSpace(session: c.XrSession) !c.XrSpace {
    var space_create_info = c.XrReferenceSpaceCreateInfo{
        .type = c.XR_TYPE_REFERENCE_SPACE_CREATE_INFO,
        .referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_STAGE,
        .poseInReferenceSpace = .{ .orientation = .{ .x = 0, .y = 0, .z = 0, .w = 1 }, .position = .{ .x = 0, .y = 0, .z = 0 } },
    };

    var space: c.XrSpace = undefined;
    try loader.xrCheck(c.xrCreateReferenceSpace(session, &space_create_info, &space));

    return space;
}
