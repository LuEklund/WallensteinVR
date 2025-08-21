const std = @import("std");
const World = @import("../ecs.zig").World;
const game = @import("root.zig");
const eng = @import("../engine/root.zig");
const nz = @import("numz");

pub fn update(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    var bullet_query = world.query(&.{ game.Bullet, eng.Transform, eng.BBAA });
    const time = try world.getResource(eng.time.Time);
    while (bullet_query.next()) |entity| {
        const bullet_transform = entity.get(eng.Transform).?;
        const bullet_bbaa = entity.get(eng.BBAA).?;
        const relative_bullet_bbaa: eng.BBAA = bullet_bbaa.toRelative(bullet_transform.position);

        var enemy_query = world.query(&.{ game.enemy.Enemy, eng.Transform, eng.BBAA });
        while (enemy_query.next()) |entity2| {
            const enemy_transform = entity2.get(eng.Transform).?;
            const enemy_bbaa = entity2.get(eng.BBAA).?;
            if (@abs(nz.distance(bullet_transform.position, enemy_transform.position)) > 4) continue;
            const relative_enemy_bbaa: eng.BBAA = enemy_bbaa.toRelative(enemy_transform.position);
            if (relative_bullet_bbaa.intersecting(relative_enemy_bbaa)) {
                try world.remove(allocator, entity2.id);
            }
        }

        const bullet = entity.get(game.Bullet).?;
        if (bullet.time_of_death <= time.current_time_ns) {
            try world.remove(allocator, entity.id);
        }
    }
}
