const std = @import("std");
const game = @import("root.zig");
const eng = @import("../engine/root.zig");
const World = @import("../ecs.zig").World;
const nz = @import("numz");

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
    const time = try world.getResource(eng.time.Time);
    var query_player = world.query(&.{ eng.Player, eng.Transform });
    var player = query_player.next().?;
    var transform = player.get(eng.Transform).?;
    const yaw = transform.rotation[1];
    const sin_yaw = @sin(yaw);
    const cos_yaw = @cos(yaw);

    const forward = [3]f32{ -sin_yaw, 0, -cos_yaw };
    const right = [3]f32{ cos_yaw, 0, -sin_yaw };

    std.debug.print("forward: {any}\n", .{forward});

    var move = [3]f32{ 0, 0, 0 };

    if (io_ctx.keyboard.isActive(.w)) {
        move[0] += forward[0];
        move[2] += forward[2];
    }
    if (io_ctx.keyboard.isActive(.s)) {
        move[0] -= forward[0];
        move[2] -= forward[2];
    }
    if (io_ctx.keyboard.isActive(.a)) {
        move[0] -= right[0];
        move[2] -= right[2];
    }
    if (io_ctx.keyboard.isActive(.d)) {
        move[0] += right[0];
        move[2] += right[2];
    }

    if (io_ctx.keyboard.isActive(.q)) move[1] -= 1;
    if (io_ctx.keyboard.isActive(.e)) move[1] += 1;

    transform.position += @as(nz.Vec3(f32), @splat(@as(f32, @floatCast(time.delta_time)))) * move;

    transform.position[0] += io_ctx.trackpad_state[0].currentState.x * right[0] * @as(f32, @floatCast(time.delta_time));
    transform.position[2] += io_ctx.trackpad_state[0].currentState.x * right[2] * @as(f32, @floatCast(time.delta_time));
    transform.position[0] += io_ctx.trackpad_state[0].currentState.y * forward[0] * @as(f32, @floatCast(time.delta_time));
    transform.position[2] += io_ctx.trackpad_state[0].currentState.y * forward[2] * @as(f32, @floatCast(time.delta_time));

    transform.rotation[1] -= io_ctx.trackpad_state[1].currentState.x * @as(f32, @floatCast(time.delta_time));

    if (io_ctx.keyboard.isActive(.left)) transform.rotation[1] += @floatCast(time.delta_time);
    if (io_ctx.keyboard.isActive(.right)) transform.rotation[1] -= @floatCast(time.delta_time);
    var query = world.query(&.{ game.Hand, eng.Transform });
    while (query.next()) |entity| {
        const hand = entity.get(game.Hand).?;
        var hand_transform = entity.get(eng.Transform).?;
        hand_transform.position = @bitCast(io_ctx.hand_pose[@intFromEnum(hand.side)].position);
        hand_transform.position += transform.position;
    }
}
