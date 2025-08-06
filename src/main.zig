const std = @import("std");
const World = @import("ecs.zig").World;

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{ .verbose_log = true }) = .init;
    const smp_allocator = std.heap.smp_allocator;

    const allocator = if (@import("builtin").mode == .Debug)
        debug_allocator.allocator()
    else
        smp_allocator;

    var world: World(
        &[_]type{ Velocity, Position },
    ) = .init();
    defer world.deinit(allocator);
    try world.runSystems(allocator, .{someInitSystem});

    while (true) {
        try world.runSystems(allocator, .{someUpdateSystem});
    }
}

pub const Velocity = struct {
    x: usize = 0,
    y: usize = 0,
};

pub const Position = struct {
    x: usize = 0,
    y: usize = 0,
    z: usize = 1,
};

pub fn someInitSystem(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    for (0..10) |i| {
        _ = if (i % 2 == 0)
            try world.spawn(allocator, .{Velocity{ .x = i, .y = i }})
        else
            try world.spawn(allocator, .{ Velocity{ .x = i, .y = i }, Position{ .x = i, .y = i } });
    }
}

// mashed potato

pub fn someUpdateSystem(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    var query = world.query(&.{ Velocity, Position });

    while (query.next()) |entity| {
        const velocity = entity.get(Velocity).?;
        const position = entity.get(Position);

        std.debug.print("ID: {d} ", .{entity.id});

        if (position) |p| {
            std.debug.print("Pos! {d} {d} ", .{ p.x, p.y });
            p.x += velocity.x;
            p.y += velocity.y;
        }

        std.debug.print("Vel! {d} {d}\n", .{ velocity.x, velocity.y });
    }
}
