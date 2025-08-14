
const std = @import("std");
const World = @import("../ecs.zig").World;
const eng = @import("../engine/root.zig");
const game = @import("../game/root.zig");
const Tilemap = @import("map.zig").Tilemap;
const nz = @import("numz");

var first_enemy: bool = true;

const PQEntry = struct {
    priority: i32,
    node: nz.Vec2(f32),
};

const PosKey = struct {
    x: i32,
    y: i32,
};

const PosKeyUsize = struct {
    x: usize,
    y: usize,
};

fn toKey(v: nz.Vec2(f32)) PosKey {
    return .{
        .x = @intFromFloat(v[0]),
        .y = @intFromFloat(v[1]),
    };
}

fn toKeyUsize(v: nz.Vec2(f32)) PosKeyUsize {
    return .{
        .x = @intFromFloat(v[0]),
        .y = @intFromFloat(v[1]),
    };
}

fn heuristic(x: nz.Vec2(f32), y: nz.Vec2(f32)) f32 {
    // Manhattan Distance
    return @abs(x[0] - y[0]) + @abs(x[1] - y[1]);
}

fn pqLessThan(_: void, a: PQEntry, b: PQEntry) std.math.Order {
    return if (a.priority < b.priority) .lt
        else if (a.priority > b.priority) .gt
        else .eq;
}

fn astar(
    allocator: std.mem.Allocator, map: Tilemap, player_pos: nz.Vec2(f32), pos: nz.Vec2(f32)) ![]nz.Vec2(f32) {

    var path = std.ArrayList(nz.Vec2(f32)).init(allocator);
    errdefer path.deinit();

    var came_from = std.AutoHashMap(PosKey, PosKey).init(allocator);
    defer came_from.deinit();

    var cost_so_far = std.AutoHashMap(PosKey, i32).init(allocator);
    defer cost_so_far.deinit();

    var pq = std.PriorityQueue(PQEntry, void, pqLessThan).init(allocator, {});
    defer pq.deinit();

    try pq.add(.{ .priority = 0, .node = pos });
    try cost_so_far.put(toKey(pos), 0);

    const dirs = [_][2]f32 {
        .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1}, .{ 0, -1 },
    };

    while (pq.count() > 0) {
        const current = pq.remove().node;

        if (nz.eql(player_pos, current)) {
            var cur = player_pos;
            try path.append(cur);

            var cur_key = toKey(cur);
            while (came_from.get(cur_key)) |prev_key| {
                cur = nz.Vec2(f32){ @floatFromInt(prev_key.x), @floatFromInt(prev_key.y) };
                cur_key = prev_key;
                try path.append(cur);
            }

            std.mem.reverse(nz.Vec2(f32), path.items);

            std.debug.print("Found Path ({} steps):\n", .{path.items.len});
            for (path.items) |p| {
                std.debug.print(" -> ({d},{d})\n", .{ p[0], p[1] });
            }

            return try path.toOwnedSlice();
        }

        const cur_cost = cost_so_far.get(toKey(current)).?;

        for (dirs) |dir| {
            const neighbor = nz.Vec2(f32){
                current[0] + dir[0],
                current[1] + dir[1],
            };
            if (neighbor[0] < 0 or neighbor[1] < 0
                or neighbor[0] >= @as(f32, @floatFromInt(map.x))
                or neighbor[1] >= @as(f32, @floatFromInt(map.y))) {
                continue;
            }

            if (map.get(
                @as(usize, @intFromFloat(neighbor[0])),
                @as(usize, @intFromFloat(neighbor[1])),
            ) == 1) continue;

            const new_cost = cur_cost + 1;
            const neighbor_key = toKey(neighbor);
            const old_cost = cost_so_far.get(neighbor_key);

            if (old_cost == null or new_cost < old_cost.?) {
                try cost_so_far.put(neighbor_key, new_cost);
                const priority = new_cost + @as(i32, @intFromFloat(heuristic(neighbor, player_pos)));
                try pq.add(.{ .priority = priority, .node = neighbor });
                try came_from.put(neighbor_key, toKey(current));
            }
        }
    }

    return error.NoPath;
}

fn clampToWalkable(map: Tilemap, pos: nz.Vec2(f32)) !nz.Vec2(f32) {
    
    const map_x_float = @as(f32, @floatFromInt(map.x));
    const map_y_float = @as(f32, @floatFromInt(map.y));
    if (pos[0] > map_x_float or pos[1] > map_y_float or pos[0] < 0 or pos[1] < 0) {
        for (map.tiles, 0..) |element, i| {
            if (element == 0) {
                const index = map.getIndex(i);
                const index_float = nz.Vec2(f32){@as(f32, @floatFromInt(index[0])), @as(f32, @floatFromInt(index[1]))};
                return index_float;
            }
        }
    }

    return error.NoWalkableTile;
}

fn isPlayerOnFreeTile(map: Tilemap, pos: nz.Vec2(usize)) {

}

pub fn spwanEnemy(comps: []const type, world: *World(comps), allocator: std.mem.Allocator, map: Tilemap) !void {
    var prng = std.Random.DefaultPrng.init(std.crypto.random.int(u64));
    const random = prng.random();
    var pos_x = random.int(usize) % (map.x-1);
    var pos_y = random.int(usize) % (map.y-1);

    while (map.get(pos_x, pos_y) == 1) {
        pos_x = random.int(usize) % (map.x-1);
        pos_y = random.int(usize) % (map.y-1);
    }


    _ = try world.spawn(allocator, .{
        eng.Enemy{},
        eng.Transform{
            .position = .{@floatFromInt(pos_x), 1, @floatFromInt(pos_y)},
            .scale = .{ 1, 1, 1 }
        },
        eng.Mesh{ .name = "asdasd"}
    });
}

pub fn enemyUpdateSystem(comps: []const type, world: *World(comps), allocator: std.mem.Allocator) !void {
    const io_ctx = try world.getResource(eng.IoCtx);
    var query_player = world.query(&.{ eng.Player, eng.Transform });
    const map: *Tilemap = try world.getResource(Tilemap);
    
    var player_transform: eng.Transform = undefined;
    while (query_player.next()) |entity| {
        const transform = entity.get(eng.Transform).?;
        player_transform = transform.*;
        if (io_ctx.keyboard.isActive(.k) and first_enemy == true) {
            try spwanEnemy(comps, world, allocator, map.*);
            first_enemy = false;
        }
    }

    std.debug.print("Player X: {} Y: {}", .{player_transform.position[0], player_transform.position[2]});

    const enemy_speed: f32 = 0.1;
    var query_enemy = world.query(&. {eng.Enemy, eng.Transform }); 
    while (query_enemy.next()) |entity| {
        const transform: *eng.Transform = entity.get(eng.Transform).?;
        var delta_transform: nz.Vec3(f32) = .{ player_transform.position[0] - transform.position[0],
                                               player_transform.position[1] - transform.position[1],
                                               player_transform.position[2] - transform.position[2] };
        delta_transform = nz.normalize(delta_transform) * @as(nz.Vec3(f32), @splat(enemy_speed));
        delta_transform[1] = 0;


        const player_pos_vec2 = try clampToWalkable(map.*, nz.Vec2(f32){player_transform.position[0], player_transform.position[2]});
        std.debug.print("Start: ({}, {}), Ziel: ({}, {})\n", .{
            transform.position[0], transform.position[1], player_pos_vec2[0], player_pos_vec2[1]
        });

        const tiles: []nz.Vec2(f32) = try astar(allocator, map.*, player_pos_vec2, nz.Vec2(f32){transform.position[0], transform.position[2]});
        delta_transform[0] = tiles[0][0];
        delta_transform[2] = tiles[0][1];
                            
        transform.position += delta_transform;
    }
    
}

