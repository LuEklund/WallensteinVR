const std = @import("std");
const World = @import("../ecs.zig").World;
const eng = @import("../engine/root.zig");
const game = @import("../game/root.zig");
const Tilemap = @import("map.zig").Tilemap;
const nz = @import("numz");
const GfxContext = @import("../engine/renderer/Context.zig");

pub const Enemy = struct {
    sight: f32 = 15.0,
    speed: f32 = 1.0,
    health: f32 = 100.0,

    // Using a slice is better for constant data in structs
    pub const directions: []const nz.Vec3(f32) = &.{
        .{ 1, 0, 0 },
        .{ -1, 0, 0 },
        .{ 0, 0, 1 },
        .{ 0, 0, -1 },
    };
};

pub fn spawn(
    comptime comps: []const type,
    world: *World(comps),
    allocator: std.mem.Allocator,
) !void {
    const io_ctx = try world.getResource(eng.IoCtx);
    // Check for a specific key press to trigger spawn
    if (!io_ctx.keyboard.isPressed(.k)) {
        return;
    }

    const map_resource: *Tilemap = try world.getResource(Tilemap);
    const map = map_resource.*;

    var prng = std.Random.DefaultPrng.init(std.crypto.random.int(u64));
    const random = prng.random();

    while (true) {
        const pos_x: usize = random.intRangeAtMost(usize, 0, map.x - 1);
        const pos_y: usize = random.intRangeAtMost(usize, 0, map.y - 1);

        if (map.get(pos_x, pos_y) == 0) {
            _ = try world.spawn(
                allocator,
                .{
                    Enemy{},
                    eng.Transform{
                        .position = .{ @floatFromInt(pos_x), 0, @floatFromInt(pos_y) },
                        .scale = .{ 0.4, 3.0, 0.4 },
                    },
                    eng.Texture{ .name = "enemy.png" },
                    eng.Mesh{ .name = "Gusn.obj" },
                    eng.BBAA{ .min = .{ -0.1, -0.1, -0.1 }, .max = .{ 0.5, 3.1, 0.5 } },
                    eng.RigidBody{},
                },
            );
            break;
        }
    }
}

pub fn update(
    comptime comps: []const type,
    world: *World(comps),
    _: std.mem.Allocator,
) !void {
    var player_it = world.query(&.{ eng.Player, eng.Transform });
    const player_transform = player_it.next().?.get(eng.Transform).?.*;

    const map: *Tilemap = try world.getResource(Tilemap);
    var gfx_context = try world.getResource(GfxContext);

    var enemy_it = world.query(&.{ Enemy, eng.Transform, eng.RigidBody });
    while (enemy_it.next()) |entry| {
        const enemy = entry.get(Enemy).?.*;
        const transform = entry.get(eng.Transform).?.*;
        const rigidbody = entry.get(eng.RigidBody).?;

        const player_pos_2d: nz.Vec2(f32) = .{ player_transform.position[0], player_transform.position[2] };
        const enemy_pos_2d: nz.Vec2(f32) = .{ transform.position[0], transform.position[2] };

        const distance = nz.distance(transform.position, player_transform.position);
        if (distance >= enemy.sight) continue;
        if (nz.distance(player_pos_2d, enemy_pos_2d) <= 0.8) gfx_context.should_quit = true;

        var best_dir: ?nz.Vec3(f32) = null;
        var shortest_dist = distance;

        for (Enemy.directions) |dir| {
            const next_pos = transform.position + dir;

            const next_x: usize = @intFromFloat(next_pos[0]);
            const next_y: usize = @intFromFloat(next_pos[2]);

            if (next_x < 0 or next_y < 0 or next_x >= map.x or next_y >= map.y) continue;

            if (map.get(next_x, next_y) != 0) continue;

            const next_dist = nz.distance(next_pos, player_transform.position);

            if (next_dist < shortest_dist) {
                shortest_dist = next_dist;
                best_dir = dir;
            }
        }
        if (best_dir) |dir| {
            rigidbody.force = nz.scale(dir, enemy.speed);
        }
    }
}
