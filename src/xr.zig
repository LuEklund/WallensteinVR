const std = @import("std");
const builtin = @import("builtin");
const log = @import("std").log;
const c = @import("c.zig");
const vk = @import("vulkan/context.zig");

pub const Context = struct {
    const Self = @This();

    instance: c.XrInstance,
    debug_messenger: ?*c.XrDebugUtilsLabelEXT,
    system: struct {
        id: c.XrSystemId,
        info: c.XrSystemGetInfo,
        properties: c.XrSystemProperties,
    },
    space: c.XrSpace,

    pub fn init(allocator: std.mem.Allocator, extensions: []const [*:0]const u8, layers: []const [*:0]const u8, vk_context: vk.Context) !Self {
        try validateExtensions(allocator, extensions);
        try validateLayers(allocator, layers);

        std.debug.print("extensions {any}\n", .{extensions});

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
            //TODO: MUST BE C char** AND remove hardcoded size
            .enabledExtensionNames = @ptrCast(extensions.ptr),
            .enabledExtensionCount = @intCast(extensions.len),
            .enabledApiLayerCount = @intCast(layers.len),
            .enabledApiLayerNames = @ptrCast(layers.ptr),
        };

        var instance: c.XrInstance = undefined;
        try c.check(
            c.xrCreateInstance(&create_info, &instance),
            error.CreateInstance,
        );

        const debug_messenger: *c.XrDebugUtilsLabelEXT = @ptrCast(@alignCast(try createDebugMessenger(instance)));

        var system_info = c.XrSystemGetInfo{
            .type = c.XR_TYPE_SYSTEM_GET_INFO,
        };

        system_info.formFactor = c.XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY;

        var system_id: c.XrSystemId = undefined;
        try c.check(
            c.xrGetSystem(instance, &system_info, &system_id),
            error.GetSystemId,
        );

        var system_properties = c.XrSystemProperties{ .type = c.XR_TYPE_SYSTEM_PROPERTIES, .next = null };
        try c.check(
            c.xrGetSystemProperties(instance, system_id, &system_properties),
            error.GetSystemProperties,
        );

        const graphics_binding = c.XrGraphicsBindingVulkanKHR{
            .type = c.XR_TYPE_GRAPHICS_BINDING_VULKAN_KHR,
            .instance = vk_context.instance,
            .physicalDevice = vk_context.device.physical,
            .device = vk_context.device.logical,
            .queueFamilyIndex = 0, // The default one
            .queueIndex = 0, // Zero because its the first and so far only queue we have
        };

        const session_info = c.XrSessionCreateInfo{
            .type = c.XR_TYPE_SESSION_CREATE_INFO,
            .next = &graphics_binding,
            .systemId = system_id,
        };

        var session: c.XrSession = undefined;
        try c.check(
            c.xrCreateSession(instance, &session_info, &session),
            error.CreateSession,
        );

        var space_create_info = c.XrReferenceSpaceCreateInfo{
            .type = c.XR_TYPE_REFERENCE_SPACE_CREATE_INFO,
            .referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_LOCAL,
            .poseInReferenceSpace = .{
                .orientation = c.XrQuaternionf{ .x = 0, .y = 0, .z = 0, .w = 1 },
                .position = c.XrVector3f{ .x = 0, .y = 0, .z = 0 },
            },
        };

        var space: c.XrSpace = undefined;
        try c.check(
            c.xrCreateReferenceSpace(session, &space_create_info, &space),
            error.CreateReferenceSpace,
        );

        return .{
            .instance = instance,
            .debug_messenger = debug_messenger,
            .system = .{
                .id = system_id,
                .info = system_info,
                .properties = system_properties,
            },
            .space = space,
        };
    }

    pub fn deinit(self: Self) void {
        const destroy_fn_ptr = getXRFunction(self.instance, "xrDestroyDebugUtilsMessengerEXT") catch unreachable;
        const xrDestroyDebugUtilsMessengerEXT: @typeInfo(c.PFN_xrDestroyDebugUtilsMessengerEXT).optional.child = @ptrCast(destroy_fn_ptr);
        _ = xrDestroyDebugUtilsMessengerEXT(@ptrCast(self.debug_messenger));
        _ = c.xrDestroyInstance(self.instance);
    }

    pub fn getVulkanExtensions() ![]const [:0]const u8 {
        // var extension_str_len: u32 = 0;

        // try c.check(
        //     c.xrGetVulkanInstanceExtensionsKHR(self.instance, self.system.id, 0, &extension_str_len, null),
        //     error.GetVulkanInstanceExtensionsKHR,
        // );

        // var buffer: [512]u8 = undefined;
        // const extension_slice = buffer[0..@intCast(extension_str_len)];

        // try c.check(
        //     c.xrGetVulkanInstanceExtensionsKHR(
        //         self.instance,
        //         self.system.id,
        //         extension_str_len,
        //         &extension_str_len,
        //         extension_slice.ptr,
        //     ),
        //     error.GetVulkanInstanceExtensionsKHR,
        // );

        // var static_extensions: [16][:0]const u8 = undefined;
        // var count: usize = 0;

        // var it = std.mem.splitAny(u8, extension_slice, " ");
        // while (it.next()) |*ext| {
        //     if (count >= static_extensions.len) break;
        //     static_extensions[count] = @ptrCast(ext);
        //     count += 1;
        // }

        // return static_extensions[0..count];

        //TODO: Make this not hard coded

        const extensions = [_][:0]const u8{
            "VK_KHR_surface",
            "VK_KHR_get_physical_device_properties2",
            "VK_EXT_debug_utils",
            "VK_KHR_external_memory_capabilities",
            switch (builtin.os.tag) {
                .windows => "VK_KHR_win32_surface",
                .linux, .freebsd, .dragonfly => "VK_KHR_wayland_surface", // "VK_KHR_xcb_surface" <-- Xorg;
                .macos => "VK_EXT_metal_surface",
                else => @compileError("Unsupported OS for Vulkan surface extension"),
            },
        };

        return &extensions;
    }
};

pub fn getXRFunction(instance: c.XrInstance, name: [*c]const u8) !*const anyopaque {
    var func: c.PFN_xrVoidFunction = null;
    try c.check(
        c.xrGetInstanceProcAddr(instance, name, &func),
        error.GetInstanceProcAddr,
    );

    return @ptrCast(func);
}

fn handleXRError(severity: c.XrDebugUtilsMessageSeverityFlagsEXT, @"type": c.XrDebugUtilsMessageTypeFlagsEXT, callback_data: *const c.XrDebugUtilsMessengerCallbackDataEXT, _: *anyopaque) c.XrBool32 {
    const type_str: []const u8 = switch (@"type") {
        c.XR_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT => "general ",
        c.XR_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT => "validation ",
        c.XR_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT => "performance ",
        c.XR_DEBUG_UTILS_MESSAGE_TYPE_CONFORMANCE_BIT_EXT => "conformance ",
        else => "other",
    };

    const severity_str = switch (severity) {
        c.XR_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => "(verbose): ",
        c.XR_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => "(info): ",
        c.XR_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => "(warning): ",
        c.XR_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => "(error): ",
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

    const PFN_xrCreateDebugUtilsMessengerEXT = *const fn (
        instance: c.XrInstance,
        createInfo: *const c.XrDebugUtilsMessengerCreateInfoEXT,
        messenger: *c.XrDebugUtilsMessengerEXT,
    ) callconv(.C) c.XrResult;

    const raw_fn = try getXRFunction(instance, "xrCreateDebugUtilsMessengerEXT");
    const xrCreateDebugUtilsMessengerEXT: PFN_xrCreateDebugUtilsMessengerEXT = @ptrCast(raw_fn);

    try c.check(
        xrCreateDebugUtilsMessengerEXT(instance, &debug_messenger_create_info, &debug_messenger),
        error.CreateDebugUtilsMessengerEXT,
    );

    return debug_messenger;
}

fn validateExtensions(allocator: std.mem.Allocator, extentions: []const [*:0]const u8) !void {
    var extension_count: u32 = 0;

    try c.check(
        c.xrEnumerateInstanceExtensionProperties(null, 0, &extension_count, null),
        error.EnumerateExtentionsPropertiesCount,
    );

    const extension_properties = try allocator.alloc(c.XrExtensionProperties, @intCast(extension_count));
    defer allocator.free(extension_properties);

    @memset(extension_properties, .{ .type = c.XR_TYPE_EXTENSION_PROPERTIES });

    try c.check(
        c.xrEnumerateInstanceExtensionProperties(null, extension_count, &extension_count, @ptrCast(extension_properties.ptr)),
        error.EnumerateExtensionsProperties,
    );

    for (extentions) |extention| {
        for (extension_properties) |extension_property| {
            if (std.mem.eql(u8, std.mem.span(extention), std.mem.sliceTo(&extension_property.extensionName, 0))) break;
        } else {
            log.err("Failed to find OpenXR extension: {s}\n", .{extention});
            return error.MissingLayers;
        }
    }
}

pub fn validateLayers(allocator: std.mem.Allocator, layers: []const [*:0]const u8) !void {
    var layer_count: u32 = 0;

    try c.check(
        c.xrEnumerateApiLayerProperties(0, &layer_count, null),
        error.EnumerateApiLayerPropertiesCount,
    );
    const layer_properties = try allocator.alloc(c.XrApiLayerProperties, @intCast(layer_count));
    defer allocator.free(layer_properties);

    @memset(layer_properties, .{ .type = c.XR_TYPE_API_LAYER_PROPERTIES });
    //try layer_properties.append(c.XR_TYPE_API_LAYER_PROPERTIES);
    try c.check(
        c.xrEnumerateApiLayerProperties(layer_count, &layer_count, @ptrCast(layer_properties.ptr)),
        error.EnumerateApiLayerProperties,
    );

    // this copy is prob useless cuz it just returns whatever is in `layers`

    // can u try this \/ \/ \/ \/ \/
    // this instead: no copying + no alloc
    // BIG FAT JUICY DONKEY MEAT
    for (layers) |layer| {
        for (layer_properties) |layer_property| {
            if (std.mem.eql(u8, std.mem.span(layer), std.mem.sliceTo(&layer_property.layerName, 0))) break;
        } else {
            log.err("Failed to find OpenXR layer: {s}\n", .{layer});
            return error.MissingLayers;
        }
    }
}
