const std = @import("std");
const c = @cImport({
    @cInclude("openxr/openxr.h");
    @cInclude("openxr/openxr_platform.h");
});

pub fn main() !void {
    var instance: c.XrInstance = undefined;

    var create_info = c.XrInstanceCreateInfo{
        .type = c.XR_TYPE_INSTANCE_CREATE_INFO,
        .next = null,
        .createFlags = 0,
        .applicationInfo = .{
            // .applicationName = "Appname", <-- Kinda weird, just ignore
            .applicationVersion = 1,
            // .engineName = "EngineName", <-- Kinda weird, just ignore
            .engineVersion = 1,
            .apiVersion = c.XR_CURRENT_API_VERSION,
        },
        .enabledExtensionCount = 0,
        .enabledExtensionNames = null,
    };

    const result = c.xrCreateInstance(&create_info, &instance);
    if (result != c.XR_SUCCESS) {
        std.debug.print("Failed to create OpenXR Instance: {d}\n", .{result});
        return;
    }
}
