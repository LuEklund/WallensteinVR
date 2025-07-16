const std = @import("std");
const log = @import("std").log;
const c = @import("c.zig");

pub const Context = struct {
    const Self = @This();

    instance: c.XrInstance,
    system: struct {
        id: c.XrSystemId,
        info: c.XrSystemGetInfo,
        properties: c.XrSystemProperties,
    },
    space: c.XrSpace,

    pub fn init(allocator: std.mem.Allocator, extensions: []const [:0]const u8) !Self {
        // const extensions = &[_][:0]const u8{
        // "XR_KHR_vulkan_enable",
        // "XR_EXT_debug_utils",
        // "XR_KHR_vulkan_enable2",
        // };

        const available_extensions = try getAvailableExtensions(allocator);

        {
            var active_extensions = try std.ArrayList([]const u8).initCapacity(allocator, extensions.len);
            defer active_extensions.deinit();

            for (extensions) |requested| {
                var found = false;

                for (available_extensions) |*prop| {
                    const name = std.mem.span(@as([*:0]const u8, @ptrCast(&prop.extensionName)));
                    if (std.mem.eql(u8, name, requested)) {
                        try active_extensions.append(requested);
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    log.err("Failed to find OpenXR extension: {s}\n", .{requested});
                    return error.MissingExtension;
                }
            }
        }

        var create_info = c.XrInstanceCreateInfo{
            .type = c.XR_TYPE_INSTANCE_CREATE_INFO,
            .next = null,
            .createFlags = 0,
            .applicationInfo = .{
                .applicationName = blk: {
                    var buffer: [128]u8 = undefined;
                    const name = "WallensteinVR";
                    @memcpy(buffer[0..name.len], name[0..]);
                    break :blk buffer;
                },
                .applicationVersion = 1,
                .engineName = blk: {
                    var buffer: [128]u8 = undefined;
                    const name = "WallensteinVR_Engine";
                    @memcpy(buffer[0..name.len], name[0..]);
                    break :blk buffer;
                },
                .engineVersion = 1,
                .apiVersion = c.XR_CURRENT_API_VERSION,
            },
            //TODO: MUST BE C char** AND remove hardcoded size
            .enabledExtensionNames = @ptrCast(&extensions),
            .enabledExtensionCount = @intCast(extensions.len),
        };

        var instance: c.XrInstance = undefined;
        try c.check(
            c.xrCreateInstance(&create_info, &instance),
            error.CreateInstance,
        );

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
            .device = null, // We need vulkan
            .instance = null, // More vulkan
            .physicalDevice = null, // AAAAAAAAAAa,
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
            .system = .{
                .id = system_id,
                .info = system_info,
                .properties = system_properties,
            },
            .space = space,
        };
    }

    pub fn deinit(self: Self) void {
        _ = c.xrDestroyInstance(self.instance);
    }

    fn getAvailableExtensions(allocator: std.mem.Allocator) ![]c.XrExtensionProperties {
        var count: u32 = 0;

        try c.check(
            c.xrEnumerateInstanceExtensionProperties(null, 0, &count, null),
            error.EnumerateInstanceExtensionProperties,
        );

        var extensions = try std.ArrayList(c.XrExtensionProperties).initCapacity(allocator, count);

        for (0..count) |i| {
            try extensions.append(std.mem.zeroes(c.XrExtensionProperties));
            extensions.items[i].type = c.XR_TYPE_EXTENSION_PROPERTIES;
        }

        try c.check(
            c.xrEnumerateInstanceExtensionProperties(
                null,
                count,
                &count,
                @ptrCast(extensions.items.ptr),
            ),
            error.EnumerateInstanceExtensionProperties,
        );

        return try extensions.toOwnedSlice();
    }
};

// Used for later
// pub fn getLayers() {
//     var layer_count: u32 = 0;
//     var layer_properties = std.ArrayList(c.XrApiLayerProperties).init(allocator);
//     defer layer_properties.deinit();
//     try c.check(c.xrEnumerateApiLayerProperties(0, &layer_count, null), error.EnumerateApiLayerProperties,);
//     try layer_properties.append(c.XR_TYPE_API_LAYER_PROPERTIES);
//     try c.check(c.xrEnumerateApiLayerProperties(layer_count, &layer_count, @ptrCast(&layer_properties.items)), error.EnumerateApiLayerProperties,);

//         for (&requestLayer : m_apiLayers)  {
//         for (auto &layerProperty : apiLayerProperties) {
//             // strcmp returns 0 if the strings match.
//             if (strcmp(requestLayer.c_str(), layerProperty.layerName) != 0) {
//                 continue;
//             } else {
//                 m_activeAPILayers.push_back(requestLayer.c_str());
//                 break;
//             }
//         }
//     }
// }
