const std = @import("std");
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cDefine("XR_USE_GRAPHICS_API_VULKAN", "1");
    @cInclude("openxr/openxr.h");
    @cInclude("openxr/openxr_platform.h");
});

pub inline fn xrCheck(result: c.XrResult, err: anyerror) !void {
    if (result != c.XR_SUCCESS) return err;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    //TODO: Must USE char** for .enabledExtensionNames = requested_instance_extensions2,
    const requested_instance_extensions = &[_][:0]const u8{
        "XR_KHR_vulkan_enable",
        "XR_EXT_debug_utils",
        "XR_KHR_vulkan_enable2",
    };
    const requested_instance_extensions2 = &[_][*:0]const u8{
        "XR_KHR_vulkan_enable".ptr,
        "XR_EXT_debug_utils".ptr,
        "XR_KHR_vulkan_enable2".ptr,
    };

    const available_extensions = try getAvailableExtensions(allocator);

    {
        var active_extensions = try std.ArrayList([]const u8).initCapacity(allocator, requested_instance_extensions.len);
        defer active_extensions.deinit();

        for (requested_instance_extensions) |requested| {
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
                std.debug.print("Failed to find OpenXR instance extension: {s}\n", .{requested});
            }
        }
    }

    var nameBuffer: [128]u8 = undefined;
    const name = "WallensteinVR";
    @memcpy(nameBuffer[0..name.len], name[0..]);
    nameBuffer[name.len] = 0;

    var engineNameBuffer: [128]u8 = undefined;
    const name1 = "WallensteinVR_Engine";
    @memcpy(engineNameBuffer[0..name1.len], name1[0..]);
    engineNameBuffer[name1.len] = 0;

    var create_info = c.XrInstanceCreateInfo{
        .type = c.XR_TYPE_INSTANCE_CREATE_INFO,
        .next = null,
        .createFlags = 0,
        .applicationInfo = .{
            .applicationName = nameBuffer,
            .applicationVersion = 1,
            .engineName = engineNameBuffer,
            .engineVersion = 1,
            .apiVersion = c.XR_CURRENT_API_VERSION,
        },
        //TODO: MUST BE C char** AND remove hardcoded size
        .enabledExtensionNames = requested_instance_extensions2,
        .enabledExtensionCount = @intCast(3),
    };

    var instance: c.XrInstance = undefined;
    try xrCheck(
        c.xrCreateInstance(&create_info, &instance),
        error.CreateInstance,
    );
    defer _ = c.xrDestroyInstance(instance);

    var sytem_info = c.XrSystemGetInfo{
        .type = c.XR_TYPE_SYSTEM_GET_INFO,
    };

    try xrCheck(
        c.xrGetSystem(instance, &sytem_info, 0),
        error.GetSystemInfo,
    );

    sytem_info.formFactor = c.XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY;

    var system_id: c.XrSystemId = undefined;
    try xrCheck(
        c.xrGetSystem(instance, &sytem_info, &system_id),
        error.GetSystemId,
    );

    var system_properties: c.XrSystemProperties = undefined;
    try xrCheck(
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
    try xrCheck(
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
    try xrCheck(
        c.xrCreateReferenceSpace(session, &space_create_info, &space),
        error.CreateReferenceSpace,
    );
}

pub fn getAvailableExtensions(allocator: std.mem.Allocator) ![]c.XrExtensionProperties {
    var count: u32 = 0;

    try xrCheck(
        c.xrEnumerateInstanceExtensionProperties(null, 0, &count, null),
        error.EnumerateInstanceExtensionProperties,
    );

    var extensions = try std.ArrayList(c.XrExtensionProperties).initCapacity(allocator, count);

    for (0..count) |i| {
        try extensions.append(std.mem.zeroes(c.XrExtensionProperties));
        extensions.items[i].type = c.XR_TYPE_EXTENSION_PROPERTIES;
    }

    try xrCheck(
        c.xrEnumerateInstanceExtensionProperties(
            null,
            count,
            &count,
            @ptrCast(extensions.items.ptr),
        ),
        error.EnumerateInstanceExtensionProperties,
    );

    //    std.debug.print("hello\n", .{});

    return try extensions.toOwnedSlice(); // this is your `available_extensions`
}

// Used for later
// pub fn getLayers() {
//     var layer_count: u32 = 0;
//     var layer_properties = std.ArrayList(c.XrApiLayerProperties).init(allocator);
//     defer layer_properties.deinit();
//     try xrCheck(c.xrEnumerateApiLayerProperties(0, &layer_count, null), error.EnumerateApiLayerProperties,);
//     try layer_properties.append(c.XR_TYPE_API_LAYER_PROPERTIES);
//     try xrCheck(c.xrEnumerateApiLayerProperties(layer_count, &layer_count, @ptrCast(&layer_properties.items)), error.EnumerateApiLayerProperties,);

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
