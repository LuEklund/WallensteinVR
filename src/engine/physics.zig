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
    max: nz.Vec3(f32) = @splat(2),

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
    return a_min < b_max and a_max > b_min;
}

pub fn update(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    const time = try world.getResource(Time);
    const delta_time: f32 = @floatCast(time.delta_time);

    var it = world.query(&.{ Transform, BBAA, Rigidbody });
    while (it.next()) |entity| {
        const current_transform = entity.get(Transform).?;
        const current_bbaa = entity.get(BBAA).?;
        const rigidbody = entity.get(Rigidbody).?;
        // current_bbaa.max = @splat(2 * @abs(@sin(current_transform.position[0])));

        current_transform.position += rigidbody.force * @as(nz.Vec3(f32), @splat(delta_time));
        const current_bbaa_relative = current_bbaa.toRelative(current_transform.position);

        //     current_transform.position += rigidbody.force * @as(nz.Vec3(f32), @splat(delta_time));
        //     if (rigidbody.mass != 0) {
        //         for (0..3) |i| {
        //             rigidbody.force[i] += if (rigidbody.force[i] > 0)
        //                 -rigidbody.mass
        //             else if (rigidbody.force[i] < 0)
        //                 rigidbody.mass
        //             else
        //                 0;

        //             if (@abs(rigidbody.force[i]) < rigidbody.mass / 1.5) rigidbody.force[i] = 0;
        //         }
        //     }

        var against_it = world.query(&.{ Transform, BBAA, Rigidbody });
        while (against_it.next()) |entry| {
            if (entity.id == entry.id) continue;
            const against_transform = entry.get(Transform).?;
            const against_bbaa = entry.get(BBAA).?;
            const against_bbaa_relative = against_bbaa.toRelative(against_transform.position);
            // if (@abs(nz.distance(transform.position, against_transform.position)) > @max(current_bbaa.max[0], against_bbaa.max[0]) + 1) continue;
            if (against_bbaa_relative.intersecting(current_bbaa_relative)) {
                std.debug.print("SCALE {}, {}\n", .{ current_transform.scale, against_transform.scale });
                rigidbody.force = -rigidbody.force;
            }
        }
    }
}
