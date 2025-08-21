const std = @import("std");
const nz = @import("numz");
const World = @import("../ecs.zig").World;
const Transform = @import("root.zig").Transform;
const Time = @import("time.zig").Time;

pub const Rigidbody = struct {
    force: nz.Vec3(f32) = @splat(0),
    mass: f32 = 1,
};

pub const BBAA = struct {
    min: nz.Vec3(f32) = @splat(0),
    max: nz.Vec3(f32) = @splat(1),

    pub fn intersecting(a: @This(), b: BBAA) bool {
        return (intersect(a.min[0], a.max[0], b.min[0], b.max[0]) and
            intersect(a.min[1], a.max[1], b.min[1], b.max[1]) and
            intersect(a.min[2], a.max[2], b.min[2], b.max[2]));
    }

    pub fn toRelative(bbaa: @This(), pos: nz.Vec3(f32)) BBAA {
        return .{
            .max = bbaa.max + pos,
            .min = bbaa.min + pos,
        };
    }
};

pub fn intersect(a_min: f32, a_max: f32, b_min: f32, b_max: f32) bool {
    return a_min <= b_max and a_max >= b_min;
}

fn getClip(
    move_min: f32,
    move_max: f32,
    other_min: f32,
    other_max: f32,
    vel: f32,
    time: f32,
) f32 {
    if (vel > 0 and move_max >= other_min) {
        return @min((other_min - move_max) * time, vel);
    }
    if (vel < 0 and move_min <= other_max) {
        return @max((other_max - move_min) * time, vel);
    }
    return vel;
}

pub fn update(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    const time = try world.getResource(Time);
    const delta_time: f32 = @floatCast(time.delta_time);

    var it = world.query(&.{ Transform, BBAA, Rigidbody });
    while (it.next()) |entity| {
        const current_transform = entity.get(Transform).?;
        const current_bbaa = entity.get(BBAA).?;
        const current_rigidbody = entity.get(Rigidbody).?;
        const current_bbaa_relative = current_bbaa.toRelative(current_transform.position);

        current_transform.position += current_rigidbody.force * @as(nz.Vec3(f32), @splat(delta_time));
        if (current_rigidbody.mass != 0) {
            for (0..3) |i| {
                current_rigidbody.force[i] += if (current_rigidbody.force[i] > 0)
                    -current_rigidbody.mass
                else if (current_rigidbody.force[i] < 0)
                    current_rigidbody.mass
                else
                    0;

                if (@abs(current_rigidbody.force[i]) <= current_rigidbody.mass) current_rigidbody.force[i] = 0;
            }
        }

        var against_it = world.query(&.{ Transform, BBAA, Rigidbody });
        // const vel = current_rigidbody.force * @as(nz.Vec3(f32), @splat(delta_time));
        while (against_it.next()) |entry| {
            if (entity.id == entry.id) continue;
            const against_transform = entry.get(Transform).?;
            // const against_rigidbody = entry.get(Rigidbody).?;
            const against_bbaa = entry.get(BBAA).?;
            const against_bbaa_relative = against_bbaa.toRelative(against_transform.position);
            // if (@abs(nz.distance(transform.position, against_transform.position)) > @max(current_bbaa.max[0], against_bbaa.max[0]) + 1) continue;
            if (against_bbaa_relative.intersecting(current_bbaa_relative)) {
                // for (0..3) |i| {
                //     vel[i] = getClip(
                //         current_bbaa_relative.min[i],
                //         current_bbaa_relative.max[i],
                //         against_bbaa_relative.min[i],
                //         against_bbaa_relative.max[i],
                //         vel[i],
                //         delta_time,
                //     );
                // }
            }
        }
        // current_transform.position += current_rigidbody.force * @as(nz.Vec3(f32), @splat(delta_time));
        // current_transform.position += vel;
    }
}
