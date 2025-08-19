const std = @import("std");
const World = @import("../ecs.zig").World;
const nz = @import("numz");

pub const Renderer = @import("renderer/renderer.zig").Renderer;
pub const GfxContext = @import("renderer/Context.zig");
pub const Input = @import("Input/Input.zig");
pub const AssetManager = @import("asset_manager/AssetManager.zig");
pub const physics = @import("physics.zig");
pub const IoCtx = @import("Input/Context.zig");
pub const time = @import("time.zig");

pub const BBAA = physics.BBAA;
pub const RigidBody = physics.Rigidbody;

pub const Transform = struct {
    position: nz.Vec3(f32) = @splat(0),
    rotation: nz.Vec3(f32) = @splat(0),
    scale: nz.Vec3(f32) = @splat(1),
};

pub const Mesh = struct {
    name: []const u8 = "default",
};

pub const Texture = struct {
    name: []const u8 = "default",
};

pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    try world.runSystems(allocator, .{
        Renderer.init,
        AssetManager.init,
        Renderer.initSwapchains,
        Input.init,
        time.init,
    });
}

pub fn deinit(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    try world.runSystems(allocator, .{
        AssetManager.deinit,
        Renderer.deinit,
    });
}

pub fn update(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    try world.runSystems(allocator, .{
        Renderer.beginFrame,
        time.update,
        Input.pollEvents,
        physics.update,
        Renderer.update,
    });
}
pub const Player = struct {};
