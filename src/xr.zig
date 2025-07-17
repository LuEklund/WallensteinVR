const std = @import("std");
const builtin = @import("builtin");
const log = @import("std").log;
const c = @import("c.zig");
//const vk = @import("vulkan/context.zig");

// WTF IS THIS FILE

pub const Context = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    instance: c.XrInstance,
    debug_messenger: ?*c.XrDebugUtilsLabelEXT,
    system: struct {
        id: c.XrSystemId,
        info: c.XrSystemGetInfo,
        properties: c.XrSystemProperties,
    },

    pub fn init(allocator: std.mem.Allocator, extensions: []const [*:0]const u8, layers: []const [*:0]const u8) !Self {
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
        try c.xrCheck(
            c.xrCreateInstance(&create_info, &instance),
            error.CreateInstance,
        );

        const debug_messenger: *c.XrDebugUtilsLabelEXT = @ptrCast(@alignCast(try createDebugMessenger(instance)));

        var system_info = c.XrSystemGetInfo{
            .type = c.XR_TYPE_SYSTEM_GET_INFO,
        };

        system_info.formFactor = c.XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY;

        var system_id: c.XrSystemId = undefined;
        try c.xrCheck(
            c.xrGetSystem(instance, &system_info, &system_id),
            error.GetSystemId,
        );

        var system_properties = c.XrSystemProperties{ .type = c.XR_TYPE_SYSTEM_PROPERTIES, .next = null };
        try c.xrCheck(
            c.xrGetSystemProperties(instance, system_id, &system_properties),
            error.GetSystemProperties,
        );

        _ = getVulkanInstanceRequirements(allocator, instance, system_id);

        return .{
            .allocator = allocator,
            .instance = instance,
            .debug_messenger = debug_messenger,
            .system = .{
                .id = system_id,
                .info = system_info,
                .properties = system_properties,
            },
        };
    }

    pub fn deinit(self: Self) void {
        const destroy_fn_ptr = getXRFunction(self.instance, "xrDestroyDebugUtilsMessengerEXT") catch unreachable;
        const xrDestroyDebugUtilsMessengerEXT: @typeInfo(c.PFN_xrDestroyDebugUtilsMessengerEXT).optional.child = @ptrCast(destroy_fn_ptr);
        _ = xrDestroyDebugUtilsMessengerEXT(@ptrCast(self.debug_messenger));
        _ = c.xrDestroyInstance(self.instance);
    }

    pub fn getVulkanExtensions(self: Self) ![]const [:0]const u8 {
        var get_instance_exts: c.PFN_xrGetVulkanInstanceExtensionsKHR = undefined;
        try c.xrGetInstanceProcAddr(
            self.instance,
            "xrGetVulkanInstanceExtensionsKHR",
            @ptrCast(&get_instance_exts),
        );

        var len: u32 = 0;
        try get_instance_exts(self.instance, self.system_id, 0, &len, null);

        const buffer = try self.allocator.alloc(u8, len);
        defer self.allocator.free(buffer);

        try get_instance_exts(self.instance, self.system_id, len, &len, buffer.ptr);

        const extension_string = buffer[0..len];

        var list = std.ArrayList([*:0]const u8).init(self.allocator);
        errdefer list.deinit();

        var it = std.mem.splitAny(u8, extension_string, " ");
        while (it.next()) |ext| {
            const cstr = try self.allocator.allocSentinel(u8, ext.len, 0);
            @memcpy(cstr[0..ext.len], ext);
            try list.append(cstr);
        }

        return list.toOwnedSlice();
    }
};

// pub const Session = struct {
//     const Self = @This();

//     session: c.XrSession,
//     space: c.XrSpace,

//     pub fn init(xr_context: Context, vk_context: vk.Context) !Self {
//         const graphics_binding = c.XrGraphicsBindingVulkanKHR{
//             .type = c.XR_TYPE_GRAPHICS_BINDING_VULKAN_KHR,
//             .instance = vk_context.instance,
//             .physicalDevice = vk_context.device.physical,
//             .device = vk_context.device.logical,
//             .queueFamilyIndex = 0, // The default one
//             .queueIndex = 0, // Zero because its the first and so far only queue we have
//         };

//         const session_info = c.XrSessionCreateInfo{
//             .type = c.XR_TYPE_SESSION_CREATE_INFO,
//             .next = &graphics_binding,
//             .systemId = xr_context.system_id,
//         };

//         var session: c.XrSession = undefined;
//         try c.xrCheck(
//             c.xrCreateSession(xr_context.instance, &session_info, &session),
//             error.CreateSession,
//         );

//         var space_create_info = c.XrReferenceSpaceCreateInfo{
//             .type = c.XR_TYPE_REFERENCE_SPACE_CREATE_INFO,
//             .referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_LOCAL,
//             .poseInReferenceSpace = .{
//                 .orientation = c.XrQuaternionf{ .x = 0, .y = 0, .z = 0, .w = 1 },
//                 .position = c.XrVector3f{ .x = 0, .y = 0, .z = 0 },
//             },
//         };

//         var space: c.XrSpace = undefined;
//         try c.xrCheck(
//             c.xrCreateReferenceSpace(session, &space_create_info, &space),
//             error.CreateReferenceSpace,
//         );

//         return .{ .session = session, .space = space };
//     }

//     pub fn deinit(self: Self) void {
//         _ = c.xrDestroySpace(self.space);
//         _ = c.xrDestroySession(self.session);
//     }
// };

pub fn getXRFunction(instance: c.XrInstance, name: [*c]const u8) !*const anyopaque {
    var func: c.PFN_xrVoidFunction = null;
    try c.xrCheck(
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

    try c.xrCheck(
        xrCreateDebugUtilsMessengerEXT(instance, &debug_messenger_create_info, &debug_messenger),
        error.CreateDebugUtilsMessengerEXT,
    );

    return debug_messenger;
}

fn validateExtensions(allocator: std.mem.Allocator, extentions: []const [*:0]const u8) !void {
    var extension_count: u32 = 0;

    try c.xrCheck(
        c.xrEnumerateInstanceExtensionProperties(null, 0, &extension_count, null),
        error.EnumerateExtentionsPropertiesCount,
    );

    const extension_properties = try allocator.alloc(c.XrExtensionProperties, @intCast(extension_count));
    defer allocator.free(extension_properties);

    @memset(extension_properties, .{ .type = c.XR_TYPE_EXTENSION_PROPERTIES });

    try c.xrCheck(
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

    try c.xrCheck(
        c.xrEnumerateApiLayerProperties(0, &layer_count, null),
        error.EnumerateApiLayerPropertiesCount,
    );
    const layer_properties = try allocator.alloc(c.XrApiLayerProperties, @intCast(layer_count));
    defer allocator.free(layer_properties);

    @memset(layer_properties, .{ .type = c.XR_TYPE_API_LAYER_PROPERTIES });
    for (layers) |layer| {
        for (layer_properties) |layer_property| {
            if (std.mem.eql(u8, std.mem.span(layer), std.mem.sliceTo(&layer_property.layerName, 0))) break;
        } else {
            log.err("Failed to find OpenXR layer: {s}\n", .{layer});
            return error.MissingLayers;
        }
    }
}

pub fn getVulkanInstanceRequirements(allocator: std.mem.Allocator, instance: c.XrInstance, system: c.XrSystemId) struct { graphics_requirements: c.XrGraphicsRequirementsVulkanKHR, extensions: []const [*:0]const u8 } {
    const PFN_xrGetVulkanGraphicsRequirementsKHR = *const fn (
        instance: c.XrInstance,
        system_id: c.XrSystemId,
        graphics_requirements: *c.XrGraphicsRequirementsVulkanKHR,
    ) callconv(.c) c.XrResult;

    const raw_fn_graphics = try getXRFunction(instance, "xrGetVulkanGraphicsRequirementsKHR");
    const xrGetVulkanGraphicsRequirementsKHR: PFN_xrGetVulkanGraphicsRequirementsKHR = @ptrCast(raw_fn_graphics);

    const PFN_xrGetVulkanInstanceExtensionsKHR = *const fn (
        instance: c.XrInstance,
        system_id: c.XrSystemId,
        buffer_capacity_input: u32,
        buffer_count_output: *u32,
        buffer: [*]u8, // 🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼🧼
    ) callconv(.c) c.XrResult;

    const raw_fn_extensions = try getXRFunction(instance, "xrGetVulkanInstanceExtensionsKHR");
    const xrGetVulkanInstanceExtensionsKHR: PFN_xrGetVulkanInstanceExtensionsKHR = @ptrCast(raw_fn_extensions);

    var graphics_requirements = c.XrGraphicsRequirementsVulkanKHR{
        .type = c.XR_TYPE_GRAPHICS_REQUIREMENTS_VULKAN_KHR,
    };

    try c.xrCheck(
        xrGetVulkanGraphicsRequirementsKHR(instance, system, &graphics_requirements),
        error.GetVulkanGraphicsRequirement,
    );

    var instance_extensions_size: u32 = 0;
    try c.xrCheck(
        xrGetVulkanInstanceExtensionsKHR(instance, system, 0, &instance_extensions_size, null),
        error.GetVulkanInstanceExtensionsCount,
    );

    var instance_extensions_data = try allocator.alloc(u8, instance_extensions_size);
    defer allocator.free(instance_extensions_data);
    try c.xrCheck(
        xrGetVulkanInstanceExtensionsKHR(instance, system, instance_extensions_size, &instance_extensions_size, instance_extensions_data.ptr),
        error.GetVulkanInstanceExtensionsData,
    );

    std.debug.print("Instance Extenstion: {s}\n", .{instance_extensions_data.ptr});
    const extensions = try std.ArrayList([*:0]const u8).initCapacity(allocator, instance_extensions_size * 2);

    var i: usize = 0;
    var last: usize = 0;
    while (i <= instance_extensions_size) : (i += 1) {
        if (i == @as(usize, @intCast(instance_extensions_size)) or instance_extensions_data[i] == ' ') {
            try extensions.append(instance_extensions_data[last .. i - last]);
            last = i + 1;
        }
    }

    return .{ .graphics_requirements = graphics_requirements, .extensions = try extensions.toOwnedSlice() };
}

pub fn getVulkanDeviceRequirements(allocator: std.mem.Allocator, instance: c.XrInstance, system: c.XrSystemId, vk_instance: c.VkInstance) struct { physical_device: c.VkPhysicalDevice, extensions: []const [*:0]const u8 } {
    const raw_fn_graphics_device = try getXRFunction(instance, "xrGetVulkanGraphicsDeviceKHR");
    const xrGetVulkanGraphicsDeviceKHR: c.PFN_xrGetVulkanGraphicsRequirementsKHR = @ptrCast(raw_fn_graphics_device);

    const raw_fn_device_extensions = try getXRFunction(instance, "xrGetVulkanDeviceExtensionsKHR");
    const xrGetVulkanDeviceExtensionsKHR: c.PFN_xrGetVulPFN_xrGetVulkanInstanceExtensionsKHRkanGraphicsRequirementsKHR = @ptrCast(raw_fn_device_extensions);

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
    std.debug.print("Instance Extenstion: {s}\n", .{device_extensions_data.ptr});
    defer allocator.free(device_extensions_data);
    try c.xrCheck(
        xrGetVulkanDeviceExtensionsKHR(instance, system, device_extensions_size, &device_extensions_size, device_extensions_data.ptr),
        error.xrGetVulkanDeviceExtensionsData,
    );

    var extensions = try std.ArrayList([*:0]const u8).initCapacity(allocator, device_extensions_size);
    var i: usize = 0;
    var last: usize = 0;
    while (i <= device_extensions_size) : (i += 1) {
        if (i == @as(usize, @intCast(device_extensions_size)) or device_extensions_data[i] == ' ') {
            try extensions.append(device_extensions_data[last .. i - last]);
            last = i + 1;
        }
    }
    return .{ .physical_device = physical_device, .extensions = try extensions.toOwnedSlice() };
}
