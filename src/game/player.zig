const std = @import("std");
const game = @import("root.zig");
const eng = @import("../engine/root.zig");
const World = @import("../ecs.zig").World;

pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    _ = try world.spawn(allocator, .{
        eng.Transform{
            // .position = .{ 0, 0, 0 },
            // .scale = .{ 0.1, 0.1, 0.1 },
        },
    });
}

pub fn update(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    var query = world.query(&.{ game.Hand, eng.Transform });
    const ctx = try world.getResource(eng.GfxContext);
    while (query.next()) |entity| {
        const hand = entity.get(game.Hand).?;
        const transform = entity.get(eng.Transform).?;

        transform.position = @bitCast(ctx.hand_pose[@intFromEnum(hand.side)].position);
    }
}
