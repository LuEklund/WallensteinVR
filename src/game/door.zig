const std = @import("std");
const game = @import("root.zig");
const eng = @import("../engine/root.zig");
const World = @import("../ecs.zig").World;
const nz = @import("numz");
const GfxContext = @import("../engine/renderer/Context.zig");

pub fn update(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    var player_query = world.query(&.{ eng.Player, eng.Transform, eng.BBAA });
    const player = player_query.next().?;
    const player_transform = player.get(eng.Transform).?;
    const player_aabb = player.get(eng.BBAA).?;
    const player_bbaa_relative = player_aabb.toRelative(player_transform.position);

    var door_query = world.query(&.{ game.Door, eng.Transform, eng.BBAA, eng.Texture });
    const door = door_query.next().?;
    const door_door = door.get(game.Door).?;
    const door_texture = door.get(eng.Texture).?;
    const door_transform = door.get(eng.Transform).?;
    const door_aabb = door.get(eng.BBAA).?;
    const door_bbaa_relative = door_aabb.toRelative(door_transform.position);

    const time = try world.getResource(eng.time.Time);

    const doot_tex: [13][]const u8 = .{
        "door0.png",
        "door1.png",
        "door2.png",
        "door3.png",
        "door4.png",
        "door5.png",
        "door6.png",
        "door7.png",
        "door8.png",
        "door9.png",
        "door10.png",
        "door11.png",
        "door12.png",
    };
    if (door_door.accumulated_time >= door_door.change_time) {
        door_door.texture_id = (door_door.texture_id + 1) % 13;
        door_texture.name = doot_tex[door_door.texture_id];
        door_door.accumulated_time = 0;
    }
    door_door.accumulated_time += @floatCast(time.delta_time);

    if (door_bbaa_relative.intersecting(player_bbaa_relative) == false) return;

    var hand_querty = world.query(&.{ game.Hand, eng.Mesh });
    while (hand_querty.next()) |entry| {
        const hand = entry.get(game.Hand).?;
        if (hand.equiped == .collectable) {
            const hand_mesh = entry.get(eng.Mesh).?;
            hand_mesh.should_render = true;
            hand.equiped = .pistol;
            try game.gameOver(comps, world, allocator, door_transform, true);
        }
    }
}
