const std = @import("std");
const game = @import("root.zig");
const eng = @import("../engine/root.zig");
const World = @import("../ecs.zig").World;

pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    _ = try world.spawn(allocator, .{
        eng.Transform{
            // .position = .{ 0, -0.5, -5 },
            // .scale = .{ 0.1, 0.1, 1},
        },
        eng.Texture{ .name = "error_wall.jpg" },
        eng.Mesh{ .name = "world" },
    });
}

pub fn update(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    _ = world;
    // var query = world.query(&.{eng.Transform});
    // var query_player = world.query(&.{eng.Player});
    // const player_id = query_player.next().?.id;
    // const time = try world.getResource(eng.Time.Time);

    // while (query.next()) |entity| {
    //     if (entity.id == player_id) continue;
    //     // const rigidbody = entity.get(eng.physics.Rigidbody).?;
    //     const transform = entity.get(eng.Transform).?;

    //     // std.debug.print("ID: {d} ", .{entity.id});
    //     transform.rotation[1] += @floatCast(time.delta_time);
    //     // std.debug.print("Pos! {d} {d} ", .{ p.x, p.y });
    //     // transform.position[0] += rigidbody.force[0] * std.math.sin(transform.position[0]);
    //     // transform.position[1] += rigidbody.force[1] * std.math.sin(transform.position[1]);

    //     // std.debug.print("Vel! {d} {d}\n", .{ velocity.x, velocity.y });
    // }
}
