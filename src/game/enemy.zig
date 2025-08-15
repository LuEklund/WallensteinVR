const std = @import("std");
const World = @import("../ecs.zig").World;
const eng = @import("../engine/root.zig");
const game = @import("../game/root.zig");
const Tilemap = @import("map.zig").Tilemap;
const nz = @import("numz");

const PQEntry = struct {
    priority: usize,
    node: nz.Vec2(usize),
};

const PosKey = struct {
    x: usize,
    y: usize,
};

fn toKey(v: nz.Vec2(usize)) PosKey {
    return .{
        .x = v[0],
        .y = v[1],
    };
}

fn heuristic(x: nz.Vec2(usize), y: nz.Vec2(usize)) usize {
    return @abs(x[0] -| y[0]) +| @abs(x[1] -| y[1]);
}

fn pqLessThan(_: void, a: PQEntry, b: PQEntry) std.math.Order {
    return if (a.priority < b.priority) .lt else if (a.priority > b.priority) .gt else .eq;
}

fn lerp(a: nz.Vec2(f32), b: nz.Vec2(usize), t: f32) nz.Vec2(f32) {
    const b_float = nz.Vec2(f32){ @as(f32, @floatFromInt(b[0])), @as(f32, @floatFromInt(b[1])) };
    const c = a * @as(nz.Vec2(f32), @splat((1 - t)));
    const d = b_float * @as(nz.Vec2(f32), @splat(t));
    return c + d;
}

fn astar(allocator: std.mem.Allocator, map: Tilemap, player_pos: nz.Vec2(usize), pos: nz.Vec2(usize)) ![]nz.Vec2(usize) {
    var path = std.ArrayList(nz.Vec2(usize)).init(allocator);
    errdefer path.deinit();

    var came_from = std.AutoHashMap(PosKey, PosKey).init(allocator);
    defer came_from.deinit();

    var cost_so_far = std.AutoHashMap(PosKey, usize).init(allocator);
    defer cost_so_far.deinit();

    var pq = std.PriorityQueue(PQEntry, void, pqLessThan).init(allocator, {});
    defer pq.deinit();

    try pq.add(.{ .priority = 0, .node = pos });
    try cost_so_far.put(toKey(pos), 0);

    const dirs = [_][2]i32{
        .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 },
    };

    while (pq.count() > 0) {
        const current = pq.remove().node;

        if (nz.eql(player_pos, current)) {
            var cur = player_pos;
            try path.append(cur);

            var cur_key = toKey(cur);
            while (came_from.get(cur_key)) |prev_key| {
                cur = nz.Vec2(usize){ prev_key.x, prev_key.y };
                cur_key = prev_key;
                try path.append(cur);
            }

            std.mem.reverse(nz.Vec2(usize), path.items);

            std.debug.print("Found Path ({} steps):\n", .{path.items.len});
            for (path.items) |p| {
                std.debug.print(" -> ({d},{d})\n", .{ p[0], p[1] });
            }

            return try path.toOwnedSlice();
        }

        const cur_cost = cost_so_far.get(toKey(current)).?;

        for (dirs) |dir| {
            const neighbor = nz.Vec2(usize){
                @intCast(@as(i32, @intCast(current[0])) + dir[0]),
                @intCast(@as(i32, @intCast(current[1])) + dir[1]),
            };
            if (neighbor[0] < 0 or neighbor[1] < 0 or neighbor[0] >= map.x or neighbor[1] >= map.y) {
                continue;
            }

            if (map.get(neighbor[0], neighbor[1]) == 1) continue;

            const new_cost = cur_cost + 1;
            const neighbor_key = toKey(neighbor);
            const old_cost = cost_so_far.get(neighbor_key);

            if (old_cost == null or new_cost < old_cost.?) {
                try cost_so_far.put(neighbor_key, new_cost);
                const priority = new_cost + heuristic(neighbor, player_pos);
                try pq.add(.{ .priority = priority, .node = neighbor });
                try came_from.put(neighbor_key, toKey(current));
            }
        }
    }

    return error.NoPath;
}

fn getDistance2D(a: nz.Vec2(f32), b: nz.Vec2(f32)) f32 {
    const dx = b[0] - a[0];
    const dy = b[1] - a[1];
    return @sqrt(dx * dx + dy * dy);
}

pub fn spawn(comps: []const type, world: *World(comps), allocator: std.mem.Allocator, map: Tilemap) !void {
    var prng = std.Random.DefaultPrng.init(std.crypto.random.int(u64));
    const random = prng.random();
    var pos_x = random.int(usize) % (map.x);
    var pos_y = random.int(usize) % (map.y);

    while (map.get(pos_x, pos_y) == 1) {
        pos_x = random.int(usize) % (map.x);
        pos_y = random.int(usize) % (map.y);
    }

    _ = try world.spawn(
        allocator,
        .{
            eng.Enemy{
                .lerp_percent = 0.0,
            },
            eng.Transform{
                .position = .{ @floatFromInt(pos_x), 1, @floatFromInt(pos_y) },
                .scale = .{ 0.4, 0.4, 0.4 },
            },
            eng.Texture{ .id = 0 },
            eng.Mesh{ .name = "xyzdragon.obj" },
        },
    );
}

pub fn update(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    const io_ctx = try world.getResource(eng.IoCtx);
    var query_player = world.query(&.{ eng.Player, eng.Transform });
    const map: *Tilemap = try world.getResource(Tilemap);

    var player_transform: eng.Transform = undefined;
    while (query_player.next()) |entity| {
        const transform = entity.get(eng.Transform).?;
        player_transform = transform.*;
        if (!(player_transform.position[0] < 0 or player_transform.position[2] < 0)) {
            const player_pos_vec2 = nz.Vec2(usize){ @as(usize, @intFromFloat(@abs(player_transform.position[0]))), @as(usize, @intFromFloat(@abs(player_transform.position[2]))) };
            if (io_ctx.keyboard.isActive(.k) and map.get(player_pos_vec2[0], player_pos_vec2[1]) == 0) {
                try spawn(comps, world, allocator, map.*);
            }
        }
    }

    //std.debug.print("Player X: {} Y: {}\n", .{player_transform.position[0], player_transform.position[2]});

    const enemy_speed: f32 = 0.001;
    const enemy_radar_distance: f32 = 5.0;
    var query_enemy = world.query(&.{ eng.Enemy, eng.Transform });
    while (query_enemy.next()) |entity| {
        // Get Components
        const transform: *eng.Transform = entity.get(eng.Transform).?;
        var enemy = entity.get(eng.Enemy).?;
        const time: *eng.time.Time = try world.getResource(eng.time.Time);

        // Interpolation
        enemy.lerp_percent += enemy_speed * @as(f32, @floatCast(time.delta_time));
        if (enemy.lerp_percent > 1.0) {
            enemy.lerp_percent = 0.0;
        }

        std.debug.print("Distance: {}\n", .{nz.distance(transform.position, player_transform.position)});
        if (!(player_transform.position[0] < 0 or transform.position[0] < 0 or
            player_transform.position[2] < 0 or transform.position[2] < 0) and
            nz.distance(transform.position, player_transform.position) <= enemy_radar_distance)
        {
            const player_pos_vec2 = nz.Vec2(usize){ @as(usize, @intFromFloat(@abs(player_transform.position[0]))), @as(usize, @intFromFloat(@abs(player_transform.position[2]))) };
            const enemy_pos_vec2 = nz.Vec2(usize){ @as(usize, @intFromFloat(@abs(transform.position[0]))), @as(usize, @intFromFloat(@abs(transform.position[2]))) };
            std.debug.print("Start ({any}) Goal ({any})\n", .{ enemy_pos_vec2, player_pos_vec2 });

            if (map.get(player_pos_vec2[0], player_pos_vec2[1]) == 0) {
                const tiles: []nz.Vec2(usize) = try astar(allocator, map.*, player_pos_vec2, enemy_pos_vec2);
                if (tiles.len > 1) {
                    const movement = lerp(nz.Vec2(f32){ transform.position[0], transform.position[2] }, tiles[1], enemy.lerp_percent);
                    transform.position[0] = movement[0];
                    transform.position[2] = movement[1];

                    //std.debug.print("Tiles: {}\n", .{tiles[1]});
                    //std.debug.print("Movement: ({}, {})\n", .{movement[0], movement[1]});
                    //std.debug.print("Pos: ({}, {})\n", .{transform.position[0], transform.position[1]});
                }
            }
        }
    }
}
