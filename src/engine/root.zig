const nz = @import("numz");

pub const Renderer = @import("renderer/renderer.zig").Renderer;
pub const Input = @import("Input/Input.zig");
pub const AssetManager = @import("asset_manager/AssetManager.zig");
pub const physics = @import("physics.zig");

pub const Transform = struct {
    position: nz.Vec3(f32) = @splat(0),
    rotation: nz.Vec3(f32) = @splat(0),
    scale: nz.Vec3(f32) = @splat(0.1),
};

pub const Mesh = struct {
    name: []const u8,
};
