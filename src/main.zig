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
    for (0..2) |i| {
        const f: f32 = @floatFromInt(i);
        _ = if (i % 2 == 0)
            try world.spawn(allocator, .{eng.RigidBody{}})
        else
            try world.spawn(allocator, .{ eng.RigidBody{}, eng.Transform{ .position = .{ f, f, f } }, eng.Mesh{ .name = "xyzdragon.obj" } });
    }
}

// mashed potato

pub fn someUpdateSystem(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    const query = world.query(&.{ eng.RigidBody, eng.Transform });
    _ = query;

    // while (query.next()) |entity| {
    //     const velocity = entity.get(eng.RigidBody).?;
    //     const position = entity.get(eng.Transform);

    //     std.debug.print("ID: {d} ", .{entity.id});

    //     if (position) |p| {
    //         std.debug.print("Pos! {d} {d} ", .{ p.x, p.y });
    //         p.x += velocity.x;
    //         p.y += velocity.y;
    //     }

    //     std.debug.print("Vel! {d} {d}\n", .{ velocity.x, velocity.y });
    // }
}
