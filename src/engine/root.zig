const nz = @import("numz");

pub const Renderer = @import("renderer/renderer.zig").Renderer;
pub const AssetManager = @import("asset_manager/AssetManager.zig");

pub const RigidBody = struct {
    force: nz.Vec3(f32) = @splat(0),
    mass: f32 = 1,
};

pub const Transform = struct {
    position: nz.Vec3(f32) = @splat(0),
    rotation: nz.Vec3(f32) = @splat(0),
    scale: nz.Vec3(f32) = @splat(1),
};

pub const Mesh = struct {
    name: []const u8,
};
