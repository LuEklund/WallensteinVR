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
    const enemy_ctx = try world.getResource(game.enemy.EnemyCtx);

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
    if (enemy_ctx.can_spawm == true) {
        if (player_x >= 0 and player_x < map.x and player_y >= 0 and player_y < map.y and map.get(@intCast(player_x), @intCast(player_y)) == 1) {
            rigidbody.force = @splat(0);
        }
    }
    transform.rotation[1] -= io_ctx.trackpad_state[1].currentState.x * @as(f32, @floatCast(time.delta_time));

    if (io_ctx.keyboard.isActive(.left)) transform.rotation[1] += @as(f32, @floatCast(time.delta_time)) * rot_speed;
    if (io_ctx.keyboard.isActive(.right)) transform.rotation[1] -= @as(f32, @floatCast(time.delta_time)) * rot_speed;
    var query = world.query(&.{ game.Hand, eng.Transform, eng.Mesh });
    while (query.next()) |entity| {
        const hand = entity.get(game.Hand).?;
        var hand_transform = entity.get(eng.Transform).?;
        var hand_mesh = entity.get(eng.Mesh).?;
        const hand_id = @intFromEnum(hand.side);
        const local_hand_pos: nz.Vec3(f32) = @bitCast(io_ctx.hand_pose[hand_id].position);

        const rotated_hand_pos = nz.Vec3(f32){
            local_hand_pos[0] * cos_yaw - local_hand_pos[2] * -sin_yaw,
            local_hand_pos[1],
            local_hand_pos[0] * -sin_yaw + local_hand_pos[2] * cos_yaw,
        };

        hand_transform.position = transform.position + rotated_hand_pos;
        const hand_quat: nz.Vec4(f32) = @bitCast(io_ctx.hand_pose[hand_id].orientation);

        // player yaw -> quaternion
        const prev_hand_yaw = transform.rotation[1];
        const half = prev_hand_yaw * 0.5;
        const player_quat = nz.Vec4(f32){
            0.0,
            std.math.sin(half),
            0.0,
            std.math.cos(half),
        };

        const combined = quatMul(player_quat, hand_quat);

        const pyr: nz.Vec3(f32) = quatToPYR(combined);

        const sign = nz.Vec3(f32){ 1.0, 1.0, 1.0 };
        // if (right[0] < 0) sign[0] = -1;

        const target_p = pyr[0] * sign[0];
        const target_y = pyr[1] * sign[1];
        const target_r = pyr[2] * sign[2];

        // unwrap to keep continuity
        hand_transform.rotation[2] = unwrapAngle(hand_transform.rotation[0], target_p); // pitch
        hand_transform.rotation[1] = unwrapAngle(hand_transform.rotation[1], target_y); // yaw
        hand_transform.rotation[0] = unwrapAngle(hand_transform.rotation[2], target_r); // roll

        switch (hand.equiped) {
            .none => {},
            .pistol => {
                if (hand.curr_cooldown <= 0) {
                    if (io_ctx.trigger_state[hand_id].isActive != 0 and (io_ctx.trigger_state[hand_id].currentState > 0.5 or io_ctx.keyboard.isPressed(.return_key))) {
                        try asset_manager.getSound("error.wav").play(0.5);
                        hand.curr_cooldown = hand.reset_cooldown;
                        _ = try world.spawn(allocator, .{
                            eng.Transform{
                                .position = hand_transform.position + @as(nz.Vec3(f32), @splat(-0.2)),
                                .scale = @splat(0.4),
                            },
                            eng.Mesh{},
                            eng.Texture{ .name = "windows_xp.png" },
                            eng.RigidBody{
                                .force = rotated_hand_pos * @as(nz.Vec3(f32), @splat(10)),
                                .mass = 0,
                            },
                            eng.BBAA{ .max = @splat(0.5), .min = @splat(-0.1) },
                            game.Bullet{ .time_of_death = time.current_time_ns + 1000 * 1000 * 1000 * 3 }, //Nano * Micro * Milli * Seconds
                        });
                    }
                } else {
                    hand.curr_cooldown -= @floatCast(time.delta_time);
                }
            },
            .collectable => {
                var collect_transform = world.getComponentByEntity(eng.Transform, hand.equiped.collectable);
                if (collect_transform != null) {
                    collect_transform.?.position = hand_transform.position;
                    collect_transform.?.rotation = hand_transform.rotation;
                }
            },
        }
        var query_collectable = world.query(&.{ game.collectable, eng.Transform });
        while (query_collectable.next()) |entry| {
            var collected = entry.get(game.collectable).?;
            if (collected.collected == true) continue;
            const collect_transform = entry.get(eng.Transform).?;
            if (@abs(nz.distance(collect_transform.position, hand_transform.position)) < 0.5) {
                hand_mesh.should_render = false;
                collected.collected = true;
                collect_transform.scale = @splat(0.1);
                hand.equiped = .{ .collectable = entry.id };
            }
        }
    }
}

fn toEulerAngles(q: nz.Vec4(f32)) nz.Vec3(f32) {
    const x = q[0];
    const y = q[1];
    const z = q[2];
    const w = q[3];
    var angles: nz.Vec3(f32) = @splat(0);

    // roll (x-axis rotation)
    const sinr_cosp: f32 = 2 * (w * x + y * z);
    const cosr_cosp: f32 = 1 - 2 * (x * x + y * y);
    angles[0] = std.math.atan2(sinr_cosp, cosr_cosp);
    const pistol_pitch_offset: f32 = std.math.degreesToRadians(-35.0);
    angles[0] += pistol_pitch_offset;

    // pitch (y-axis rotation)
    const sinp: f32 = std.math.sqrt(1 + 2 * (w * y - x * z));
    const cosp: f32 = std.math.sqrt(1 - 2 * (w * y - x * z));
    angles[1] = 2 * std.math.atan2(sinp, cosp) - std.math.pi / 2.0;

    // yaw (z-axis rotation)
    const siny_cosp: f32 = 2 * (w * z + x * y);
    const cosy_cosp: f32 = 1 - 2 * (y * y + z * z);
    angles[2] = 2 * std.math.atan2(siny_cosp, cosy_cosp);

    return angles;
}

fn quatToEuler(q: nz.Vec4(f32)) nz.Vec3(f32) {
    const x = q[0];
    const y = q[1];
    const z = q[2];
    const w = q[3];

    var angles: nz.Vec3(f32) = @splat(0);

    // roll (X axis)
    const sinr_cosp = 2.0 * (w * x + y * z);
    const cosr_cosp = 1.0 - 2.0 * (x * x + y * y);
    angles[0] = std.math.atan2(sinr_cosp, cosr_cosp);

    // pitch (Y axis)
    const sinp = 2.0 * (w * y - z * x);
    if (@abs(sinp) >= 1.0) {
        // use 90° with sign when out of range
        angles[1] = std.math.copysign(std.math.pi / 2.0, sinp);
    } else {
        angles[1] = std.math.asin(sinp);
    }

    // yaw (Z axis)
    const siny_cosp = 2.0 * (w * z + x * y);
    const cosy_cosp = 1.0 - 2.0 * (y * y + z * z);
    angles[2] = std.math.atan2(siny_cosp, cosy_cosp);

    return angles;
}

fn quatMul(q1: nz.Vec4(f32), q2: nz.Vec4(f32)) nz.Vec4(f32) {
    const x1 = q1[0];
    const y1 = q1[1];
    const z1 = q1[2];
    const w1 = q1[3];
    const x2 = q2[0];
    const y2 = q2[1];
    const z2 = q2[2];
    const w2 = q2[3];

    return nz.Vec4(f32){
        w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
        w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
        w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2,
        w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
    };
}

inline fn unwrapAngle(prev: f32, current: f32) f32 {
    var delta = current - prev;
    const two_pi: f32 = 2.0 * std.math.pi;
    while (delta > std.math.pi) delta -= two_pi;
    while (delta < -std.math.pi) delta += two_pi;
    return prev + delta;
}

// quat -> [pitch, yaw, roll] (engine order)
fn quatToPYR(q: nz.Vec4(f32)) nz.Vec3(f32) {
    const x = q[0];
    const y = q[1];
    const z = q[2];
    const w = q[3];

    // yaw (around Z)
    const siny_cosp: f32 = 2.0 * (w * z + x * y);
    const cosy_cosp: f32 = 1.0 - 2.0 * (y * y + z * z);
    const yaw: f32 = std.math.atan2(siny_cosp, cosy_cosp);

    // pitch (around Y)
    var sinp: f32 = 2.0 * (w * y - z * x);
    if (sinp > 1.0) sinp = 1.0;
    if (sinp < -1.0) sinp = -1.0;
    const pitch: f32 = std.math.asin(sinp);

    // roll (around X)
    const sinr_cosp: f32 = 2.0 * (w * x + y * z);
    const cosr_cosp: f32 = 1.0 - 2.0 * (x * x + y * y);
    const roll: f32 = std.math.atan2(sinr_cosp, cosr_cosp);

    return nz.Vec3(f32){ yaw, pitch, roll };
}
