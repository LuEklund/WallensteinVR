const std = @import("std");
const World = @import("../ecs.zig").World;
const game = @import("root.zig");
const eng = @import("../engine/root.zig");
pub fn update(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    var bullet_query = world.query(&.{game.Bullet});
    const time = try world.getResource(eng.time.Time);
    while (bullet_query.next()) |entity| {
        const bullet = entity.get(game.Bullet).?;
        if (bullet.time_of_death >= time.current_time_ns) {
            try world.remove(allocator, entity.id);
        }
    }
}
