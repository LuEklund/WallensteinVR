const std = @import("std");
const game = @import("root.zig");
const eng = @import("../engine/root.zig");
const World = @import("../ecs.zig").World;
const nz = @import("numz");

pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {

    //PLAYER
    _ = try world.spawn(allocator, .{
        eng.Mesh{ .name = "csdsd" },
        eng.Transform{
            .position = .{ 0, 1, 0 },
            .scale = @splat(0.1),
        },
        eng.Texture{ .name = "bisng.jpg" },
        eng.Player{},
        eng.BBAA{},
        eng.RigidBody{},
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

pub fn update(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    const io_ctx = try world.getResource(eng.IoCtx);
    const asset_manager = try world.getResource(eng.AssetManager);
    const map = try world.getResource(game.map.Tilemap);

    const time = try world.getResource(eng.time.Time);
    var speed: f32 = 300;
    var rot_speed: f32 = 3;

    var query_player = world.query(&.{ eng.Player, eng.Transform, eng.RigidBody });
    var player = query_player.next().?;
    var transform = player.get(eng.Transform).?;
    var rigidbody = player.get(eng.RigidBody).?;
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
        speed = 2000;
        rot_speed = 6;
    }
    rigidbody.force = @as(nz.Vec3(f32), @splat(@as(f32, @floatCast(time.delta_time)))) * move * @as(nz.Vec3(f32), @splat(speed));

    rigidbody.force[0] += io_ctx.trackpad_state[0].currentState.x * right[0] * @as(f32, @floatCast(time.delta_time)) * speed;
    rigidbody.force[2] += io_ctx.trackpad_state[0].currentState.x * right[2] * @as(f32, @floatCast(time.delta_time)) * speed;
    rigidbody.force[0] += io_ctx.trackpad_state[0].currentState.y * forward[0] * @as(f32, @floatCast(time.delta_time)) * speed;
    rigidbody.force[2] += io_ctx.trackpad_state[0].currentState.y * forward[2] * @as(f32, @floatCast(time.delta_time)) * speed;

    const to_be_pos = rigidbody.force * @as(nz.Vec3(f32), @splat(0.1));
    const player_x: i32 = @intFromFloat(transform.position[0] + to_be_pos[0]);
    const player_y: i32 = @intFromFloat(transform.position[2] + to_be_pos[2]);
    if (player_x >= 0 and player_x < map.x and player_y >= 0 and player_y < map.y and map.get(@intCast(player_x), @intCast(player_y)) == 1) {
        rigidbody.force = @splat(0);
    } else {}

    transform.rotation[1] -= io_ctx.trackpad_state[1].currentState.x * @as(f32, @floatCast(time.delta_time));

    if (io_ctx.keyboard.isActive(.left)) transform.rotation[1] += @as(f32, @floatCast(time.delta_time)) * rot_speed;
    if (io_ctx.keyboard.isActive(.right)) transform.rotation[1] -= @as(f32, @floatCast(time.delta_time)) * rot_speed;
    var query = world.query(&.{ game.Hand, eng.Transform });
    while (query.next()) |entity| {
        const hand = entity.get(game.Hand).?;
        var hand_transform = entity.get(eng.Transform).?;
        const hand_id = @intFromEnum(hand.side);
        const local_hand_pos: nz.Vec3(f32) = @bitCast(io_ctx.hand_pose[hand_id].position);

        const rotated_hand_pos = nz.Vec3(f32){
            local_hand_pos[0] * cos_yaw - local_hand_pos[2] * -sin_yaw,
            local_hand_pos[1],
            local_hand_pos[0] * -sin_yaw + local_hand_pos[2] * cos_yaw,
        };
        hand_transform.rotation = transform.rotation;
        const hand_rot: nz.Vec3(f32) = quatToEuler(@bitCast(io_ctx.hand_pose[hand_id].orientation));
        hand_transform.rotation[0] += hand_rot[0]; // TODO: fix he Roll?
        hand_transform.rotation[1] += hand_rot[1];
        hand_transform.rotation[2] += hand_rot[2];
        hand_transform.position = transform.position + rotated_hand_pos;

        switch (hand.equiped) {
            .none => {},
            .pistol => {
                if (hand.curr_cooldown <= 0) {
                    if (io_ctx.trigger_state[hand_id].isActive != 0 and (io_ctx.trigger_state[hand_id].currentState > 0.5 or io_ctx.keyboard.isPressed(.return_key))) {
                        try asset_manager.getSound("error.wav").play(0.5);
                        hand.curr_cooldown = hand.reset_cooldown;
                        _ = try world.spawn(allocator, .{
                            eng.Transform{ .position = hand_transform.position },
                            eng.Mesh{},
                            eng.Texture{ .name = "windows_xp.jpg" },
                            eng.RigidBody{ .force = rotated_hand_pos * @as(nz.Vec3(f32), @splat(1)), .mass = 0 },
                            eng.BBAA{},
                            game.Bullet{ .time_of_death = time.current_time_ns + 1000 * 1000 * 1000 * 60 }, //Nano * Micro * Milli * Seconds
                        });
                    }
                } else {
                    hand.curr_cooldown -= @floatCast(time.delta_time);
                }
            },
            .collectable => {
                var c_transform = world.getComponentByEntity(eng.Transform, hand.equiped.collectable);
                if (c_transform != null) c_transform.?.position = hand_transform.position;
            },
        }
        var query_collectable = world.query(&.{ game.collectable, eng.Transform });
        while (query_collectable.next()) |entry| {
            var collected = entry.get(game.collectable).?;
            if (collected.collected == true) continue;
            const c_transform = entry.get(eng.Transform).?;
            if (@abs(nz.distance(c_transform.position, hand_transform.position)) < 0.5) {
                hand_transform.scale = @splat(0);
                collected.collected = true;
                hand.equiped = .{ .collectable = entry.id };
            }
        }
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
