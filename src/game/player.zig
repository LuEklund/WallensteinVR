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
        // eng.Mesh{ .name = "csdsd" },
        eng.Transform{
            .position = .{ 0, 1, 0 },
            .scale = .{ 0.1, 0.1, 0.1 },
        },
        eng.Texture{ .name = "s" },
        eng.Player{},
    });
    //HANDS
    _ = try world.spawn(allocator, .{
        eng.Transform{
            .position = .{ 0, 0, 0 },
            .scale = @splat(0.03),
        },
        eng.Mesh{ .name = "Gun.obj" },
        eng.Texture{ .name = "33.jpg" },
        game.Hand{ .side = .left },
    });
    _ = try world.spawn(allocator, .{
        eng.Transform{
            .position = .{ 0, 0, 0 },
            .scale = @splat(0.03),
        },
        eng.Mesh{ .name = "Gun.obj" },
        eng.Texture{ .name = "33.jpg" },
        game.Hand{ .side = .right },
    });
}

pub fn update(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    const io_ctx = try world.getResource(eng.IoCtx);

    const time = try world.getResource(eng.time.Time);
    var speed: f32 = 1;
    var rot_speed: f32 = 1;

    var query_player = world.query(&.{ eng.Player, eng.Transform });
    var player = query_player.next().?;
    var transform = player.get(eng.Transform).?;
    const yaw = transform.rotation[1];
    const sin_yaw = @sin(yaw);
    const cos_yaw = @cos(yaw);

    const forward = [3]f32{ -sin_yaw, 0, -cos_yaw };
    const right = [3]f32{ cos_yaw, 0, -sin_yaw };

    // std.debug.print("forward: {any}\n", .{forward});

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

    if (io_ctx.keyboard.isActive(.left_shift)) {
        speed = 10;
        rot_speed = 5;
    }
    transform.position += @as(nz.Vec3(f32), @splat(@as(f32, @floatCast(time.delta_time)))) * move * @as(nz.Vec3(f32), @splat(speed));

    transform.position[0] += io_ctx.trackpad_state[0].currentState.x * right[0] * @as(f32, @floatCast(time.delta_time));
    transform.position[2] += io_ctx.trackpad_state[0].currentState.x * right[2] * @as(f32, @floatCast(time.delta_time));
    transform.position[0] += io_ctx.trackpad_state[0].currentState.y * forward[0] * @as(f32, @floatCast(time.delta_time));
    transform.position[2] += io_ctx.trackpad_state[0].currentState.y * forward[2] * @as(f32, @floatCast(time.delta_time));

    transform.rotation[1] -= io_ctx.trackpad_state[1].currentState.x * @as(f32, @floatCast(time.delta_time));

    if (io_ctx.keyboard.isActive(.left)) transform.rotation[1] += @as(f32, @floatCast(time.delta_time)) * rot_speed;
    if (io_ctx.keyboard.isActive(.right)) transform.rotation[1] -= @as(f32, @floatCast(time.delta_time)) * rot_speed;
    var query = world.query(&.{ game.Hand, eng.Transform });
    while (query.next()) |entity| {
        const hand = entity.get(game.Hand).?;
        var hand_transform = entity.get(eng.Transform).?;
        const local_hand_pos: nz.Vec3(f32) = @bitCast(io_ctx.hand_pose[@intFromEnum(hand.side)].position);

        const rotated_hand_pos = nz.Vec3(f32){
            local_hand_pos[0] * cos_yaw - local_hand_pos[2] * -sin_yaw,
            local_hand_pos[1],
            local_hand_pos[0] * -sin_yaw + local_hand_pos[2] * cos_yaw,
        };
        hand_transform.rotation = transform.rotation;
        std.debug.print("Rot: {}\n", .{io_ctx.hand_pose[@intFromEnum(hand.side)].orientation});
        const hand_rot: nz.Vec3(f32) = quatToEuler(@bitCast(io_ctx.hand_pose[@intFromEnum(hand.side)].orientation));
        std.debug.print("Rot-Mat: {}\n", .{hand_rot});
        hand_transform.rotation[0] += hand_rot[0]; // TODO: fix he Roll?
        hand_transform.rotation[1] += hand_rot[1];
        hand_transform.rotation[2] += hand_rot[2];
        hand_transform.position = transform.position + rotated_hand_pos;
        // hand_transform.position = transform.position + rotated_hand_pos + @as(
        // nz.Vec3(f32),
        // @bitCast(io_ctx.xr_views[0].pose.position),
        // );
    }
}

fn quatToEuler(q: nz.Vec4(f32)) nz.Vec3(f32) {
    const x = q[0];
    const y = q[1];
    const z = q[2];
    const w = q[3];

    // roll (x-axis rotation)
    const sinr_cosp = 2.0 * (w * x + y * z);
    const cosr_cosp = 1.0 - 2.0 * (x * x + y * y);
    const roll = std.math.atan2(sinr_cosp, cosr_cosp);

    // pitch (y-axis rotation)
    const sinp: f32 = 2.0 * (w * y - z * x);
    var pitch: f32 = undefined;
    if (@abs(sinp) >= 1.0) {
        // use 90 degrees if out of range
        pitch = 0;
        // pitch = std.math.copysign(std.math.pi / 2.0, sinp);
    } else {
        pitch = std.math.asin(sinp);
    }

    // yaw (z-axis rotation)
    const siny_cosp = 2.0 * (w * z + x * y);
    const cosy_cosp = 1.0 - 2.0 * (y * y + z * z);
    const yaw = std.math.atan2(siny_cosp, cosy_cosp);

    return nz.Vec3(f32){ roll, pitch, -yaw };
}
