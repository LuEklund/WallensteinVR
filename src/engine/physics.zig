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

    pub fn intersect_BBAAs(a: @This(), b: BBAA) bool {
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

pub fn getClipX(current: BBAA, against: BBAA, deltaX: f32) bool {
    // var new_x = deltaX;
    if (deltaX > 0 and current.max[0] <= against.min[0]) {
        return true;
        // const clip: f32 = against.min[0] - current.max[0];
        // if (deltaX > clip)
        //     new_x = clip;
    }
    if (deltaX < 0 and current.min[0] >= against.max[0]) {
        return true;
        // const clip = against.max[0] - current.min[0];
        // if (deltaX < clip)
        //     new_x = clip;
    }
    return false;
    // return new_x;
}
pub fn getClipY(current: BBAA, against: BBAA, deltaY: f32) bool {
    // var new_y = deltaY;
    if (deltaY > 0 and current.max[1] <= against.min[1]) {
        return true;

        // const clip: f32 = against.min[1] - current.max[1];
        // if (deltaY > clip)
        //     new_y = clip;
    }
    if (deltaY < 0 and current.min[1] >= against.max[1]) {
        return true;

        // const clip: f32 = against.max[1] - current.min[1];
        // if (deltaY < clip)
        //     new_y = clip;
    }
    return false;
    // return new_y;
}
pub fn getClipZ(current: BBAA, against: BBAA, deltaZ: f32) bool {
    // var new_z = deltaZ;
    if (deltaZ > 0 and current.max[2] <= against.min[2]) {
        return true;

        // const clip: f32 = against.min[2] - current.max[2];
        // if (deltaZ > clip)
        //     new_z = clip;
    }
    if (deltaZ < 0 and current.min[2] >= against.max[2]) {
        return true;

        // const clip: f32 = against.max[2] - current.min[2];
        // if (deltaZ < clip)
        //     new_z = clip;
    }
    return false;

    // return new_z;
}

pub fn update(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    const delta_time: f32 = 0.016;
    var it = world.query(&.{ Transform, BBAA, Rigidbody });
    while (it.next()) |entity| {
        const transform = entity.get(Transform).?;
        const bbaa = entity.get(BBAA).?;
        const rigidbody = entity.get(Rigidbody).?;

        var it2 = world.query(&.{ Transform, BBAA, Rigidbody });
        while (it2.next()) |entity2| {
            if (entity.id == entity2.id) continue;
            const transform2 = entity2.get(Transform).?;
            if (@abs(nz.distance(transform.position, transform2.position)) > 1.5) continue;
            const bbaa2 = entity2.get(BBAA).?;
            // const rigidbody2 = entity2.get(Rigidbody).?;
            const current_bbaa: BBAA = .{
                .max = bbaa.max + transform.position,
                .min = bbaa.min + transform.position,
            };
            const against_bbaa: BBAA = .{
                .max = bbaa2.max + transform2.position,
                .min = bbaa2.min + transform2.position,
            };
            if (current_bbaa.intersect_BBAAs(against_bbaa)) {
                std.debug.print("Enity ID {} collied with ID {}\n", .{ entity.id, entity2.id });
                // if (getClipX(current_bbaa, against_bbaa, rigidbody.force[0])) rigidbody.force[0] = 0;
                // if (getClipY(current_bbaa, against_bbaa, rigidbody.force[1])) rigidbody.force[1] = 0;
                // if (getClipZ(current_bbaa, against_bbaa, rigidbody.force[2])) rigidbody.force[2] = 0;
                // if (getClipX(current_bbaa, against_bbaa, rigidbody2.force[0])) rigidbody2.force[0] = 0;
                // if (getClipY(current_bbaa, against_bbaa, rigidbody2.force[1])) rigidbody2.force[1] = 0;
                // if (getClipZ(current_bbaa, against_bbaa, rigidbody2.force[2])) rigidbody2.force[2] = 0;
            }
            // if (nz.eql(@as(nz.Vec3(f32), @splat(nz.distance(bbaa.size, bbaa2.size))), bbaa.size + @as(nz.Vec3(f32), @splat(2)))) {
            //     for (0..3) |i| {
            //         if (transform.position[i] + bbaa.size[i] / 2 < transform2 + bbaa2.size[i] / 2) {
            //             rigidbody.force[i] += delta_time;
            //         }
            //     }
            // }
        }

        transform.position += rigidbody.force * @as(nz.Vec3(f32), @splat(delta_time));
    }
}
