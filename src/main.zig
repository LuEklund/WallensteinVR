const std = @import("std");
const World = @import("ecs.zig").World;
const eng = @import("engine/root.zig");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{ .verbose_log = true }) = .init;
    const smp_allocator = std.heap.smp_allocator;

    const allocator = if (@import("builtin").mode == .Debug)
        debug_allocator.allocator()
    else
        smp_allocator;

    var world: World(
        &[_]type{ eng.RigidBody, eng.Transform, eng.Mesh },
    ) = .init();
    defer world.deinit(allocator);
    try world.runSystems(allocator, .{ eng.Renderer.init, eng.AssetManager.init, someInitSystem });

    while (true) {
        try world.runSystems(allocator, .{ eng.Renderer.update, someUpdateSystem });
    }
    try world.runSystems(allocator, .{eng.AssetManager.deinit});
}

pub fn someInitSystem(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    for (0..4) |i| {
        var fx: f32 = @floatFromInt(i);
        fx = fx / 5;
        for (0..4) |j| {
            var fy: f32 = @floatFromInt(j);
            fy = fy / 5;
            for (0..4) |k| {
                var fz: f32 = @floatFromInt(k);
                fz = fz / 5 - 2;
                _ = try world.spawn(allocator, .{
                    eng.RigidBody{ .force = .{ std.math.sin(fx) / 1000, std.math.cos(fy) / 1000, std.math.tan(fz) / 1000 } },
                    eng.Transform{ .position = .{ fx, fy, fz } },
                    eng.Mesh{ .name = "cube.obj" },
                });
            }
        }
    }

    _ = try world.spawn(allocator, .{
        eng.Transform{
            .position = .{ 0, -1, 0 },
            .scale = .{ 10, 0.01, 10 },
        },
        eng.Mesh{ .name = "cube.obj" },
    });

    _ = try world.spawn(allocator, .{
        eng.Transform{
            .position = .{ 0, 0, -0.5 },
            .scale = .{ 0.01, 0.01, 0.01 },
        },
        eng.Mesh{ .name = "cube.obj" },
    });
}

// mashed potato

pub fn someUpdateSystem(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    var query = world.query(&.{ eng.RigidBody, eng.Transform });
    // _ = query;

    while (query.next()) |entity| {
        const rigid_body = entity.get(eng.RigidBody).?;
        const transform = entity.get(eng.Transform).?;

        // std.debug.print("ID: {d} ", .{entity.id});

        // std.debug.print("Pos! {d} {d} ", .{ p.x, p.y });
        transform.position[0] += rigid_body.force[0];
        transform.position[1] += rigid_body.force[1];

        // std.debug.print("Vel! {d} {d}\n", .{ velocity.x, velocity.y });
    }
}
