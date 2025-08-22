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

pub fn gameOver(comps: []const type, world: *World(comps), allocator: std.mem.Allocator, end_transform: *eng.Transform, win: bool) !void {
    const asset_manager = try world.getResource(eng.AssetManager);
    var enemy_ctx = try world.getResource(enemy.EnemyCtx);
    enemy_ctx.can_spawm = false;
    var enemy_querty = world.query(&.{enemy.Enemy});
    while (enemy_querty.next()) |enemy_entry| {
        try world.remove(allocator, enemy_entry.id);
    }

    if (win == true) {
        try asset_manager.getSound("win.wav").play(0.5);
    } else {
        try asset_manager.getSound("loss.wav").play(0.5);
    }

    _ = try world.spawn(allocator, .{
        eng.Transform{ .position = end_transform.position + @as(nz.Vec3(f32), @splat(2.5)), .scale = @splat(-5) },
        eng.Mesh{},
        eng.Texture{ .name = "GameOver.jpg" },
    });
    var world_query = world.query(&.{ WorldMap, eng.Transform });
    var world_transform = world_query.next().?.get(eng.Transform).?;
    world_transform.scale = @splat(0.1);
    world_transform.position = end_transform.position - @as(nz.Vec3(f32), @splat(2.5));
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
