const std = @import("std");
const nz = @import("numz");

pub const Tilemap = struct {
    const Self = @This();

    tiles: []u8,
    x: usize,
    y: usize,
    start_x: usize,
    start_y: usize,
    end_x: usize,
    end_y: usize,

    pub fn init(allocator: std.mem.Allocator, x: usize, y: usize) !Self {
        const tiles: []u8 = try allocator.alloc(u8, x * y);
        @memset(tiles, 1);

        return .{
            .tiles = tiles,
            .x = x,
            .y = y,
            .start_x = 0,
            .start_y = 0,
            .end_x = 0,
            .end_y = 0,
        };
    }

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.tiles);
    }

    pub fn get(self: Self, x: usize, y: usize) u8 {
        const index = (y * self.x) + x;
        return self.tiles[index];
    }

    pub fn getIndex(self: Self, index: usize) nz.Vec2(usize) {
        const x = index % self.x;
        const y = (index - x) / self.x;
        return nz.Vec2(usize){ x, y };
    }

    pub fn set(self: Self, x: usize, y: usize, tile: u8) void {
        const index = (y * self.x) + x;
        self.tiles[index] = tile;
    }

    pub fn spawnWalker(self: *Self, random: std.Random, iterations: ?usize) void {
        var x: usize = random.int(usize) % self.x;
        var y: usize = random.int(usize) % self.y;

        self.start_x = x;
        self.start_y = y;
        defer self.set(self.start_x, self.start_y, 254);

        const i = iterations orelse 10000;
        std.debug.print("ITS {d}\n", .{i});
        for (0..i) |_| {
            const decision: u8 = random.int(u8) % 4;
            switch (decision) {
                0 => x +|= 1,
                1 => y +|= 1,
                2 => x -|= 1,
                3 => y -|= 1,
                else => unreachable,
            }

            x = std.math.clamp(x, 1, self.x - 2);
            y = std.math.clamp(y, 1, self.y - 2);

            self.set(x, y, 0);
        }
        self.end_x = x;
        self.end_y = y;
        self.set(x, y, 255);
    }

    pub fn toModel(self: Tilemap, allocator: std.mem.Allocator) !struct { []f32, []u32 } {
        var verices: std.ArrayListUnmanaged(f32) = .empty;
        var indices: std.ArrayListUnmanaged(u32) = .empty;

        var size: u32 = 0;
        for (0..self.x) |ix| {
            const x: f32 = @floatFromInt(ix);
            for (0..1) |iy| {
                const y: f32 = @floatFromInt(iy);
                for (0..self.y) |iz| {
                    if (self.get(ix, iz) == 0) continue;
                    const z: f32 = @floatFromInt(iz);
                    //TOP FACE
                    try indices.appendSlice(allocator, &.{
                        size,
                        size + 1,
                        size + 2,
                        size,
                        size + 2,
                        size + 3,
                    });
                    try verices.appendSlice(allocator, &.{
                        x, y + 1, z, 0.0, 0.0, 0.0, 1.0, 0.0, // bottom-left
                        x, y + 1, z + 1, 0.0, 1.0, 0.0, 1.0, 0.0, // top-left
                        x + 1, y + 1, z + 1, 1.0, 1.0, 0.0, 1.0, 0.0, // top-right
                        x + 1, y + 1, z, 1.0, 0.0, 0.0, 1.0, 0.0, // bottom-right
                    });
                    size += 4;

                    // LEFT FACE
                    try indices.appendSlice(allocator, &.{
                        size,
                        size + 1,
                        size + 2,
                        size,
                        size + 2,
                        size + 3,
                    });
                    try verices.appendSlice(allocator, &.{
                        x, y + 1, z, 0.0, 0.0, 0.0, 1.0, 0.0, // bottom-left
                        x, y, z, 0.0, 1.0, 0.0, 1.0, 0.0, // top-left
                        x, y, z + 1, 1.0, 1.0, 0.0, 1.0, 0.0, // top-right
                        x, y + 1, z + 1, 1.0, 0.0, 0.0, 1.0, 0.0, // bottom-right
                    });
                    size += 4;

                    //FRONT FACE
                    try indices.appendSlice(allocator, &.{
                        size,
                        size + 1,
                        size + 2,
                        size,
                        size + 2,
                        size + 3,
                    });
                    try verices.appendSlice(allocator, &.{
                        x, y + 1, z + 1, 0.0, 0.0, 0.0, 1.0, 0.0, // bottom-left
                        x, y, z + 1, 0.0, 1.0, 0.0, 1.0, 0.0, // top-left
                        x + 1, y, z + 1, 1.0, 1.0, 0.0, 1.0, 0.0, // top-right
                        x + 1, y + 1, z + 1, 1.0, 0.0, 0.0, 1.0, 0.0, // bottom-right
                    });
                    size += 4;

                    //RIGHT FACE
                    try indices.appendSlice(allocator, &.{
                        size,
                        size + 1,
                        size + 2,
                        size,
                        size + 2,
                        size + 3,
                    });
                    try verices.appendSlice(allocator, &.{
                        x + 1, y + 1, z + 1, 0.0, 0.0, 0.0, 1.0, 0.0, // bottom-left
                        x + 1, y, z + 1, 0.0, 1.0, 0.0, 1.0, 0.0, // top-left
                        x + 1, y, z, 1.0, 1.0, 0.0, 1.0, 0.0, // top-right
                        x + 1, y + 1, z, 1.0, 0.0, 0.0, 1.0, 0.0, // bottom-right
                    });
                    size += 4;

                    //BACK FACE
                    try indices.appendSlice(allocator, &.{
                        size,
                        size + 1,
                        size + 2,
                        size,
                        size + 2,
                        size + 3,
                    });
                    try verices.appendSlice(allocator, &.{
                        x + 1, y + 1, z, 0.0, 0.0, 0.0, 1.0, 0.0, // bottom-left
                        x + 1, y, z, 0.0, 1.0, 0.0, 1.0, 0.0, // top-left
                        x, y, z, 1.0, 1.0, 0.0, 1.0, 0.0, // top-right
                        x, y + 1, z, 1.0, 0.0, 0.0, 1.0, 0.0, // bottom-right
                    });
                    size += 4;
                }
            }
        }
        return .{ try verices.toOwnedSlice(allocator), try indices.toOwnedSlice(allocator) };
    }

    pub fn gridSpawn(self: Self, distance: usize, offset: usize, tile: u8) void {
        for (0..@divFloor(self.x - offset, distance)) |x| {
            for (0..@divFloor(self.y - offset, distance)) |y| {
                if (self.get(x * distance + offset, y * distance + offset) == 0)
                    self.set(x * distance + offset, y * distance + offset, tile);
            }
        }
    }

    pub fn print(self: Self) void {
        for (self.tiles, 0..) |tile, i| {
            if (i > 0 and i % self.x == 0) {
                std.debug.print("\x1b[0m\n", .{});
            }

            const color: struct { u8, u8, u8 } = switch (tile) {
                0 => .{ 0, 0, 0 }, // Air
                1 => .{ 0, 100, 0 }, // Basic wall
                200 => .{ 255, 0, 0 }, // Enemy spawn
                254 => .{ 255, 255, 255 }, // Spawn
                255 => .{ 255, 215, 0 }, // Goal
                else => unreachable,
            };

            std.debug.print("\x1b[38;2;{d};{d};{d}m\x1b[48;2;{d};{d};{d}m██", .{ color.@"0", color.@"1", color.@"2", color.@"0", color.@"1", color.@"2" });
        }

        std.debug.print("\x1b[0m\n", .{});
    }
};

pub fn init(allocator: std.mem.Allocator, seed: ?u64) !Tilemap {
    var prng = std.Random.DefaultPrng.init(seed orelse std.crypto.random.int(u64));
    const random = prng.random();
    // defer std.debug.print("SEED: {d}\n", .{seed});

    var map: Tilemap = try .init(allocator, 100, 100);
    map.spawnWalker(random, null);
    // map.gridSpawn(7, 0, 200);

    // const SIZE = 20;
    // const tiles: [SIZE * SIZE]u8 = .{
    //     // row 0 (top border)
    //     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    //     // row 1
    //     1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    //     // row 2
    //     1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1,
    //     // row 3
    //     1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    //     // row 4
    //     1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1,
    //     // row 5
    //     1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    //     // row 6
    //     1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1,
    //     // row 7
    //     1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    //     // row 8
    //     1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1,
    //     // row 9
    //     1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    //     // row 10
    //     1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1,
    //     // row 11
    //     1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    //     // row 12
    //     1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1,
    //     // row 13
    //     1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    //     // row 14
    //     1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1,
    //     // row 15
    //     1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    //     // row 16
    //     1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1,
    //     // row 17
    //     1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    //     // row 18
    //     1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    //     // row 19 (bottom border)
    //     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    // };

    // @memcpy(map.tiles, &tiles);

    map.print();
    return map;
}
