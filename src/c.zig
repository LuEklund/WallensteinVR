pub const c = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cDefine("XR_USE_GRAPHICS_API_VULKAN", "1");
    @cInclude("openxr/openxr.h");
    @cInclude("openxr/openxr_platform.h");
});
pub usingnamespace c;

pub inline fn check(result: c_int, err: anyerror) !void {
    if (result != 1) return err;
}
