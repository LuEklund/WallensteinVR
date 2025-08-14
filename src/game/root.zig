const std = @import("std");
const World = @import("../ecs.zig").World;
const nz = @import("numz");
pub const map = @import("map.zig");
pub const player = @import("player.zig");
pub const enemy = @import("enemy.zig");
pub const some = @import("some.zig");

pub const Hand = struct {
    side: enum(usize) { left = 0, right = 1 },
};

pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    try world.runSystems(allocator, .{
        player.init,
        some.init,
    });
}

pub fn deinit(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    try world.runSystems(allocator, .{});
}

pub fn update(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    try world.runSystems(allocator, .{
        player.update,
        enemy.enemyUpdateSystem,
        some.update,
    });
}
