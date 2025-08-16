const std = @import("std");
const game = @import("root.zig");
const eng = @import("../engine/root.zig");
const World = @import("../ecs.zig").World;

pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    // for (0..4) |i| {
    //     var fx: f32 = @floatFromInt(i);
    //     fx = fx / 5;
    //     for (0..4) |j| {
    //         var fy: f32 = @floatFromInt(j);
    //         fy = fy / 5;
    //         for (0..4) |k| {
    //             var fz: f32 = @floatFromInt(k);
    //             fz = fz / 5 - 2;
    //             _ = try world.spawn(allocator, .{
    //                 eng.physics.Rigidbody{ .force = .{ std.math.sin(fx) / 1000, std.math.cos(fy) / 1000, std.math.tan(fz) / 1000 } },
    //                 eng.Transform{ .position = .{ fx, fy, fz } },
    //                 eng.Mesh{ .name = "basket.obj" },
    //             });
    //         }
    //     }
    // }

    // _ = try world.spawn(allocator, .{
    //     eng.Transform{
    //         .position = .{ 0, 0, 0 },
    //         .scale = .{ 0.1, 0.1, 0.1 },
    //     },
    //     eng.Mesh{ .name = "basket.obj" },
    //     game.Hand{ .side = .left },
    // });
    // _ = try world.spawn(allocator, .{
    //     eng.Transform{
    //         .position = .{ 0, 0, 0 },
    //         .scale = .{ 0.1, 0.1, 0.1 },
    //     },
    //     eng.Mesh{ .name = "cube.obj" },
    //     game.Hand{ .side = .right },
    // });
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
