const std = @import("std");

const World = @import("../ecs.zig").World;

pub const Time = struct {
    delta_time: f64 = 0,
    previous_time_ns: i128 = 0,
    current_time_ns: i128 = 0,
};

pub fn init(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    const time_ctx: *Time = try allocator.create(Time);
    time_ctx.* = .{
        .previous_time_ns = std.time.nanoTimestamp(),
    };

    try world.setResource(allocator, Time, time_ctx);
}

pub fn update(comps: []const type, world: *World(comps), _: std.mem.Allocator) !void {
    // std.debug.print("Starting main loop...\n", .{});
    var time = try world.getResource(Time);

    time.current_time_ns = std.time.nanoTimestamp();

    const time_diff_ns = time.current_time_ns - time.previous_time_ns;

    time.delta_time = @as(f64, @floatFromInt(time_diff_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));

    time.previous_time_ns = time.current_time_ns;

    // std.debug.print("Main loop finished.\nDeltaTime: {any}\nCurrent: {any}\nPrev: {any}", .{ time.delta_time, time.current_time_ns, time.previous_time_ns });
}
