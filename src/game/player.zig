const std = @import("std");
const game = @import("root.zig");
const eng = @import("../engine/root.zig");
const World = @import("../ecs.zig").World;

pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {

    //     const io_ctx: *eng.IoCtx = try world.getResource(eng.);
    // io_ctx.*.player_pos[0] = @floatFromInt(map.start_x);
    // io_ctx.*.player_pos[2] = @floatFromInt(map.start_y);
    //PLAYER
    _ = try world.spawn(allocator, .{
        eng.Transform{
            .position = .{ 0, 1, 0 },
            .scale = .{ 1, 1, 1 },
        },
        eng.Player{},
    });
    //HANDS
    _ = try world.spawn(allocator, .{
        eng.Transform{
            .position = .{ 0, 0, 0 },
            .scale = .{ 0.1, 0.1, 0.1 },
        },
        eng.Mesh{ .name = "basket.obj" },
        game.Hand{ .side = .left },
    });
    _ = try world.spawn(allocator, .{
        eng.Transform{
            .position = .{ 0, 0, 0 },
            .scale = .{ 0.1, 0.1, 0.1 },
        },
        eng.Mesh{ .name = "cube.obj" },
        game.Hand{ .side = .right },
    });
}

pub fn update(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    const io_ctx = try world.getResource(eng.IoCtx);
    const time = try world.getResource(eng.Time.Time);
    var query_player = world.query(&.{ eng.Player, eng.Transform });
    while (query_player.next()) |entity| {
        var transform = entity.get(eng.Transform).?;
        if (io_ctx.keyboard.isActive(.w)) transform.position[2] -= @floatCast(time.delta_time);
        if (io_ctx.keyboard.isActive(.s)) transform.position[2] += @floatCast(time.delta_time);
        if (io_ctx.keyboard.isActive(.a)) transform.position[0] -= @floatCast(time.delta_time);
        if (io_ctx.keyboard.isActive(.d)) transform.position[0] += @floatCast(time.delta_time);
        if (io_ctx.keyboard.isActive(.q)) transform.position[1] -= @floatCast(time.delta_time);
        if (io_ctx.keyboard.isActive(.e)) transform.position[1] += @floatCast(time.delta_time);
        if (io_ctx.keyboard.isActive(.left)) transform.rotation[1] += @floatCast(time.delta_time);
        if (io_ctx.keyboard.isActive(.right)) transform.rotation[1] -= @floatCast(time.delta_time);
    }

    var query = world.query(&.{ game.Hand, eng.Transform });

    // if (io_ctx.keyboard.isActive(.left)) io_ctx.p += 0.016;
    // if (io_ctx.keyboard.isActive(.right)) io_ctx.player_pos[1] += 0.016;
    // io_ctx.player_pos[0] += io_ctx.trackpad_state[0].currentState.x / 100;
    // io_ctx.player_pos[2] += io_ctx.trackpad_state[0].currentState.y / 100;
    while (query.next()) |entity| {
        const hand = entity.get(game.Hand).?;
        var transform = entity.get(eng.Transform).?;
        transform.position = @bitCast(io_ctx.hand_pose[@intFromEnum(hand.side)].position);
    }
}
