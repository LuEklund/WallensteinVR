const std = @import("std");
const nz = @import("numz");
const World = @import("../ecs.zig").World;
const Transform = @import("root.zig").Transform;

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
    const delta_time: f32 = 0.016;
    var it = world.query(&.{ Transform, BBAA, Rigidbody });
    while (it.next()) |entity| {
        const transform = entity.get(Transform).?;
        const current = entity.get(BBAA).?;
        const rigidbody = entity.get(Rigidbody).?;

        transform.position += rigidbody.force * @as(nz.Vec3(f32), @splat(delta_time));
        for (0..3) |i| {
            rigidbody.force[i] += if (rigidbody.force[i] > 0)
                -rigidbody.mass
            else if (rigidbody.force[i] < 0)
                rigidbody.mass
            else
                0;

            if (@abs(rigidbody.force[i]) < rigidbody.mass / 1.5) rigidbody.force[i] = 0;
        }

        var against_it = world.query(&.{ Transform, BBAA, Rigidbody });
        while (against_it.next()) |entry| {
            if (entity.id == entry.id) continue;
            const against_transform = entry.get(Transform).?;
            if (@abs(nz.distance(transform.position, against_transform.position)) > 1.5) continue;
            const against = entry.get(BBAA).?;
            if (against.intersecting(current.*)) {
                rigidbody.force = -rigidbody.force;
            }
        }
    }
}
