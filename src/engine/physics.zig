const std = @import("std");
const nz = @import("numz");
const World = @import("../ecs.zig").World;
const Transform = @import("root.zig").Transform;

pub const Rigidbody = struct {
    force: nz.Vec3(f32) = @splat(0),
    mass: f32 = 1,
};

pub const BBAA = struct {
    size: nz.Vec3(f32) = @splat(1),
};

pub fn update(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    const delta_time: f32 = 0.016;
    var it = world.query(&.{ Transform, BBAA, Rigidbody });
    while (it.next()) |entity| {
        const transform = entity.get(Transform).?;
        // const bbaa = entity.get(BBAA).?;
        const rigidbody = entity.get(Rigidbody).?;

        // var it2 = world.query(&.{ Transform, BBAA });
        // while (it2.next()) |entity2| {
        //     const transform2 = entity2.get(Transform).?;
        //     const bbaa2 = entity2.get(BBAA).?;
        //     if (nz.eql(@as(nz.Vec3(f32), @splat(nz.distance(bbaa.size, bbaa2.size))), bbaa.size + @as(nz.Vec3(f32), @splat(2)))) {
        //         for (0..3) |i| {
        //             if (transform.position[i] + bbaa.size[i] / 2 < transform2 + bbaa2.size[i] / 2) {
        //                 rigidbody.force[i] += delta_time;
        //             }
        //         }
        //     }
        // }

        transform.position += rigidbody.force * @as(nz.Vec3(f32), @splat(delta_time));
        // rigidbody.force -= @splat(delta_time);
    }
}
