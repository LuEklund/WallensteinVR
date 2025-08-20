const std = @import("std");
const game = @import("root.zig");
const eng = @import("../engine/root.zig");
const World = @import("../ecs.zig").World;
const nz = @import("numz");
const GfxContext = @import("../engine/renderer/Context.zig");

pub fn update(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    var player_query = world.query(&.{ eng.Player, eng.Transform, eng.BBAA });
    const player = player_query.next().?;
    const player_transform = player.get(eng.Transform).?;
    const player_aabb = player.get(eng.BBAA).?;
    const player_bbaa_relative = player_aabb.toRelative(player_transform.position);

    var door_query = world.query(&.{ game.Door, eng.Transform, eng.BBAA });
    const door = door_query.next().?;
    const door_transform = door.get(eng.Transform).?;
    const door_aabb = door.get(eng.BBAA).?;
    const door_bbaa_relative = door_aabb.toRelative(door_transform.position);

    if (door_bbaa_relative.intersecting(player_bbaa_relative) == false) return;

    var hand_querty = world.query(&.{game.Hand});
    while (hand_querty.next()) |entry| {
        const hand = entry.get(game.Hand).?;
        if (hand.equiped == .collectable) {
            // var gfx_context = try world.getResource(GfxContext);
            // gfx_context.should_quit = true;
        }
    }
}
