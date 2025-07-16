const std = @import("std");
const builtin = @import("builtin");
const log = @import("std").log;
const c = @import("c.zig");
const vk = @import("vulkan/context.zig");

pub const Context = struct {
    const Self = @This();

    instance: c.XrInstance,
    system: struct {
        id: c.XrSystemId,
        info: c.XrSystemGetInfo,
        properties: c.XrSystemProperties,
    },
    space: c.XrSpace,

    pub fn init(allocator: std.mem.Allocator, extensions: []const [:0]const u8, vk_context: vk.Context) !Self {
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
            .instance = vk_context.instance,
            .physicalDevice = vk_context.device.physical,
            .device = vk_context.device.logical,
            .queueFamilyIndex = vk_context.device.graphics_queue orelse return error.DeviceGraphicsQueueWasNull,
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

    pub fn getVulkanExtensions(self: Self) ![]const [:0]const u8 {
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
        _ = self;

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
