const std = @import("std");
const World = @import("../ecs.zig").World;
const nz = @import("numz");
pub const map = @import("map.zig");
pub const player = @import("player.zig");
pub const enemy = @import("enemy.zig");
pub const some = @import("some.zig");
pub const bullets = @import("bullets.zig");
pub const door = @import("door.zig");
const eng = @import("../engine/root.zig");

pub const Hand = struct {
    side: enum(usize) { left = 0, right = 1 },
    equiped: union(enum) { none: void, pistol: void, collectable: u32 } = .{ .pistol = {} },
    curr_cooldown: f32 = 0,
    reset_cooldown: f32 = 0.2,
};

pub const Bullet = struct {
    time_of_death: i128 = 0,
};

pub const collectable = struct {
    collected: bool = false,
};

pub const Door = struct {
    texture_id: u8 = 0,
    accumulated_time: f32 = 0,
    change_time: f32 = 0.1,
};

pub const WorldMap = struct {};

pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    try world.runSystems(allocator, .{
        player.init,
        some.init,
        enemy.init,
    });
}

pub fn deinit(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    try world.runSystems(allocator, .{});
}

pub fn update(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    try world.runSystems(allocator, .{
        player.update,
        some.update,
        enemy.update,
        bullets.update,
        door.update,
    });
}
