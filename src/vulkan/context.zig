const std = @import("std");
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

inline fn vkCheck(result: c.VkResult, err: anyerror) !void {
    if (result != c.VK_SUCCESS) return err;
}

pub const Context = struct {
    const Self = @This();

    instance: c.VkInstance,

    pub fn init() !Self {
        const instance = createInstance();

        return .{ .instance = instance };
    }

    pub fn deinit(_: Self) void {}

    fn createInstance() !c.VkInstance {
        var instance: c.VkInstance = undefined;

        var create_info = c.VkInstanceCreateInfo{ .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO };

        c.vkCreateInstance(&create_info, null, &instance);
    }
};
